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

struct Tool: Codable {
    let type: String
    let function: FunctionDefinition
}

struct FunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: Parameters
    let strict: Bool?
    
    struct Parameters: Codable {
        let type: String
        let properties: [String: FunctionParameter]
        let required: [String]
        let additionalProperties: Bool
    }
}

@MainActor
class OpenAIService {
    var imageBase64: String
    var imageBase64Array: [String]
    var settings: SettingsManager
    var modelContext: ModelContext
    
    private let baseURL = "https://7mc060nx64.execute-api.us-east-2.amazonaws.com/prod"
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120.0 // 2 minutes
        config.timeoutIntervalForResource = 180.0 // 3 minutes
        return URLSession(configuration: config)
    }()
    
    init(imageBase64: String, settings: SettingsManager, modelContext: ModelContext) {
        self.imageBase64 = imageBase64
        self.imageBase64Array = [imageBase64]
        self.settings = settings
        self.modelContext = modelContext
    }
    
    init(imageBase64Array: [String], settings: SettingsManager, modelContext: ModelContext) {
        self.imageBase64 = imageBase64Array.first ?? ""
        self.imageBase64Array = imageBase64Array
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
        
        let imagePrompt = imageBase64Array.count > 1 
            ? "Analyze these \(imageBase64Array.count) images which show the same item from different angles and perspectives. Combine all the visual information from all images to create ONE comprehensive description of this single item. Pay special attention to any text, labels, stickers, or engravings that might contain a serial number, model number, or product identification. Return only ONE response that describes the item based on all the photos together."
            : "Analyze this image and identify the item which is the primary subject of the photo, along with its attributes. Pay special attention to any text, labels, stickers, or engravings that might contain a serial number, model number, or product identification."
        
        let function = FunctionDefinition(
            name: "process_inventory_item",
            description: imageBase64Array.count > 1 
                ? "Process and structure information about ONE inventory item based on multiple photos. Return only ONE item description that combines information from all images."
                : "Process and structure information about an inventory item",
            parameters: FunctionDefinition.Parameters(
                type: "object",
                properties: [
                    "title": FunctionParameter(
                        type: "string",
                        description: "A concise name of the subject, to help the user identify the item from a list. Do not include descriptors such as color, instead use make, model or generic name of the item.",
                        enum_values: nil
                    ),
                    "quantity": FunctionParameter(
                        type: "string",
                        description: "The number of instances of this item, or empty string if unclear",
                        enum_values: nil
                    ),
                    "description": FunctionParameter(
                        type: "string", 
                        description: imageBase64Array.count > 1 
                            ? "A single concise description combining details from all \(imageBase64Array.count) photos of this one item, limited to 160 characters"
                            : "A description of the subject, limited to 160 characters",
                        enum_values: nil
                    ),
                    "make": FunctionParameter(
                        type: "string",
                        description: "The brand or manufacturer associated with the subject, or empty string if unclear",
                        enum_values: nil
                    ),
                    "model": FunctionParameter(
                        type: "string",
                        description: "The model name or number associated with the subject, or empty string if unclear",
                        enum_values: nil
                    ),
                    "category": FunctionParameter(
                        type: "string",
                        description: "The general category of household item",
                        enum_values: categories
                    ),
                    "location": FunctionParameter(
                        type: "string",
                        description: "The most likely room or location in the house to find this item",
                        enum_values: locations
                    ),
                    "price": FunctionParameter(
                        type: "string",
                        description: "The estimated original price in US dollars (e.g., $10.99). Provide a single value, not a range.",
                        enum_values: nil
                    ),
                    "serialNumber": FunctionParameter(
                        type: "string",
                        description: imageBase64Array.count > 1 
                            ? "The serial number, product ID, or model identifier if visible in any of the \(imageBase64Array.count) photos, or empty string if not found"
                            : "The serial number, product ID, or model identifier if visible in the image, or empty string if not found",
                        enum_values: nil
                    )
                ],
                required: ["title", "quantity", "description", "make", "model", "category", "location", "price", "serialNumber"],
                additionalProperties: false
            ),
            strict: true
        )
        
        let tool = Tool(type: "function", function: function)
        
        var urlRequest = URLRequest(url: url)
        
        urlRequest.httpMethod = httpMethod.rawValue
        
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var messageContent: [MessageContent] = []
        
        // Add text prompt
        let textMessage = MessageContent(type: "text", text: imagePrompt, image_url: nil)
        messageContent.append(textMessage)
        
        // Add all images
        for base64Image in imageBase64Array {
            let imageMessage = MessageContent(type: "image_url", text: nil, image_url: ImageURL(url: "data:image/png:base64,\(base64Image)", detail: settings.effectiveDetailLevel))
            messageContent.append(imageMessage)
        }
        
        let message = Message(role: "user", content: messageContent)
        let toolChoice = ToolChoice(type: "function", function: ToolChoiceFunction(name: "process_inventory_item"))
        let payload = GPTPayload(
            model: settings.effectiveAIModel,
            messages: [message],
            max_completion_tokens: settings.maxTokens,
            tools: [tool],
            tool_choice: toolChoice
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
        
        let requestSize = urlRequest.httpBody?.count ?? 0
        let imageCount = imageBase64Array.count
        let useHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
        
        print("🚀 Sending \(imageCount == 1 ? "single" : "multi") image request to: \(urlRequest.url?.absoluteString ?? "unknown URL")")
        print("📊 Request size: \(Double(requestSize) / 1024.0) KB, Images: \(imageCount)")
        print("🤖 AI Settings - Model: \(settings.effectiveAIModel), Detail: \(settings.effectiveDetailLevel), Pro: \(settings.isPro), High Quality: \(settings.highQualityAnalysisEnabled)")
        
        // Track analysis start
        TelemetryManager.shared.trackAIAnalysisStarted(
            isProUser: settings.isPro,
            useHighQuality: useHighQuality,
            model: settings.effectiveAIModel,
            detailLevel: settings.effectiveDetailLevel,
            imageResolution: settings.effectiveImageResolution,
            imageCount: imageCount
        )
        
        // Safety check for extremely large requests
        if requestSize > 20_000_000 { // 20MB limit
            throw OpenAIError.serverError("Request too large: \(Double(requestSize) / 1_000_000.0) MB. Please use smaller images.")
        }
        
        let startTime = Date()
        let (data, response) = try await urlSession.data(for: urlRequest)
        
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
                print("❌ Lambda error response: \(errorMessage)")
                throw OpenAIError.serverError(errorMessage)
            }
            
            // If not an error, try to parse as GPTResponse
            let gptResponse = try JSONDecoder().decode(GPTResponse.self, from: data)
            
            print("✅ Received GPT response with \(gptResponse.choices.count) choices")
            
            guard let choice = gptResponse.choices.first else {
                print("❌ No choices in response")
                throw OpenAIError.invalidData
            }
            
            guard let toolCalls = choice.message.tool_calls, !toolCalls.isEmpty else {
                print("❌ No tool calls in response")
                print("📝 Response message: \(choice.message)")
                throw OpenAIError.invalidData
            }
            
            let toolCall = toolCalls[0]
            print("🎯 Tool call received: \(toolCall.function.name)")
            print("📄 Arguments length: \(toolCall.function.arguments.count) characters")
            
            guard let responseData = toolCall.function.arguments.data(using: .utf8) else {
                print("❌ Cannot convert function arguments to data")
                print("📄 Raw arguments: \(toolCall.function.arguments)")
                
                // Track failure
                let responseTime = Int(Date().timeIntervalSince(startTime) * 1000)
                TelemetryManager.shared.trackAIAnalysisCompleted(
                    isProUser: settings.isPro,
                    useHighQuality: useHighQuality,
                    model: settings.effectiveAIModel,
                    detailLevel: settings.effectiveDetailLevel,
                    imageResolution: settings.effectiveImageResolution,
                    imageCount: imageCount,
                    responseTimeMs: responseTime,
                    success: false
                )
                
                throw OpenAIError.invalidData
            }
            
            let result = try JSONDecoder().decode(ImageDetails.self, from: responseData)
            
            // Track successful completion
            let responseTime = Int(Date().timeIntervalSince(startTime) * 1000)
            TelemetryManager.shared.trackAIAnalysisCompleted(
                isProUser: settings.isPro,
                useHighQuality: useHighQuality,
                model: settings.effectiveAIModel,
                detailLevel: settings.effectiveDetailLevel,
                imageResolution: settings.effectiveImageResolution,
                imageCount: imageCount,
                responseTimeMs: responseTime,
                success: true
            )
            
            return result
        } catch DecodingError.dataCorrupted(let context) {
            print("❌ Data corruption error: \(context)")
            print("📄 Response data: \(responseString)")
            throw OpenAIError.invalidData
        } catch DecodingError.keyNotFound(let key, let context) {
            print("❌ Key not found: \(key) in \(context)")
            print("📄 Response data: \(responseString)")
            throw OpenAIError.invalidData
        } catch DecodingError.typeMismatch(let type, let context) {
            print("❌ Type mismatch: \(type) in \(context)")
            print("📄 Response data: \(responseString)")
            throw OpenAIError.invalidData
        } catch DecodingError.valueNotFound(let type, let context) {
            print("❌ Value not found: \(type) in \(context)")
            print("📄 Response data: \(responseString)")
            throw OpenAIError.invalidData
        } catch {
            print("❌ Error processing response: \(error)")
            print("📄 Response data: \(responseString)")
            
            // Track failure for any unhandled errors
            let responseTime = Int(Date().timeIntervalSince(startTime) * 1000)
            TelemetryManager.shared.trackAIAnalysisCompleted(
                isProUser: settings.isPro,
                useHighQuality: useHighQuality,
                model: settings.effectiveAIModel,
                detailLevel: settings.effectiveDetailLevel,
                imageResolution: settings.effectiveImageResolution,
                imageCount: imageCount,
                responseTimeMs: responseTime,
                success: false
            )
            
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
    let max_completion_tokens: Int
    let tools: [Tool]
    let tool_choice: ToolChoice
}

struct ToolChoice: Codable {
    let type: String
    let function: ToolChoiceFunction
}

struct ToolChoiceFunction: Codable {
    let name: String
}

struct GPTResponse: Decodable {
    let choices: [GPTCompletionResponse]
}

struct GPTCompletionResponse: Decodable {
    let message: GPTMessageResponse
}

struct GPTMessageResponse: Decodable {
    let tool_calls: [ToolCall]?
}

struct ToolCall: Decodable {
    let id: String
    let type: String
    let function: FunctionCall
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
    let serialNumber: String
}
