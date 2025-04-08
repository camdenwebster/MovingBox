//
//  OpenAIService.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import Foundation
import SwiftData
import CryptoKit

enum HTTPMethod: String {
    case post = "POST"
    case get = "GET"
}

// TODO: Re-implement ability to use your own API key

enum OpenAIError: Error {
    case invalidURL
    case invalidResponse(statusCode: Int, responseData: String)
    case invalidData
    case rateLimitExceeded
    case serverError(String)
    
    var userFriendlyMessage: String {
        switch self {
        case .invalidURL:
            return "Invalid server configuration"
        case .invalidResponse(let statusCode, let responseData):
            // Try to parse Lambda/OpenAI error messages
            if let errorData = responseData.data(using: .utf8),
               let errorDict = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
               let errorMessage = errorDict["error"] as? String {
                return "Server Error (\(statusCode)): \(errorMessage)"
            }
            return "Server returned an error (Status: \(statusCode))"
        case .invalidData:
            return "Unable to process the server response"
        case .rateLimitExceeded:
            return "Too many requests. Please try again later."
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

struct FunctionParameter: Codable {
    let type: String
    let description: String?
    let enum_values: [String]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enum_values = "enum"
    }
}

struct FunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: Parameters
    
    struct Parameters: Codable {
        let type: String
        let properties: [String: FunctionParameter]
        let required: [String]
    }
}

@MainActor
class OpenAIService {
    var imageBase64: String
    var settings: SettingsManager
    var modelContext: ModelContext
    
    private let baseURL = "https://7mc060nx64.execute-api.us-east-2.amazonaws.com/prod"
    
    init(imageBase64: String, settings: SettingsManager, modelContext: ModelContext) {
        self.imageBase64 = imageBase64
        self.settings = settings
        self.modelContext = modelContext
    }
    
    internal func generateURLRequest(httpMethod: HTTPMethod) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw OpenAIError.invalidURL
        }
        
        // Get JWT token
        let token = JWTManager.shared.generateToken()
        
        let categories = DefaultDataManager.getAllLabels(from: modelContext)
        let locations = DefaultDataManager.getAllLocations(from: modelContext)
        
        let imagePrompt = "Analyze this image and identify the item which is the primary subject of the photo, along with its attributes."
        
        let function = FunctionDefinition(
            name: "process_inventory_item",
            description: "Process and structure information about an inventory item",
            parameters: FunctionDefinition.Parameters(
                type: "object",
                properties: [
                    "title": FunctionParameter(
                        type: "string",
                        description: "A short description of the subject, to help the user identify the item from a list",
                        enum_values: nil
                    ),
                    "quantity": FunctionParameter(
                        type: "string",
                        description: "The number of instances of this item, or empty string if unclear",
                        enum_values: nil
                    ),
                    "description": FunctionParameter(
                        type: "string",
                        description: "A slightly longer description of the subject, limited to 160 characters",
                        enum_values: nil
                    ),
                    "make": FunctionParameter(
                        type: "string",
                        description: "The brand or manufacturer associated with the subject",
                        enum_values: nil
                    ),
                    "model": FunctionParameter(
                        type: "string",
                        description: "The model name or number associated with the subject",
                        enum_values: nil
                    ),
                    "category": FunctionParameter(
                        type: "string",
                        description: "The general category of household item",
                        enum_values: categories
                    ),
                    "location": FunctionParameter(
                        type: "string",
                        description: "The most likely room or location in the house",
                        enum_values: locations
                    ),
                    "price": FunctionParameter(
                        type: "string",
                        description: "The estimated original price in US dollars (e.g., $10.99). Provide a single value, not a range.",
                        enum_values: nil
                    )
                ],
                required: ["title", "quantity", "description", "make", "model", "category", "location", "price"]
            )
        )
        
        var urlRequest = URLRequest(url: url)
        
        urlRequest.httpMethod = httpMethod.rawValue
        
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let textMessage = MessageContent(type: "text", text: imagePrompt, image_url: nil)
        let imageMessage = MessageContent(type: "image_url", text: nil, image_url: ImageURL(url: "data:image/png:base64,\(imageBase64)", detail: "\(settings.isHighDetail ? "high" : "low")"))
        let message = Message(role: "user", content: [textMessage, imageMessage])
        let payload = GPTPayload(
            model: settings.aiModel,
            messages: [message],
            max_tokens: settings.maxTokens,
            functions: [function],
            function_call: ["name": "process_inventory_item"]
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try encoder.encode(payload)
            urlRequest.httpBody = jsonData
        } catch {
            print("Error encoding payload: \(error)")
        }
        
        // Add Authorization header with JWT
        urlRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return urlRequest
    }
    
    func getImageDetails() async throws -> ImageDetails {
        let urlRequest = try await MainActor.run {
            try generateURLRequest(httpMethod: .post)
        }
        
        print("🚀 Sending request to: \(urlRequest.url?.absoluteString ?? "unknown URL")")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse(statusCode: 0, responseData: "Invalid HTTP Response")
        }
        
        print("📥 Response status code: \(httpResponse.statusCode)")
        
        let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
        print("📥 Response body: \(responseString)")
        
        // Handle common HTTP error codes
        switch httpResponse.statusCode {
        case 200:
            break // Success, continue processing
        case 413:
            throw OpenAIError.serverError("Image is too large. Please try with a smaller image.")
        case 429:
            throw OpenAIError.rateLimitExceeded
        case 400...499:
            throw OpenAIError.invalidResponse(statusCode: httpResponse.statusCode, responseData: responseString)
        case 500...599:
            throw OpenAIError.serverError("Server is temporarily unavailable. Please try again later.")
        default:
            throw OpenAIError.invalidResponse(statusCode: httpResponse.statusCode, responseData: responseString)
        }
        
        do {
            // First try to parse as a Lambda error response
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                throw OpenAIError.serverError(errorMessage)
            }
            
            // If not an error, try to parse as GPTResponse
            let gptResponse = try JSONDecoder().decode(GPTResponse.self, from: data)
            
            guard let functionCall = gptResponse.choices.first?.message.function_call,
                  let responseData = functionCall.arguments.data(using: .utf8) else {
                throw OpenAIError.invalidData
            }
            
            return try JSONDecoder().decode(ImageDetails.self, from: responseData)
        } catch {
            print("❌ Error processing response: \(error)")
            if error is OpenAIError {
                throw error
            }
            throw OpenAIError.invalidData
        }
    }
}

#if DEBUG
extension OpenAIService {
    func decodePayload(from data: Data) throws -> GPTPayload {
        return try JSONDecoder().decode(GPTPayload.self, from: data)
    }
    
    func decodeResponse(from data: Data) throws -> GPTResponse {
        return try JSONDecoder().decode(GPTResponse.self, from: data)
    }
}
#endif

struct Message: Codable {
    let role: String
    let content: [MessageContent]
}

struct MessageContent: Codable {
    let type: String
    let text: String?
    let image_url: ImageURL?
}

struct ImageURL: Codable {
    let url: String
    let detail: String
}

struct GPTPayload: Codable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
    let functions: [FunctionDefinition]
    let function_call: [String: String]
}

struct GPTResponse: Decodable {
    let choices: [GPTCompletionResponse]
}

struct GPTCompletionResponse: Decodable {
    let message: GPTMessageResponse
}

struct GPTMessageResponse: Decodable {
    let function_call: FunctionCall?
}

struct FunctionCall: Decodable {
    let name: String
    let arguments: String
}

struct ImageDetails: Decodable {
    let title: String
    let quantity: String
    let description: String
    let make: String
    let model: String
    let category: String
    let location: String
    let price: String
}
