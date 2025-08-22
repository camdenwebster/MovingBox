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

// MARK: - AI Property Configuration

struct AIPropertyConfig {
    let enabled: Bool
    let description: String
    let enumValues: [String]?
    
    init(enabled: Bool = true, description: String, enumValues: [String]? = nil) {
        self.enabled = enabled
        self.description = description
        self.enumValues = enumValues
    }
}

struct AIPromptConfiguration {
    // Core properties (always enabled)
    static let coreProperties: [String: AIPropertyConfig] = [
        "title": AIPropertyConfig(
            description: "A concise name of the subject, to help the user identify the item from a list. Do not include descriptors such as color, instead use make, model or generic name of the item."
        ),
        "quantity": AIPropertyConfig(
            description: "The number of instances of this item, or empty string if unclear"
        ),
        "description": AIPropertyConfig(
            description: "A description of the subject, limited to 160 characters"
        ),
        "make": AIPropertyConfig(
            description: "The brand or manufacturer associated with the subject, or empty string if unclear"
        ),
        "model": AIPropertyConfig(
            description: "The model name or number associated with the subject, or empty string if unclear"
        ),
        "category": AIPropertyConfig(
            description: "The general category of household item"
        ),
        "location": AIPropertyConfig(
            description: "The most likely room or location in the house to find this item"
        ),
        "price": AIPropertyConfig(
            description: "The estimated original price in US dollars (e.g., $10.99). Provide a single value, not a range."
        ),
        "serialNumber": AIPropertyConfig(
            description: "The serial number, product ID, or model identifier if visible in the image, or empty string if not found"
        )
    ]
    
    // Extended properties (can be toggled)
    static let extendedProperties: [String: AIPropertyConfig] = [
        "condition": AIPropertyConfig(
            enabled: true,
            description: "The apparent condition of the item based on visual inspection",
            enumValues: ["New", "Like New", "Good", "Fair", "Poor"]
        ),
        "color": AIPropertyConfig(
            enabled: true,
            description: "The primary color of the item, or empty string if unclear"
        ),
        "dimensions": AIPropertyConfig(
            enabled: true,
            description: "Estimated dimensions in format 'L x W x H' with units (e.g., '24\" x 16\" x 8\"'), or empty string if unclear"
        ),
        "dimensionLength": AIPropertyConfig(
            enabled: false, // Disable individual dimension components for now
            description: "Estimated length/width dimension value only (number without units)"
        ),
        "dimensionWidth": AIPropertyConfig(
            enabled: false,
            description: "Estimated width dimension value only (number without units)"
        ),
        "dimensionHeight": AIPropertyConfig(
            enabled: false,
            description: "Estimated height dimension value only (number without units)"
        ),
        "dimensionUnit": AIPropertyConfig(
            enabled: false,
            description: "Most appropriate unit for the dimensions"
        ),
        "weight": AIPropertyConfig(
            enabled: true,
            description: "Estimated weight with units (e.g., '5.2 lbs', '2.3 kg'), or empty string if unclear"
        ),
        "weightValue": AIPropertyConfig(
            enabled: false, // Disable individual weight components for now
            description: "Estimated weight value only (number without units)"
        ),
        "weightUnit": AIPropertyConfig(
            enabled: false,
            description: "Most appropriate unit for the weight"
        ),
        "purchaseLocation": AIPropertyConfig(
            enabled: true,
            description: "Most likely place this item would be purchased (e.g., 'Apple Store', 'Best Buy', 'Amazon'), or empty string if unclear"
        ),
        "replacementCost": AIPropertyConfig(
            enabled: true,
            description: "Estimated current replacement cost in US dollars (e.g., $15.99), or empty string if unclear"
        ),
        "storageRequirements": AIPropertyConfig(
            enabled: true,
            description: "Any special storage requirements (e.g., 'Keep dry', 'Climate controlled'), or empty string if none"
        ),
        "isFragile": AIPropertyConfig(
            enabled: true,
            description: "Whether the item is fragile and requires careful handling",
            enumValues: ["true", "false"]
        )
    ]
    
    static func getAllEnabledProperties(categories: [String], locations: [String]) -> [String: AIPropertyConfig] {
        var allProperties = coreProperties
        
        // Add enabled extended properties
        for (key, config) in extendedProperties where config.enabled {
            allProperties[key] = config
        }
        
        // Override enum values for category and location with actual data
        allProperties["category"] = AIPropertyConfig(
            description: coreProperties["category"]!.description,
            enumValues: categories
        )
        allProperties["location"] = AIPropertyConfig(
            description: coreProperties["location"]!.description,
            enumValues: locations
        )
        
        return allProperties
    }
}

enum OpenAIError: Error {
    case invalidURL
    case invalidResponse(statusCode: Int, responseData: String)
    case invalidData
    case rateLimitExceeded
    case serverError(String)
    case networkCancelled
    case networkTimeout
    case networkUnavailable
    
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
        case .networkCancelled:
            return "Request was cancelled. Please try again."
        case .networkTimeout:
            return "Request timed out. Please check your connection and try again."
        case .networkUnavailable:
            return "Network unavailable. Please check your internet connection."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkCancelled, .networkTimeout, .networkUnavailable, .rateLimitExceeded:
            return true
        case .serverError:
            return true
        case .invalidURL, .invalidResponse, .invalidData:
            return false
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
    
    // Track current request to allow cancellation
    private var currentTask: Task<ImageDetails, Error>?
    
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
        
        // Get enabled properties from configuration
        let enabledProperties = AIPromptConfiguration.getAllEnabledProperties(categories: categories, locations: locations)
        
        // Build properties dictionary
        var properties: [String: FunctionParameter] = [:]
        var requiredFields: [String] = []
        
        for (propertyName, config) in enabledProperties {
            let description = adjustDescriptionForMultipleImages(
                description: config.description,
                propertyName: propertyName
            )
            
            properties[propertyName] = FunctionParameter(
                type: getPropertyType(for: propertyName),
                description: description,
                enum_values: config.enumValues
            )
            
            // All core properties are required, extended properties are optional
            if AIPromptConfiguration.coreProperties.keys.contains(propertyName) {
                requiredFields.append(propertyName)
            }
        }
        
        let function = FunctionDefinition(
            name: "process_inventory_item",
            description: imageBase64Array.count > 1 
                ? "Process and structure information about ONE inventory item based on multiple photos. Return only ONE item description that combines information from all images."
                : "Process and structure information about an inventory item",
            parameters: FunctionDefinition.Parameters(
                type: "object",
                properties: properties,
                required: requiredFields,
                additionalProperties: false
            ),
            strict: false
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
        
        // Increase token limit for multiple images to avoid truncation
        let adjustedMaxTokens = imageBase64Array.count > 1 
            ? max(settings.maxTokens, 2000)  // Ensure at least 2000 tokens for multiple images
            : settings.maxTokens
        
        let payload = GPTPayload(
            model: settings.effectiveAIModel,
            messages: [message],
            max_completion_tokens: adjustedMaxTokens,
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
    
    // MARK: - Helper Methods
    
    private func adjustDescriptionForMultipleImages(description: String, propertyName: String) -> String {
        // Adjust certain descriptions for multiple images
        if imageBase64Array.count > 1 {
            switch propertyName {
            case "description":
                return "A single concise description combining details from all \(imageBase64Array.count) photos of this one item, limited to 160 characters"
            case "serialNumber":
                return "The serial number, product ID, or model identifier if visible in any of the \(imageBase64Array.count) photos, or empty string if not found"
            default:
                return description
            }
        }
        return description
    }
    
    private func getPropertyType(for propertyName: String) -> String {
        // Most properties are strings, but we could add special handling for other types here
        switch propertyName {
        case "isFragile":
            return "string" // We'll handle boolean as string for simplicity
        default:
            return "string"
        }
    }
    
    func getImageDetails() async throws -> ImageDetails {
        // Cancel any existing request
        currentTask?.cancel()
        
        // Create new task for this request
        currentTask = Task {
            return try await performRequestWithRetry()
        }
        
        defer {
            currentTask = nil
        }
        
        return try await currentTask!.value
    }
    
    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }
    
    private func performRequestWithRetry(maxAttempts: Int = 3) async throws -> ImageDetails {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            // Check for task cancellation
            try Task.checkCancellation()
            
            do {
                return try await performSingleRequest(attempt: attempt, maxAttempts: maxAttempts)
            } catch {
                lastError = error
                
                // Handle task cancellation errors
                if error is CancellationError {
                    throw error
                }
                
                // Check if error is retryable
                if let openAIError = error as? OpenAIError, !openAIError.isRetryable {
                    throw error
                }
                
                // Check for specific network cancellation error
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .cancelled:
                        if attempt < maxAttempts {
                            print("🔄 Request cancelled, retrying attempt \(attempt + 1)/\(maxAttempts)")
                            let delay = min(pow(2.0, Double(attempt)), 8.0) // Exponential backoff with max 8 seconds
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            try Task.checkCancellation() // Check again after delay
                            continue
                        } else {
                            throw OpenAIError.networkCancelled
                        }
                    case .timedOut:
                        if attempt < maxAttempts {
                            print("⏱️ Request timed out, retrying attempt \(attempt + 1)/\(maxAttempts)")
                            let delay = min(pow(2.0, Double(attempt)), 8.0)
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            try Task.checkCancellation() // Check again after delay
                            continue
                        } else {
                            throw OpenAIError.networkTimeout
                        }
                    case .notConnectedToInternet, .networkConnectionLost:
                        throw OpenAIError.networkUnavailable
                    default:
                        if attempt < maxAttempts {
                            print("🌐 Network error: \(urlError.localizedDescription), retrying attempt \(attempt + 1)/\(maxAttempts)")
                            let delay = min(pow(2.0, Double(attempt)), 8.0)
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            try Task.checkCancellation() // Check again after delay
                            continue
                        }
                    }
                }
                
                // For other retryable errors
                if attempt < maxAttempts {
                    print("🔄 Request failed: \(error.localizedDescription), retrying attempt \(attempt + 1)/\(maxAttempts)")
                    let delay = min(pow(2.0, Double(attempt)), 8.0)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    try Task.checkCancellation() // Check again after delay
                    continue
                } else {
                    throw error
                }
            }
        }
        
        throw lastError ?? OpenAIError.serverError("Maximum retry attempts exceeded")
    }
    
    private func performSingleRequest(attempt: Int, maxAttempts: Int) async throws -> ImageDetails {
        let urlRequest = try await MainActor.run {
            try generateURLRequest(httpMethod: .post)
        }
        
        let requestSize = urlRequest.httpBody?.count ?? 0
        let imageCount = imageBase64Array.count
        let useHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
        
        if attempt == 1 {
            print("🚀 Sending \(imageCount == 1 ? "single" : "multi") image request to: \(urlRequest.url?.absoluteString ?? "unknown URL")")
            print("📊 Request size: \(Double(requestSize) / 1024.0) KB, Images: \(imageCount)")
            
            // Calculate and log the token limit being used
            let adjustedMaxTokens = imageCount > 1 
                ? max(settings.maxTokens, 2000)
                : settings.maxTokens
            print("🤖 AI Settings - Model: \(settings.effectiveAIModel), Detail: \(settings.effectiveDetailLevel), Pro: \(settings.isPro), High Quality: \(settings.highQualityAnalysisEnabled)")
            print("🎯 Token limit: \(adjustedMaxTokens) (base: \(settings.maxTokens), adjusted for \(imageCount) images)")
            
            // Track analysis start (only on first attempt)
            TelemetryManager.shared.trackAIAnalysisStarted(
                isProUser: settings.isPro,
                useHighQuality: useHighQuality,
                model: settings.effectiveAIModel,
                detailLevel: settings.effectiveDetailLevel,
                imageResolution: settings.effectiveImageResolution,
                imageCount: imageCount
            )
        } else {
            print("🔄 Retry attempt \(attempt)/\(maxAttempts)")
        }
        
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
    // Core properties with defaults provided for missing values
    let title: String
    let quantity: String
    let description: String
    let make: String
    let model: String
    let category: String
    let location: String
    let price: String
    let serialNumber: String
    
    // Extended properties (optional, based on AI configuration)
    let condition: String?
    let color: String?
    let dimensions: String?
    let dimensionLength: String?
    let dimensionWidth: String?
    let dimensionHeight: String?
    let dimensionUnit: String?
    let weight: String?
    let weightValue: String?
    let weightUnit: String?
    let purchaseLocation: String?
    let replacementCost: String?
    let storageRequirements: String?
    let isFragile: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Core properties with defaults for missing values
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Unknown Item"
        quantity = try container.decodeIfPresent(String.self, forKey: .quantity) ?? "1"
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? "Item details not available"
        make = try container.decodeIfPresent(String.self, forKey: .make) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Uncategorized"
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? "Unknown"
        price = try container.decodeIfPresent(String.self, forKey: .price) ?? "$0.00"
        serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber) ?? ""
        
        // Extended properties (already optional)
        condition = try container.decodeIfPresent(String.self, forKey: .condition)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        dimensions = try container.decodeIfPresent(String.self, forKey: .dimensions)
        dimensionLength = try container.decodeIfPresent(String.self, forKey: .dimensionLength)
        dimensionWidth = try container.decodeIfPresent(String.self, forKey: .dimensionWidth)
        dimensionHeight = try container.decodeIfPresent(String.self, forKey: .dimensionHeight)
        dimensionUnit = try container.decodeIfPresent(String.self, forKey: .dimensionUnit)
        weight = try container.decodeIfPresent(String.self, forKey: .weight)
        weightValue = try container.decodeIfPresent(String.self, forKey: .weightValue)
        weightUnit = try container.decodeIfPresent(String.self, forKey: .weightUnit)
        purchaseLocation = try container.decodeIfPresent(String.self, forKey: .purchaseLocation)
        replacementCost = try container.decodeIfPresent(String.self, forKey: .replacementCost)
        storageRequirements = try container.decodeIfPresent(String.self, forKey: .storageRequirements)
        isFragile = try container.decodeIfPresent(String.self, forKey: .isFragile)
    }
    
    private enum CodingKeys: String, CodingKey {
        case title, quantity, description, make, model, category, location, price, serialNumber
        case condition, color, dimensions, dimensionLength, dimensionWidth, dimensionHeight, dimensionUnit
        case weight, weightValue, weightUnit, purchaseLocation, replacementCost, storageRequirements, isFragile
    }
    
    // Static factory method for creating empty instances
    static func empty() -> ImageDetails {
        return ImageDetails(
            title: "",
            quantity: "",
            description: "",
            make: "",
            model: "",
            category: "None",
            location: "None",
            price: "",
            serialNumber: "",
            condition: nil,
            color: nil,
            dimensions: nil,
            dimensionLength: nil,
            dimensionWidth: nil,
            dimensionHeight: nil,
            dimensionUnit: nil,
            weight: nil,
            weightValue: nil,
            weightUnit: nil,
            purchaseLocation: nil,
            replacementCost: nil,
            storageRequirements: nil,
            isFragile: nil
        )
    }
    
    // Memberwise initializer for manual construction
    init(title: String, quantity: String, description: String, make: String, model: String,
         category: String, location: String, price: String, serialNumber: String,
         condition: String? = nil, color: String? = nil, dimensions: String? = nil,
         dimensionLength: String? = nil, dimensionWidth: String? = nil, dimensionHeight: String? = nil,
         dimensionUnit: String? = nil, weight: String? = nil, weightValue: String? = nil,
         weightUnit: String? = nil, purchaseLocation: String? = nil, replacementCost: String? = nil,
         storageRequirements: String? = nil, isFragile: String? = nil) {
        
        self.title = title
        self.quantity = quantity
        self.description = description
        self.make = make
        self.model = model
        self.category = category
        self.location = location
        self.price = price
        self.serialNumber = serialNumber
        self.condition = condition
        self.color = color
        self.dimensions = dimensions
        self.dimensionLength = dimensionLength
        self.dimensionWidth = dimensionWidth
        self.dimensionHeight = dimensionHeight
        self.dimensionUnit = dimensionUnit
        self.weight = weight
        self.weightValue = weightValue
        self.weightUnit = weightUnit
        self.purchaseLocation = purchaseLocation
        self.replacementCost = replacementCost
        self.storageRequirements = storageRequirements
        self.isFragile = isFragile
    }
}
