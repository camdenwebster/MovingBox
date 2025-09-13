//
//  OpenAIService.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import AIProxy
import Foundation
import SwiftData
import CryptoKit
import UIKit


// MARK: - Service Protocols

protocol OpenAIServiceProtocol {
    func getImageDetails(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws -> ImageDetails
    func cancelCurrentRequest()
}

protocol ImageManagerProtocol {
    func saveImage(_ image: UIImage, id: String) async throws -> URL
    func saveSecondaryImages(_ images: [UIImage], itemId: String) async throws -> [String]
    func loadImage(url: URL) async throws -> UIImage
    func loadSecondaryImages(from urls: [String]) async throws -> [UIImage]
    func deleteSecondaryImage(urlString: String) async throws
    func prepareImageForAI(from image: UIImage) async -> String?
    func getThumbnailURL(for id: String) -> URL?
}

protocol DataParserProtocol {
    func parseDimensions(_ dimensionsString: String) -> (length: String, width: String, height: String, unit: String)?
    func parseWeight(_ weightString: String) -> (value: String, unit: String)?
    func formatInitialPrice(_ price: Decimal) -> String
}

protocol PriceFormatterProtocol {
    func formatPrice(_ price: Decimal) -> String
    func parsePrice(from string: String) -> Decimal?
}

// MARK: - OpenAI Request Builder

struct OpenAIRequestBuilder {
    let openAIService = AIProxy.openAIService(
        partialKey: "v2|5c7e57d7|ilrKAnl-45-YCHAB",
        serviceURL: "https://api.aiproxy.com/1530daf2/e2ce41d0"
    )
    
    @MainActor
    func buildRequestBody(
        with images: [UIImage],
        settings: SettingsManager,
        modelContext: ModelContext
    ) async -> OpenAIChatCompletionRequestBody {
        let categories = DefaultDataManager.getAllLabels(from: modelContext)
        let locations = DefaultDataManager.getAllLocations(from: modelContext)
        
        let imagePrompt = createImagePrompt(for: images.count)
        let function = buildFunctionDefinition(
            imageCount: images.count,
            categories: categories,
            locations: locations
        )
        
        let messageContent = await buildMessageContent(
            prompt: imagePrompt,
            images: images,
            settings: settings
        )
        
        // Calculate proper token limit based on image count and quality
        let adjustedMaxTokens = calculateTokenLimit(imageCount: images.count, settings: settings)
        
        // Build proper function definition with actual properties
        let parametersDict = buildFunctionParameters(function: function)
        
        return OpenAIChatCompletionRequestBody(
            model: settings.effectiveAIModel,
            messages: messageContent,
            maxCompletionTokens: adjustedMaxTokens,
            tools: [
                .function(
                    name: function.name,
                    description: function.description,
                    parameters: parametersDict,
                    strict: function.strict ?? false
                )
            ],
            toolChoice: .specific(functionName: "process_inventory_item")
        )
    }
    
    
    
    private func createImagePrompt(for imageCount: Int) -> String {
        if imageCount > 1 {
            return "Analyze these \(imageCount) images which show the same item from different angles and perspectives. Combine all the visual information from all images to create ONE comprehensive description of this single item. Pay special attention to any text, labels, stickers, or engravings that might contain a serial number, model number, or product identification. Return only ONE response that describes the item based on all the photos together."
        } else {
            return "Analyze this image and identify the item which is the primary subject of the photo, along with its attributes. Pay special attention to any text, labels, stickers, or engravings that might contain a serial number, model number, or product identification."
        }
    }
    
    private func buildFunctionDefinition(
        imageCount: Int,
        categories: [String],
        locations: [String]
    ) -> FunctionDefinition {
        let enabledProperties = AIPromptConfiguration.getAllEnabledProperties(
            categories: categories,
            locations: locations
        )
        
        var properties: [String: FunctionParameter] = [:]
        var requiredFields: [String] = []
        
        for (propertyName, config) in enabledProperties {
            let description = adjustDescriptionForMultipleImages(
                description: config.description,
                propertyName: propertyName,
                imageCount: imageCount
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
        
        return FunctionDefinition(
            name: "process_inventory_item",
            description: imageCount > 1 
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
    }
    
    @MainActor
    private func buildMessageContent(
        prompt: String,
        images: [UIImage],
        settings: SettingsManager
    ) async -> [OpenAIChatCompletionRequestBody.Message] {
        var parts: [OpenAIChatCompletionRequestBody.Message.ContentPart] = []
        
        // Add the text prompt first
        parts.append(.text(prompt))
        
        // Resize and convert each UIImage using AIProxy's native method
        for image in images {
            // Resize image based on Pro settings to save bandwidth and improve API speed
            let targetResolution = settings.effectiveImageResolution
            let resizedImage = await OptimizedImageManager.shared.optimizeImage(image, maxDimension: targetResolution)
            
            if let imageURL = AIProxy.encodeImageAsURL(image: resizedImage, compressionQuality: 0.8) {
                // Use .auto detail as shown in AIProxy documentation
                parts.append(.imageURL(imageURL, detail: .auto))
            }
        }
        
        return [.user(content: .parts(parts))]
    }
    
    private func adjustDescriptionForMultipleImages(
        description: String,
        propertyName: String,
        imageCount: Int
    ) -> String {
        guard imageCount > 1 else { return description }
        
        switch propertyName {
        case "description":
            return "A single concise description combining details from all \(imageCount) photos of this one item, limited to 160 characters"
        case "serialNumber":
            return "The serial number, product ID, or model identifier if visible in any of the \(imageCount) photos, or empty string if not found"
        default:
            return description
        }
    }
    
    private func getPropertyType(for propertyName: String) -> String {
        switch propertyName {
        case "isFragile":
            return "string" // We'll handle boolean as string for simplicity
        default:
            return "string"
        }
    }
    
    @MainActor
    private func calculateTokenLimit(imageCount: Int, settings: SettingsManager) -> Int {
        // Base token limit for single image with low quality
        let baseTokens = 3000
        
        // Add 300 tokens for each additional image (up to 5 images max)
        let imageCount = min(imageCount, 5) // Cap at 5 images
        let additionalTokens = max(0, (imageCount - 1)) * 300
        let lowQualityTokens = baseTokens + additionalTokens
        
        // Apply 3x multiplier for high quality images (Pro + high quality enabled)
        let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
        let finalTokens = isHighQuality ? lowQualityTokens * 3 : lowQualityTokens
        
        return finalTokens
    }
    
    private func buildFunctionParameters(function: FunctionDefinition) -> [String: AIProxyJSONValue] {
        var parametersDict: [String: AIProxyJSONValue] = [:]
        
        // Convert the function parameters to AIProxyJSONValue format
        parametersDict["type"] = .string(function.parameters.type)
        parametersDict["additionalProperties"] = .bool(function.parameters.additionalProperties)
        parametersDict["required"] = .array(function.parameters.required.map { .string($0) })
        
        // Convert properties
        var propertiesDict: [String: AIProxyJSONValue] = [:]
        for (key, parameter) in function.parameters.properties {
            var propertyDict: [String: AIProxyJSONValue] = [:]
            propertyDict["type"] = .string(parameter.type)
            
            if let description = parameter.description {
                propertyDict["description"] = .string(description)
            }
            
            if let enumValues = parameter.enum_values {
                propertyDict["enum"] = .array(enumValues.map { .string($0) })
            }
            
            propertiesDict[key] = .object(propertyDict)
        }
        parametersDict["properties"] = .object(propertiesDict)
        
        return parametersDict
    }
}

// MARK: - OpenAI Response Parser

struct OpenAIResponseParser {
    
    struct ParseResult {
        let imageDetails: ImageDetails
        let usage: TokenUsage?
    }
    
    @MainActor
    private func calculateTokenLimit(imageCount: Int, settings: SettingsManager) -> Int {
        // Base token limit for single image with low quality
        let baseTokens = 3000
        
        // Add 300 tokens for each additional image (up to 5 images max)
        let imageCount = min(imageCount, 5) // Cap at 5 images
        let additionalTokens = max(0, (imageCount - 1)) * 300
        let lowQualityTokens = baseTokens + additionalTokens
        
        // Apply 3x multiplier for high quality images (Pro + high quality enabled)
        let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
        let finalTokens = isHighQuality ? lowQualityTokens * 3 : lowQualityTokens
        
        return finalTokens
    }
    
    @MainActor
    func parseAIProxyResponse(
        response: OpenAIChatCompletionResponseBody,
        imageCount: Int,
        startTime: Date,
        settings: SettingsManager
    ) throws -> ParseResult {
        print("✅ Processing AIProxy response with \(response.choices.count) choices")
        
        // Log comprehensive token usage information
        if let usage = response.usage {
            logAIProxyTokenUsage(
                usage: usage,
                elapsedTime: Date().timeIntervalSince(startTime),
                imageCount: imageCount,
                settings: settings
            )
        } else {
            print("⚠️ No token usage information in response")
        }
        
        // Extract and validate response
        guard let choice = response.choices.first else {
            print("❌ No choices in response")
            throw OpenAIError.invalidData
        }
        
        guard let toolCalls = choice.message.toolCalls, !toolCalls.isEmpty else {
            print("❌ No tool calls in response")
            print("📝 Response message: \(choice.message)")
            throw OpenAIError.invalidData
        }
        
        let toolCall = toolCalls[0]
        print("🎯 Tool call received: \(toolCall.function.name)")
        
        // Get arguments as string - AIProxy provides argumentsRaw for JSON string
        let argumentsString = toolCall.function.argumentsRaw ?? ""
        print("📄 Arguments length: \(argumentsString.count) characters")
        
        guard let responseData = argumentsString.data(using: .utf8) else {
            print("❌ Cannot convert function arguments to data")
            print("📄 Raw arguments: \(argumentsString)")
            throw OpenAIError.invalidData
        }
        
        let result = try JSONDecoder().decode(ImageDetails.self, from: responseData)
        
        // Convert AIProxy usage to our TokenUsage type for compatibility
        let tokenUsage = response.usage != nil ? convertAIProxyUsage(response.usage!) : nil
        
        return ParseResult(imageDetails: result, usage: tokenUsage)
    }
    
    
    private func convertAIProxyUsage(_ aiProxyUsage: OpenAIChatUsage) -> TokenUsage {
        return TokenUsage(
            prompt_tokens: aiProxyUsage.promptTokens ?? 0,
            completion_tokens: aiProxyUsage.completionTokens ?? 0,
            total_tokens: aiProxyUsage.totalTokens ?? 0,
            prompt_tokens_details: nil,
            completion_tokens_details: nil
        )
    }
    
    @MainActor
    private func logAIProxyTokenUsage(
        usage: OpenAIChatUsage,
        elapsedTime: TimeInterval,
        imageCount: Int,
        settings: SettingsManager
    ) {
        print("💰 TOKEN USAGE REPORT")
        print("   📊 Total tokens: \(usage.totalTokens ?? 0)")
        print("   📝 Prompt tokens: \(usage.promptTokens ?? 0)")
        print("   🤖 Completion tokens: \(usage.completionTokens ?? 0)")
        print("   ⏱️ Request time: \(String(format: "%.2f", elapsedTime))s")
        print("   🖼️ Images: \(imageCount) (\(imageCount == 1 ? "single" : "multi")-photo analysis)")
        
        // Calculate token efficiency metrics
        let totalTokens = usage.totalTokens ?? 0
        let tokensPerSecond = Double(totalTokens) / elapsedTime
        print("   🚀 Efficiency: \(String(format: "%.1f", tokensPerSecond)) tokens/sec")
        
        // Check if we're approaching token limits
        let adjustedMaxTokens = calculateTokenLimit(imageCount: imageCount, settings: settings)
        let usagePercentage = Double(totalTokens) / Double(adjustedMaxTokens) * 100.0
        
        if usagePercentage > 90.0 {
            print("⚠️ WARNING: Token usage at \(String(format: "%.1f", usagePercentage))% of limit (\(totalTokens)/\(adjustedMaxTokens))")
        } else if usagePercentage > 75.0 {
            print("⚡ High token usage: \(String(format: "%.1f", usagePercentage))% of limit (\(totalTokens)/\(adjustedMaxTokens))")
        } else {
            print("✅ Token usage: \(String(format: "%.1f", usagePercentage))% of limit (\(totalTokens)/\(adjustedMaxTokens))")
        }
        
        // Track token usage in telemetry for monitoring trends
        TelemetryManager.shared.trackAITokenUsage(
            totalTokens: usage.totalTokens ?? 0,
            promptTokens: usage.promptTokens ?? 0,
            completionTokens: usage.completionTokens ?? 0,
            requestTimeSeconds: elapsedTime,
            imageCount: imageCount,
            isProUser: settings.isPro,
            model: settings.effectiveAIModel
        )
    }
    
    @MainActor
    private func logTokenUsage(
        usage: TokenUsage,
        elapsedTime: TimeInterval,
        requestSize: Int,
        imageCount: Int,
        settings: SettingsManager
    ) {
        let requestSizeMB = Double(requestSize) / 1_000_000.0
        
        print("💰 TOKEN USAGE REPORT")
        print("   📊 Total tokens: \(usage.total_tokens)")
        print("   📝 Prompt tokens: \(usage.prompt_tokens)")
        print("   🤖 Completion tokens: \(usage.completion_tokens)")
        print("   ⏱️ Request time: \(String(format: "%.2f", elapsedTime))s")
        print("   📦 Request size: \(String(format: "%.2f", requestSizeMB))MB")
        print("   🖼️ Images: \(imageCount) (\(imageCount == 1 ? "single" : "multi")-photo analysis)")
        
        // Calculate token efficiency metrics
        let tokensPerSecond = Double(usage.total_tokens) / elapsedTime
        let tokensPerMB = Double(usage.total_tokens) / max(requestSizeMB, 0.001)
        print("   🚀 Efficiency: \(String(format: "%.1f", tokensPerSecond)) tokens/sec, \(String(format: "%.0f", tokensPerMB)) tokens/MB")
        
        // Log detailed token breakdown if available
        if let promptDetails = usage.prompt_tokens_details {
            print("   📋 Prompt details:")
            if let cached = promptDetails.cached_tokens {
                print("      🗄️ Cached tokens: \(cached)")
            }
            if let audio = promptDetails.audio_tokens {
                print("      🎵 Audio tokens: \(audio)")
            }
        }
        
        if let completionDetails = usage.completion_tokens_details {
            print("   📝 Completion details:")
            if let reasoning = completionDetails.reasoning_tokens {
                print("      🧠 Reasoning tokens: \(reasoning)")
            }
            if let audio = completionDetails.audio_tokens {
                print("      🎵 Audio tokens: \(audio)")
            }
            if let accepted = completionDetails.accepted_prediction_tokens {
                print("      ✅ Accepted prediction tokens: \(accepted)")
            }
            if let rejected = completionDetails.rejected_prediction_tokens {
                print("      ❌ Rejected prediction tokens: \(rejected)")
            }
        }
        
        // Check if we're approaching token limits
        let adjustedMaxTokens = calculateTokenLimit(imageCount: imageCount, settings: settings)
        let usagePercentage = Double(usage.total_tokens) / Double(adjustedMaxTokens) * 100.0
        
        if usagePercentage > 90.0 {
            print("⚠️ WARNING: Token usage at \(String(format: "%.1f", usagePercentage))% of limit (\(usage.total_tokens)/\(adjustedMaxTokens))")
        } else if usagePercentage > 75.0 {
            print("⚡ High token usage: \(String(format: "%.1f", usagePercentage))% of limit (\(usage.total_tokens)/\(adjustedMaxTokens))")
        } else {
            print("✅ Token usage: \(String(format: "%.1f", usagePercentage))% of limit (\(usage.total_tokens)/\(adjustedMaxTokens))")
        }
        
        // Track token usage in telemetry for monitoring trends
        TelemetryManager.shared.trackAITokenUsage(
            totalTokens: usage.total_tokens,
            promptTokens: usage.prompt_tokens,
            completionTokens: usage.completion_tokens,
            requestTimeSeconds: elapsedTime,
            imageCount: imageCount,
            isProUser: settings.isPro,
            model: settings.effectiveAIModel
        )
    }
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
            enabled: false,
            description: "Estimated dimensions in format 'L x W x H' with units (e.g., '24\" x 16\" x 8\"'), or empty string if unclear"
        ),
        "dimensionLength": AIPropertyConfig(
            enabled: true,
            description: "Estimated length/width dimension value only (number without units)"
        ),
        "dimensionWidth": AIPropertyConfig(
            enabled: true,
            description: "Estimated width dimension value only (number without units)"
        ),
        "dimensionHeight": AIPropertyConfig(
            enabled: true,
            description: "Estimated height dimension value only (number without units)"
        ),
        "dimensionUnit": AIPropertyConfig(
            enabled: true,
            description: "Most appropriate unit for the dimensions",
            enumValues: ["inches", "feet", "cm", "m"]
        ),
        "weight": AIPropertyConfig(
            enabled: false,
            description: "Estimated weight with units (e.g., '5.2 lbs', '2.3 kg'), or empty string if unclear"
        ),
        "weightValue": AIPropertyConfig(
            enabled: true,
            description: "Estimated weight value only (number without units)"
        ),
        "weightUnit": AIPropertyConfig(
            enabled: true,
            description: "Most appropriate unit for the weight",
            enumValues: ["lbs", "kg", "oz", "g"]
        ),
        "purchaseLocation": AIPropertyConfig(
            enabled: true,
            description: "Most likely place this item would be purchased (e.g., 'Apple Store', 'Best Buy', 'Amazon'), or empty string if unclear"
        ),
        "replacementCost": AIPropertyConfig(
            enabled: true,
            description: "Estimated current replacement cost in US dollars (e.g., $15.99), or empty string if unclear"
        ),
        "depreciationRate": AIPropertyConfig(
            enabled: true,
            description: "Annual depreciation rate as a percentage (e.g., 15%), or empty string if unclear"
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
class OpenAIService: OpenAIServiceProtocol {
    
    @MainActor
    private func calculateTokenLimit(imageCount: Int, settings: SettingsManager) -> Int {
        // Base token limit for single image with low quality
        let baseTokens = 3000
        
        // Add 300 tokens for each additional image (up to 5 images max)
        let imageCount = min(imageCount, 5) // Cap at 5 images
        let additionalTokens = max(0, (imageCount - 1)) * 300
        let lowQualityTokens = baseTokens + additionalTokens
        
        // Apply 3x multiplier for high quality images (Pro + high quality enabled)
        let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
        let finalTokens = isHighQuality ? lowQualityTokens * 3 : lowQualityTokens
        
        return finalTokens
    }
    // Track current request to allow cancellation
    private var currentTask: Task<ImageDetails, Error>?
    
    private let requestBuilder = OpenAIRequestBuilder()
    private let responseParser = OpenAIResponseParser()
    
    init() {
        // Stateless service - no stored properties needed
    }
    
    
    
    func getImageDetails(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws -> ImageDetails {
        // Cancel any existing request
        currentTask?.cancel()
        
        // Create new task for this request
        currentTask = Task {
            return try await performRequestWithRetry(images: images, settings: settings, modelContext: modelContext)
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
    
    private func performRequestWithRetry(images: [UIImage], settings: SettingsManager, modelContext: ModelContext, maxAttempts: Int = 3) async throws -> ImageDetails {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            // Check for task cancellation
            try Task.checkCancellation()
            
            do {
                return try await performSingleRequest(images: images, settings: settings, modelContext: modelContext, attempt: attempt, maxAttempts: maxAttempts)
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
                
                // Handle AIProxy specific errors
                if let aiProxyError = error as? AIProxyError {
                    switch aiProxyError {
                    case .unsuccessfulRequest(let statusCode, let responseBody):
                        print("🌐 AIProxy error \(statusCode): \(responseBody)")
                        
                        // Handle specific HTTP status codes
                        switch statusCode {
                        case 429: // Rate limited
                            if attempt < maxAttempts {
                                print("⏱️ Rate limited, retrying attempt \(attempt + 1)/\(maxAttempts)")
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw OpenAIError.rateLimitExceeded
                            }
                        case 413: // Payload too large
                            throw OpenAIError.serverError("Image is too large. Please try with a smaller image.")
                        case 500...599: // Server errors - retryable
                            if attempt < maxAttempts {
                                print("🔄 Server error \(statusCode), retrying attempt \(attempt + 1)/\(maxAttempts)")
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw OpenAIError.serverError("Server is temporarily unavailable. Please try again later.")
                            }
                        case 400...499: // Client errors - not retryable
                            throw OpenAIError.invalidResponse(statusCode: statusCode, responseData: responseBody)
                        default:
                            if attempt < maxAttempts {
                                print("🔄 Unknown AIProxy error \(statusCode), retrying attempt \(attempt + 1)/\(maxAttempts)")
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw OpenAIError.serverError(responseBody)
                            }
                        }
                    @unknown default:
                        // Handle any future AIProxy error cases
                        if attempt < maxAttempts {
                            print("🔄 Unknown AIProxy error, retrying attempt \(attempt + 1)/\(maxAttempts)")
                            let delay = min(pow(2.0, Double(attempt)), 8.0)
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            try Task.checkCancellation()
                            continue
                        } else {
                            throw OpenAIError.serverError("Unknown AIProxy error occurred")
                        }
                    }
                }
                
                // Handle URLError for network-level issues (still possible with AIProxy)
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .cancelled:
                        if attempt < maxAttempts {
                            print("🔄 Request cancelled, retrying attempt \(attempt + 1)/\(maxAttempts)")
                            let delay = min(pow(2.0, Double(attempt)), 8.0)
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            try Task.checkCancellation()
                            continue
                        } else {
                            throw OpenAIError.networkCancelled
                        }
                    case .timedOut:
                        if attempt < maxAttempts {
                            print("⏱️ Request timed out, retrying attempt \(attempt + 1)/\(maxAttempts)")
                            let delay = min(pow(2.0, Double(attempt)), 8.0)
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            try Task.checkCancellation()
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
                            try Task.checkCancellation()
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
    
    private func performSingleRequest(images: [UIImage], settings: SettingsManager, modelContext: ModelContext, attempt: Int, maxAttempts: Int) async throws -> ImageDetails {
        guard !images.isEmpty else {
            throw OpenAIError.invalidData
        }
        
        // Build request body using AIProxy with UIImages directly - no base64 conversion needed
        // AIProxy handles image encoding internally via encodeImageAsURL
        let requestBody = await requestBuilder.buildRequestBody(
            with: images,
            settings: settings,
            modelContext: modelContext
        )
        
        let imageCount = images.count
        let useHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
        
        if attempt == 1 {
            print("🚀 Sending \(imageCount == 1 ? "single" : "multi") image request via AIProxy")
            print("📊 Images: \(imageCount)")
            
            // Calculate and log the token limit being used
            let adjustedMaxTokens = calculateTokenLimit(imageCount: imageCount, settings: settings)
            let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
            print("🤖 AI Settings - Model: \(settings.effectiveAIModel), Detail: \(settings.effectiveDetailLevel), Pro: \(settings.isPro), High Quality: \(isHighQuality)")
            print("🎯 Token limit: \(adjustedMaxTokens) (base: 3000, \(imageCount) images, \(isHighQuality ? "3x quality multiplier" : "standard quality"))")
            
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
        
        let startTime = Date()
        let response = try await requestBuilder.openAIService.chatCompletionRequest(body: requestBody, secondsToWait: 60)
        
        print("✅ Received AIProxy response with \(response.choices.count) choices")
        
        do {
            // Parse AIProxy response directly
            let parseResult = try await responseParser.parseAIProxyResponse(
                response: response,
                imageCount: imageCount,
                startTime: startTime,
                settings: settings
            )
            
            let result = parseResult.imageDetails
            
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
            throw OpenAIError.invalidData
        } catch DecodingError.keyNotFound(let key, let context) {
            print("❌ Key not found: \(key) in \(context)")
            throw OpenAIError.invalidData
        } catch DecodingError.typeMismatch(let type, let context) {
            print("❌ Type mismatch: \(type) in \(context)")
            throw OpenAIError.invalidData
        } catch DecodingError.valueNotFound(let type, let context) {
            print("❌ Value not found: \(type) in \(context)")
            throw OpenAIError.invalidData
        } catch {
            print("❌ Error processing response: \(error)")
            
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


// Keep TokenUsage for compatibility with existing telemetry code
struct TokenUsage: Decodable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
    let prompt_tokens_details: PromptTokensDetails?
    let completion_tokens_details: CompletionTokensDetails?
}

struct PromptTokensDetails: Decodable {
    let cached_tokens: Int?
    let audio_tokens: Int?
}

struct CompletionTokensDetails: Decodable {
    let reasoning_tokens: Int?
    let audio_tokens: Int?
    let accepted_prediction_tokens: Int?
    let rejected_prediction_tokens: Int?
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
    let weightValue: String?
    let weightUnit: String?
    let purchaseLocation: String?
    let replacementCost: String?
    let depreciationRate: String?
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
        weightValue = try container.decodeIfPresent(String.self, forKey: .weightValue)
        weightUnit = try container.decodeIfPresent(String.self, forKey: .weightUnit)
        purchaseLocation = try container.decodeIfPresent(String.self, forKey: .purchaseLocation)
        replacementCost = try container.decodeIfPresent(String.self, forKey: .replacementCost)
        depreciationRate = try container.decodeIfPresent(String.self, forKey: .depreciationRate)
        storageRequirements = try container.decodeIfPresent(String.self, forKey: .storageRequirements)
        isFragile = try container.decodeIfPresent(String.self, forKey: .isFragile)
    }
    
    private enum CodingKeys: String, CodingKey {
        case title, quantity, description, make, model, category, location, price, serialNumber
        case condition, color, dimensions, dimensionLength, dimensionWidth, dimensionHeight, dimensionUnit
        case weightValue, weightUnit, purchaseLocation, replacementCost, depreciationRate, storageRequirements, isFragile
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
            weightValue: nil,
            weightUnit: nil,
            purchaseLocation: nil,
            replacementCost: nil,
            depreciationRate: nil,
            storageRequirements: nil,
            isFragile: nil
        )
    }
    
    // Memberwise initializer for manual construction
    init(title: String, quantity: String, description: String, make: String, model: String,
         category: String, location: String, price: String, serialNumber: String,
         condition: String? = nil, color: String? = nil, dimensions: String? = nil,
         dimensionLength: String? = nil, dimensionWidth: String? = nil, dimensionHeight: String? = nil,
         dimensionUnit: String? = nil, weightValue: String? = nil,
         weightUnit: String? = nil, purchaseLocation: String? = nil, replacementCost: String? = nil,
         depreciationRate: String? = nil, storageRequirements: String? = nil, isFragile: String? = nil) {
        
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
        self.weightValue = weightValue
        self.weightUnit = weightUnit
        self.purchaseLocation = purchaseLocation
        self.replacementCost = replacementCost
        self.depreciationRate = depreciationRate
        self.storageRequirements = storageRequirements
        self.isFragile = isFragile
    }
}
