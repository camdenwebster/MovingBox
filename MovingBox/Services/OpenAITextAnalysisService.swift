//
//  OpenAITextAnalysisService.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import SwiftData

/// Service for analyzing text descriptions to create structured inventory items
@MainActor
class OpenAITextAnalysisService {
    private let settings: SettingsManager
    private let modelContext: ModelContext
    private let baseURL = "https://7mc060nx64.execute-api.us-east-2.amazonaws.com/prod"
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0 // 1 minute for text analysis
        config.timeoutIntervalForResource = 90.0 // 1.5 minutes
        return URLSession(configuration: config)
    }()
    
    init(settings: SettingsManager, modelContext: ModelContext) {
        self.settings = settings
        self.modelContext = modelContext
    }
    
    /// Analyze text description and return structured inventory item data
    func analyzeDescription(_ description: String) async throws -> TextAnalysisResult {
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIError.invalidData
        }
        
        let request = try generateURLRequest(for: description)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse(statusCode: 0, responseData: "No HTTP response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            if httpResponse.statusCode == 429 {
                throw OpenAIError.rateLimitExceeded
            }
            
            throw OpenAIError.invalidResponse(statusCode: httpResponse.statusCode, responseData: responseString)
        }
        
        return try parseResponse(data: data)
    }
    
    private func generateURLRequest(for description: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw OpenAIError.invalidURL
        }
        
        let token = JWTManager.shared.generateToken()
        
        // Get existing categories and locations for context
        let categories = DefaultDataManager.getAllLabels(from: modelContext)
        let locations = DefaultDataManager.getAllLocations(from: modelContext)
        
        let systemPrompt = """
        You are an expert at analyzing text descriptions of household and personal items to extract structured inventory information. 
        
        The user will provide a text description of an item they want to add to their home inventory. Your job is to:
        1. Identify the primary item being described
        2. Extract or infer relevant details like make, model, serial number, estimated value
        3. Suggest appropriate category/label and location based on the item type
        4. Provide a concise, clear description for inventory purposes
        
        Available categories: \(categories.map(\.name).joined(separator: ", "))
        Available locations: \(locations.map(\.name).joined(separator: ", "))
        
        If the user's description doesn't clearly match existing categories or locations, suggest new ones that would be appropriate.
        Be conservative with price estimates - only suggest if you have reasonable confidence.
        """
        
        let function = FunctionDefinition(
            name: "create_inventory_item_from_description",
            description: "Extract structured inventory item information from a text description",
            parameters: FunctionDefinition.Parameters(
                type: "object",
                properties: [
                    "title": FunctionParameter(
                        type: "string",
                        description: "A concise, clear name for the item that would help identify it in a list",
                        enum_values: nil
                    ),
                    "quantity": FunctionParameter(
                        type: "string",
                        description: "The number of items described, or '1' if not specified",
                        enum_values: nil
                    ),
                    "description": FunctionParameter(
                        type: "string",
                        description: "A clean, concise description suitable for inventory records, limited to 160 characters",
                        enum_values: nil
                    ),
                    "make": FunctionParameter(
                        type: "string",
                        description: "Brand or manufacturer if mentioned or can be reasonably inferred",
                        enum_values: nil
                    ),
                    "model": FunctionParameter(
                        type: "string",
                        description: "Model name or number if mentioned or can be reasonably inferred",
                        enum_values: nil
                    ),
                    "serial": FunctionParameter(
                        type: "string",
                        description: "Serial number if explicitly mentioned",
                        enum_values: nil
                    ),
                    "estimated_price": FunctionParameter(
                        type: "number",
                        description: "Estimated current value in USD, only if you can make a reasonable estimate",
                        enum_values: nil
                    ),
                    "suggested_category": FunctionParameter(
                        type: "string",
                        description: "Most appropriate category/label for this item type",
                        enum_values: nil
                    ),
                    "suggested_location": FunctionParameter(
                        type: "string",
                        description: "Most likely location where this item would be stored",
                        enum_values: nil
                    ),
                    "confidence_notes": FunctionParameter(
                        type: "string",
                        description: "Brief notes about what information was inferred vs. explicitly stated",
                        enum_values: nil
                    )
                ],
                required: ["title", "quantity", "description"],
                additionalProperties: false
            ),
            strict: true
        )
        
        let tool = Tool(type: "function", function: function)
        
        let payload: [String: Any] = [
            "model": "gpt-4-vision-preview",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": "Please analyze this item description and create structured inventory data: \(description)"
                ]
            ],
            "tools": [tool],
            "tool_choice": ["type": "function", "function": ["name": "create_inventory_item_from_description"]],
            "max_tokens": 1000,
            "temperature": 0.1
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        return request
    }
    
    private func parseResponse(data: Data) throws -> TextAnalysisResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let toolCalls = message["tool_calls"] as? [[String: Any]],
              let firstToolCall = toolCalls.first,
              let function = firstToolCall["function"] as? [String: Any],
              let argumentsString = function["arguments"] as? String,
              let argumentsData = argumentsString.data(using: .utf8),
              let arguments = try JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
            throw OpenAIError.invalidData
        }
        
        let title = arguments["title"] as? String ?? "Unknown Item"
        let quantity = arguments["quantity"] as? String ?? "1"
        let description = arguments["description"] as? String ?? ""
        let make = arguments["make"] as? String ?? ""
        let model = arguments["model"] as? String ?? ""
        let serial = arguments["serial"] as? String ?? ""
        let estimatedPrice = arguments["estimated_price"] as? Double
        let suggestedCategory = arguments["suggested_category"] as? String ?? ""
        let suggestedLocation = arguments["suggested_location"] as? String ?? ""
        let confidenceNotes = arguments["confidence_notes"] as? String ?? ""
        
        return TextAnalysisResult(
            title: title,
            quantity: quantity,
            description: description,
            make: make,
            model: model,
            serial: serial,
            estimatedPrice: estimatedPrice,
            suggestedCategory: suggestedCategory,
            suggestedLocation: suggestedLocation,
            confidenceNotes: confidenceNotes
        )
    }
}

struct TextAnalysisResult: Sendable {
    let title: String
    let quantity: String
    let description: String
    let make: String
    let model: String
    let serial: String
    let estimatedPrice: Double?
    let suggestedCategory: String
    let suggestedLocation: String
    let confidenceNotes: String
}