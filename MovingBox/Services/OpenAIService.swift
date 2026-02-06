//
//  OpenAIService.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import AIProxy
import CryptoKit
import Foundation
import SwiftData

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Mock Service for Testing

#if DEBUG
    @MainActor
    class MockOpenAIService: OpenAIServiceProtocol {
        var shouldFail = false
        var shouldFailMultiItem = false

        var mockResponse = ImageDetails(
            title: "Office Desk Chair",
            quantity: "1",
            description: "Ergonomic office chair with adjustable height and lumbar support",
            make: "Herman Miller",
            model: "Aeron",
            category: "Furniture",
            location: "Home Office",
            price: "$1,295.00",
            serialNumber: ""
        )

        var mockMultiItemResponse = MultiItemAnalysisResponse(
            items: [
                DetectedInventoryItem(
                    title: "Office Desk Chair",
                    description: "Ergonomic office chair with adjustable height and lumbar support",
                    category: "Furniture",
                    make: "Herman Miller",
                    model: "Aeron",
                    estimatedPrice: "$1,295.00",
                    confidence: 0.92
                ),
                DetectedInventoryItem(
                    title: "MacBook Pro",
                    description: "15-inch laptop with silver finish",
                    category: "Electronics",
                    make: "Apple",
                    model: "MacBook Pro 15-inch",
                    estimatedPrice: "$2,399.00",
                    confidence: 0.95
                ),
                DetectedInventoryItem(
                    title: "Standing Desk",
                    description: "Height-adjustable standing desk with electric controls",
                    category: "Furniture",
                    make: "Uplift",
                    model: "V2",
                    estimatedPrice: "$799.00",
                    confidence: 0.88
                ),
            ],
            detectedCount: 3,
            analysisType: "multi_item",
            confidence: 0.92
        )

        func getImageDetails(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws
            -> ImageDetails
        {
            print("🧪 MockOpenAIService: getImageDetails called with \(images.count) images")
            if shouldFail {
                print("🧪 MockOpenAIService: Simulating failure")
                throw OpenAIError.invalidData
            }

            print("🧪 MockOpenAIService: Simulating analysis delay...")
            try await Task.sleep(nanoseconds: 500_000_000)

            print("🧪 MockOpenAIService: Returning mock response")
            return mockResponse
        }

        func getMultiItemDetails(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext)
            async throws -> MultiItemAnalysisResponse
        {
            print("🧪 MockOpenAIService: getMultiItemDetails called with \(images.count) images")
            if shouldFailMultiItem {
                print("🧪 MockOpenAIService: Simulating multi-item failure")
                throw OpenAIError.invalidData
            }

            print("🧪 MockOpenAIService: Simulating multi-item analysis delay...")
            try await Task.sleep(nanoseconds: 500_000_000)

            print(
                "🧪 MockOpenAIService: Returning mock multi-item response with \(mockMultiItemResponse.items?.count ?? 0) items"
            )
            return mockMultiItemResponse
        }

        func cancelCurrentRequest() {
        }
    }
#endif

// MARK: - Service Factory

@MainActor
enum OpenAIServiceFactory {
    static func create() -> OpenAIServiceProtocol {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("Mock-OpenAI") {
                print("🧪 OpenAIServiceFactory: Creating MockOpenAIService for testing")
                return MockOpenAIService()
            }
        #endif
        print("🔧 OpenAIServiceFactory: Creating real OpenAIService")
        return OpenAIService()
    }
}

// MARK: - Multi-Item Analysis Types

struct MultiItemAnalysisResponse: Codable {
    let items: [DetectedInventoryItem]?
    let detectedCount: Int
    let analysisType: String
    let confidence: Double

    var isValid: Bool {
        // Handle case where items might be missing
        let actualItems = items ?? []
        return actualItems.count == detectedCount && confidence >= 0.5 && detectedCount > 0 && !actualItems.isEmpty
    }

    // Computed property to safely access items
    var safeItems: [DetectedInventoryItem] {
        return items ?? []
    }
}

struct DetectedInventoryItem: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let category: String
    let make: String
    let model: String
    let estimatedPrice: String
    let confidence: Double

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        category: String,
        make: String,
        model: String,
        estimatedPrice: String,
        confidence: Double
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.make = make
        self.model = model
        self.estimatedPrice = estimatedPrice
        self.confidence = confidence
    }
}

// MARK: - Service Protocols

protocol OpenAIServiceProtocol {
    func getImageDetails(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws
        -> ImageDetails
    func getMultiItemDetails(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws
        -> MultiItemAnalysisResponse
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
        return await buildRequestBody(with: images, settings: settings, modelContext: modelContext, isMultiItem: false)
    }

    @MainActor
    func buildMultiItemRequestBody(
        with images: [UIImage],
        settings: SettingsManager,
        modelContext: ModelContext
    ) async -> OpenAIChatCompletionRequestBody {
        return await buildRequestBody(with: images, settings: settings, modelContext: modelContext, isMultiItem: true)
    }

    @MainActor
    private func buildRequestBody(
        with images: [UIImage],
        settings: SettingsManager,
        modelContext: ModelContext,
        isMultiItem: Bool
    ) async -> OpenAIChatCompletionRequestBody {
        // Get active home to filter labels and locations
        let homeDescriptor = FetchDescriptor<Home>(sortBy: [SortDescriptor(\Home.purchaseDate)])
        let homes = (try? modelContext.fetch(homeDescriptor)) ?? []

        let activeHome: Home?
        if let activeIdString = settings.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        {
            activeHome = homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
        } else {
            activeHome = homes.first { $0.isPrimary }
        }

        // Get all labels and locations, then filter by active home
        let allCategories = DefaultDataManager.getAllLabels(from: modelContext)
        let allLocations = DefaultDataManager.getAllLocations(from: modelContext)

        // Fetch actual label and location objects to filter by home
        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        let allLabelObjects = (try? modelContext.fetch(labelDescriptor)) ?? []
        let locationDescriptor = FetchDescriptor<InventoryLocation>()
        let allLocationObjects = (try? modelContext.fetch(locationDescriptor)) ?? []

        // Filter locations by active home (labels are global)
        let filteredLocationObjects =
            activeHome != nil
            ? allLocationObjects.filter { $0.home?.id == activeHome?.id }
            : allLocationObjects

        // Convert to name arrays, including "None" as first option
        // Labels are global (not filtered by home)
        let categories = ["None"] + allLabelObjects.map { $0.name }
        let locations = ["None"] + filteredLocationObjects.map { $0.name }

        let imagePrompt = createImagePrompt(for: images.count, isMultiItem: isMultiItem)
        let function = buildFunctionDefinition(
            imageCount: images.count,
            categories: categories,
            locations: locations,
            isMultiItem: isMultiItem
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
            toolChoice: .specific(functionName: function.name)
        )
    }

    private func createImagePrompt(for imageCount: Int, isMultiItem: Bool = false) -> String {
        if isMultiItem {
            return """
                Analyze this image and identify ALL distinct items visible. Each item should be a separate inventory item that would be individually cataloged. Look for objects like electronics, furniture, appliances, books, tools, clothing, etc. 

                CRITICAL REQUIREMENTS:
                1. You MUST use the process_multiple_inventory_items function
                2. You MUST include an "items" array in your response - this field is REQUIRED
                3. The "items" array must contain objects, even if empty: []
                4. Each item object must have: title, description, category, make, model, estimatedPrice, confidence
                5. The "detectedCount" must match the length of the "items" array
                6. Set "analysisType" to "multi_item"
                7. Provide an overall "confidence" score

                EXAMPLE RESPONSE FORMAT:
                {
                    "items": [
                        {"title": "Laptop", "description": "Silver laptop computer", "category": "Electronics", "make": "Apple", "model": "MacBook Pro", "estimatedPrice": "$2000", "confidence": 0.95}
                    ],
                    "detectedCount": 1,
                    "analysisType": "multi_item", 
                    "confidence": 0.90
                }

                Pay attention to text, labels, or model numbers on each item.
                """
        } else if imageCount > 1 {
            return
                "Analyze these \(imageCount) images which show the same item from different angles and perspectives. Combine all the visual information from all images to create ONE comprehensive description of this single item. Pay special attention to any text, labels, stickers, or engravings that might contain a serial number, model number, or product identification. Return only ONE response that describes the item based on all the photos together."
        } else {
            return
                "Analyze this image and identify the item which is the primary subject of the photo, along with its attributes. Pay special attention to any text, labels, stickers, or engravings that might contain a serial number, model number, or product identification."
        }
    }

    private func buildFunctionDefinition(
        imageCount: Int,
        categories: [String],
        locations: [String],
        isMultiItem: Bool = false
    ) -> FunctionDefinition {
        let enabledProperties = AIPromptConfiguration.getAllEnabledProperties(
            categories: categories,
            locations: locations
        )

        var properties: [String: FunctionParameterProperty] = [:]
        var requiredFields: [String] = []

        for (propertyName, config) in enabledProperties {
            let description = adjustDescriptionForMultipleImages(
                description: config.description,
                propertyName: propertyName,
                imageCount: imageCount
            )

            properties[propertyName] = FunctionParameterProperty(
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
            name: isMultiItem ? "process_multiple_inventory_items" : "process_inventory_item",
            description: isMultiItem
                ? "Process and structure information about MULTIPLE distinct inventory items visible in the image. You MUST return a JSON object with an 'items' array containing a separate object for each unique item that would be individually cataloged. Always include the items array, even if empty."
                : (imageCount > 1
                    ? "Process and structure information about ONE inventory item based on multiple photos. Return only ONE item description that combines information from all images."
                    : "Process and structure information about an inventory item"),
            parameters: isMultiItem
                ? createMultiItemParameters(properties: properties, requiredFields: requiredFields)
                : FunctionDefinition.Parameters(
                    type: "object",
                    properties: properties,
                    required: requiredFields,
                    additionalProperties: false
                ),
            strict: false
        )
    }

    private func createMultiItemParameters(
        properties: [String: FunctionParameterProperty],
        requiredFields: [String]
    ) -> FunctionDefinition.Parameters {
        // Simplest possible schema - just basic types without complex array items
        let multiItemProperties: [String: FunctionParameterProperty] = [
            "items": FunctionParameterProperty(
                type: "array",
                description:
                    "REQUIRED: Array of detected inventory items. You MUST include this field with an array of objects, even if empty."
            ),
            "detectedCount": FunctionParameterProperty(
                type: "integer",
                description: "Total number of distinct items detected in the image (must match items array length)"
            ),
            "analysisType": FunctionParameterProperty(
                type: "string",
                description: "Must be 'multi_item'"
            ),
            "confidence": FunctionParameterProperty(
                type: "number",
                description: "Overall confidence in the analysis between 0.0 and 1.0"
            ),
        ]

        return FunctionDefinition.Parameters(
            type: "object",
            properties: multiItemProperties,
            required: ["items", "detectedCount", "analysisType", "confidence"],
            additionalProperties: false
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
            return
                "A single concise description combining details from all \(imageCount) photos of this one item, limited to 160 characters"
        case "serialNumber":
            return
                "The serial number, product ID, or model identifier if visible in any of the \(imageCount) photos, or empty string if not found"
        default:
            return description
        }
    }

    private func getPropertyType(for propertyName: String) -> String {
        switch propertyName {
        case "isFragile":
            return "string"  // We'll handle boolean as string for simplicity
        default:
            return "string"
        }
    }

    @MainActor
    private func calculateTokenLimit(imageCount: Int, settings: SettingsManager) -> Int {
        // Base token limit for single image with low quality
        let baseTokens = 3000

        // Add 300 tokens for each additional image (up to 5 images max)
        let imageCount = min(imageCount, 5)  // Cap at 5 images
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

            // Special handling for array properties (specifically "items" in multi-item functions)
            if parameter.type == "array" && key == "items" && function.name == "process_multiple_inventory_items" {
                // Create a proper items schema that OpenAI expects for arrays
                let itemSchemaDict: [String: AIProxyJSONValue] = [
                    "type": .string("object"),
                    "description": .string("Individual inventory item with all standard properties"),
                    "additionalProperties": .bool(true),
                ]
                propertyDict["items"] = .object(itemSchemaDict)
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
        let imageCount = min(imageCount, 5)  // Cap at 5 images
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

        // Token usage logging is handled by the calling service
        if response.usage == nil {
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

        guard let responseData = argumentsString.data(using: String.Encoding.utf8) else {
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
        print(
            "   🚀 Efficiency: \(String(format: "%.1f", tokensPerSecond)) tokens/sec, \(String(format: "%.0f", tokensPerMB)) tokens/MB"
        )

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
            print(
                "⚠️ WARNING: Token usage at \(String(format: "%.1f", usagePercentage))% of limit (\(usage.total_tokens)/\(adjustedMaxTokens))"
            )
        } else if usagePercentage > 75.0 {
            print(
                "⚡ High token usage: \(String(format: "%.1f", usagePercentage))% of limit (\(usage.total_tokens)/\(adjustedMaxTokens))"
            )
        } else {
            print(
                "✅ Token usage: \(String(format: "%.1f", usagePercentage))% of limit (\(usage.total_tokens)/\(adjustedMaxTokens))"
            )
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
            description:
                "A concise name of the subject, to help the user identify the item from a list. Do not include descriptors such as color, instead use make, model or generic name of the item."
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
            description:
                "The estimated original price in US dollars (e.g., $10.99). Provide a single value, not a range."
        ),
        "serialNumber": AIPropertyConfig(
            description:
                "The serial number, product ID, or model identifier if visible in the image, or empty string if not found"
        ),
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
            description:
                "Estimated dimensions in format 'L x W x H' with units (e.g., '24\" x 16\" x 8\"'), or empty string if unclear"
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
            description:
                "Most likely place this item would be purchased (e.g., 'Apple Store', 'Best Buy', 'Amazon'), or empty string if unclear"
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
            description:
                "Any special storage requirements (e.g., 'Keep dry', 'Climate controlled'), or empty string if none"
        ),
        "isFragile": AIPropertyConfig(
            enabled: true,
            description: "Whether the item is fragile and requires careful handling",
            enumValues: ["true", "false"]
        ),
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
            if let errorData = responseData.data(using: String.Encoding.utf8),
                let errorDict = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                let errorMessage = errorDict["error"] as? String
            {
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
    let items: FunctionParameterItems?
    let properties: [String: FunctionParameterProperty]?
    let required: [String]?

    init(
        type: String,
        description: String? = nil,
        enum_values: [String]? = nil,
        items: FunctionParameterItems? = nil,
        properties: [String: FunctionParameterProperty]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.enum_values = enum_values
        self.items = items
        self.properties = properties
        self.required = required
    }

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enum_values = "enum"
        case items
        case properties
        case required
    }
}

struct FunctionParameterItems: Codable {
    let type: String
    let properties: [String: FunctionParameterProperty]?
    let required: [String]?
}

struct FunctionParameterProperty: Codable {
    let type: String
    let description: String?
    let enum_values: [String]?
    let items: ArrayItemSchema?

    init(type: String, description: String? = nil, enum_values: [String]? = nil, items: ArrayItemSchema? = nil) {
        self.type = type
        self.description = description
        self.enum_values = enum_values
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enum_values = "enum"
        case items
    }
}

struct ArrayItemSchema: Codable {
    let type: String
    let description: String?
    let additionalProperties: Bool

    init(type: String, description: String? = nil, additionalProperties: Bool = false) {
        self.type = type
        self.description = description
        self.additionalProperties = additionalProperties
    }
}

struct FunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: Parameters
    let strict: Bool?

    struct Parameters: Codable {
        let type: String
        let properties: [String: FunctionParameterProperty]
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
        let imageCount = min(imageCount, 5)  // Cap at 5 images
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

    func getImageDetails(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws
        -> ImageDetails
    {
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

    func getMultiItemDetails(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws
        -> MultiItemAnalysisResponse
    {
        // Cancel any existing request
        currentTask?.cancel()

        // Create new task for this request (reusing the same cancellation mechanism)
        let multiItemTask = Task<MultiItemAnalysisResponse, Error> {
            return try await performMultiItemStructuredResponseWithRetry(
                images: images, settings: settings, modelContext: modelContext)
        }

        defer {
            currentTask = nil
        }

        return try await multiItemTask.value
    }

    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Multi-Item Structured Response Implementation

    private func performMultiItemStructuredResponseWithRetry(
        images: [UIImage], settings: SettingsManager, modelContext: ModelContext, maxAttempts: Int = 3
    ) async throws -> MultiItemAnalysisResponse {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            // Check for task cancellation
            try Task.checkCancellation()

            do {
                return try await performSingleMultiItemStructuredRequest(
                    images: images, settings: settings, modelContext: modelContext, attempt: attempt,
                    maxAttempts: maxAttempts)
            } catch {
                lastError = error

                // Handle task cancellation errors
                if error is CancellationError {
                    throw error
                }

                // Handle AIProxy specific errors with same retry logic as single item
                if let aiProxyError = error as? AIProxyError {
                    switch aiProxyError {
                    case .unsuccessfulRequest(let statusCode, _):
                        switch statusCode {
                        case 429:  // Rate limited
                            if attempt < maxAttempts {
                                print("🔄 Multi-item rate limited, retrying attempt \(attempt + 1)/\(maxAttempts)")
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw OpenAIError.rateLimitExceeded
                            }
                        case 500...599:  // Server errors
                            if attempt < maxAttempts {
                                print(
                                    "🔄 Multi-item server error \(statusCode), retrying attempt \(attempt + 1)/\(maxAttempts)"
                                )
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw OpenAIError.serverError("Server error \(statusCode)")
                            }
                        default:
                            print(
                                "🔄 Multi-item other AIProxy error \(statusCode), retrying attempt \(attempt + 1)/\(maxAttempts)"
                            )
                            if attempt < maxAttempts {
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw OpenAIError.serverError("AIProxy error \(statusCode)")
                            }
                        }
                    case .assertion, .deviceCheckIsUnavailable, .deviceCheckBypassIsMissing:
                        throw OpenAIError.serverError("AIProxy configuration error")
                    }
                }

                // Handle URLError for network-level issues
                if let urlError = error as? URLError {
                    if attempt < maxAttempts {
                        print("🔄 Multi-item network error, retrying attempt \(attempt + 1)/\(maxAttempts)")
                        let delay = min(pow(2.0, Double(attempt)), 8.0)
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        try Task.checkCancellation()
                        continue
                    } else {
                        throw OpenAIError.networkUnavailable
                    }
                }

                // For other errors, throw immediately without retry
                throw error
            }
        }

        // If we get here, all attempts failed
        throw lastError ?? OpenAIError.invalidResponse(statusCode: 0, responseData: "Unknown error")
    }

    private func performSingleMultiItemStructuredRequest(
        images: [UIImage], settings: SettingsManager, modelContext: ModelContext, attempt: Int, maxAttempts: Int
    ) async throws -> MultiItemAnalysisResponse {
        let startTime = Date()
        let imageCount = images.count

        print("🔄 Multi-item structured response attempt \(attempt)/\(maxAttempts)")

        // Create the JSON schema for multi-item analysis
        let multiItemSchema: [String: AIProxyJSONValue] = [
            "type": "object",
            "properties": [
                "items": [
                    "type": "array",
                    "description": "Array of detected inventory items",
                    "items": [
                        "type": "object",
                        "properties": [
                            "id": [
                                "type": "string",
                                "description": "Unique identifier for the item",
                            ],
                            "title": [
                                "type": "string",
                                "description": "Descriptive name of the item",
                            ],
                            "description": [
                                "type": "string",
                                "description": "Detailed description of the item",
                            ],
                            "category": [
                                "type": "string",
                                "description": "Category classification for the item",
                            ],
                            "make": [
                                "type": "string",
                                "description": "Manufacturer or brand name",
                            ],
                            "model": [
                                "type": "string",
                                "description": "Model number or name",
                            ],
                            "estimatedPrice": [
                                "type": "string",
                                "description": "Estimated price with currency symbol",
                            ],
                            "confidence": [
                                "type": "number",
                                "description": "Confidence score between 0.0 and 1.0",
                            ],
                        ],
                        "required": [
                            "id", "title", "description", "category", "make", "model", "estimatedPrice", "confidence",
                        ],
                        "additionalProperties": false,
                    ],
                ],
                "detectedCount": [
                    "type": "integer",
                    "description": "Total number of items detected (must match items array length)",
                ],
                "analysisType": [
                    "type": "string",
                    "description": "Must be 'multi_item'",
                ],
                "confidence": [
                    "type": "number",
                    "description": "Overall confidence in the analysis between 0.0 and 1.0",
                ],
            ],
            "required": ["items", "detectedCount", "analysisType", "confidence"],
            "additionalProperties": false,
        ]

        // Build base request body for multi-item but we'll override the responseFormat
        let baseRequestBody = await requestBuilder.buildMultiItemRequestBody(
            with: images,
            settings: settings,
            modelContext: modelContext
        )

        // Calculate token limit
        let adjustedMaxTokens = calculateTokenLimit(imageCount: imageCount, settings: settings)
        let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled

        print("🚀 Sending multi-item structured response request via AIProxy")
        print("📊 Images: \(imageCount)")
        print("⚙️ Quality: \(isHighQuality ? "High" : "Standard")")
        print("📝 Max tokens: \(adjustedMaxTokens)")

        // Make the request using structured responses instead of function calling
        let response: OpenAIChatCompletionResponseBody = try await requestBuilder.openAIService.chatCompletionRequest(
            body: .init(
                model: baseRequestBody.model,
                messages: baseRequestBody.messages,
                maxCompletionTokens: adjustedMaxTokens,
                responseFormat: .jsonSchema(
                    name: "multi_item_analysis",
                    description: "Analysis of multiple inventory items in the image",
                    schema: multiItemSchema,
                    strict: true
                )
            ),
            secondsToWait: 60
        )

        print("✅ Received multi-item structured response with \(response.choices.count) choices")

        // Parse the structured response
        guard let choice = response.choices.first,
            let content = choice.message.content
        else {
            throw OpenAIError.invalidResponse(statusCode: 200, responseData: "No content in response")
        }

        print("📄 Structured response content length: \(content.count) characters")

        guard let responseData = content.data(using: .utf8) else {
            throw OpenAIError.invalidData
        }

        let result: MultiItemAnalysisResponse
        do {
            result = try JSONDecoder().decode(MultiItemAnalysisResponse.self, from: responseData)
            print("✅ Successfully decoded MultiItemAnalysisResponse with \(result.safeItems.count) items")
        } catch {
            print("❌ Failed to decode multi-item response: \(error)")
            print("📄 Raw response: \(content)")
            throw OpenAIError.invalidData
        }

        // Log token usage if available
        if let usage = response.usage {
            self.logAIProxyTokenUsage(
                usage: usage,
                elapsedTime: Date().timeIntervalSince(startTime),
                imageCount: imageCount,
                settings: settings
            )
        }

        return result
    }

    // MARK: - Deprecated Function Calling Implementation (Temporarily Disabled)
    /*
    private func performMultiItemRequestWithRetry(images: [UIImage], settings: SettingsManager, modelContext: ModelContext, maxAttempts: Int = 3) async throws -> MultiItemAnalysisResponse {
        var lastError: Error?
    
        for attempt in 1...maxAttempts {
            // Check for task cancellation
            try Task.checkCancellation()
    
            do {
                return try await performSingleMultiItemRequest(images: images, settings: settings, modelContext: modelContext, attempt: attempt, maxAttempts: maxAttempts)
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
    
                // Handle AIProxy specific errors with same retry logic as single item
                if let aiProxyError = error as? AIProxyError {
                    switch aiProxyError {
                    case .unsuccessfulRequest(let statusCode, _):
                        switch statusCode {
                        case 429: // Rate limited
                            if attempt < maxAttempts {
                                print("⏱️ Multi-item rate limited, retrying attempt \(attempt + 1)/\(maxAttempts)")
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw OpenAIError.rateLimitExceeded
                            }
                        case 500...599: // Server errors - retryable
                            if attempt < maxAttempts {
                                print("🔄 Multi-item server error \(statusCode), retrying attempt \(attempt + 1)/\(maxAttempts)")
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            }
                        default:
                            throw error
                        }
                    default:
                        throw error
                    }
                }
    
                // If not retryable or last attempt, throw the error
                if attempt == maxAttempts {
                    throw lastError ?? error
                }
    
                // Wait before retry with exponential backoff
                let delay = min(pow(2.0, Double(attempt)), 8.0)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                try Task.checkCancellation()
            }
        }
    
        throw lastError ?? OpenAIError.invalidData
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
                    case .assertion(let message):
                        throw OpenAIError.serverError("Assertion error: \(message)")
                    case .deviceCheckIsUnavailable:
                        throw OpenAIError.serverError("Device verification is unavailable")
                    case .deviceCheckBypassIsMissing:
                        throw OpenAIError.serverError("Device verification bypass is missing")
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
    
    private func performSingleMultiItemRequest(images: [UIImage], settings: SettingsManager, modelContext: ModelContext, attempt: Int, maxAttempts: Int) async throws -> MultiItemAnalysisResponse {
        guard !images.isEmpty else {
            throw OpenAIError.invalidData
        }
    
        // Build multi-item request body
        let requestBody = await requestBuilder.buildMultiItemRequestBody(
            with: images,
            settings: settings,
            modelContext: modelContext
        )
    
        let imageCount = images.count
        let useHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
    
        if attempt == 1 {
            print("🚀 Sending multi-item analysis request via AIProxy")
            print("📊 Images: \(imageCount)")
    
            // Calculate and log the token limit being used
            let adjustedMaxTokens = calculateTokenLimit(imageCount: imageCount, settings: settings)
            let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
            print("🤖 AI Settings - Model: \(settings.effectiveAIModel), Detail: \(settings.effectiveDetailLevel), Pro: \(settings.isPro), High Quality: \(isHighQuality)")
            print("🎯 Token limit: \(adjustedMaxTokens) (base: 3000, \(imageCount) images, \(isHighQuality ? "3x quality multiplier" : "standard quality"))")
    
            // Debug: Print function schema info
            print("🔧 Multi-item function schema: process_multiple_inventory_items")
            print("   Required fields include: items (array), detectedCount, analysisType, confidence")
    
            // Enhanced debugging would go here, but functions array not available in this scope
    
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
            print("🔄 Multi-item retry attempt \(attempt)/\(maxAttempts)")
        }
    
        let startTime = Date()
        let response = try await requestBuilder.openAIService.chatCompletionRequest(body: requestBody, secondsToWait: 60)
    
        print("✅ Received multi-item AIProxy response with \(response.choices.count) choices")
    
        do {
            // Parse multi-item response
            let result = try await parseMultiItemResponse(
                response: response,
                imageCount: imageCount,
                startTime: startTime,
                settings: settings
            )
    
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
            print("❌ Multi-item data corruption error: \(context)")
            throw OpenAIError.invalidData
        } catch DecodingError.keyNotFound(let key, let context) {
            print("❌ Multi-item key not found: \(key) in \(context)")
            throw OpenAIError.invalidData
        } catch DecodingError.typeMismatch(let type, let context) {
            print("❌ Multi-item type mismatch: \(type) in \(context)")
            throw OpenAIError.invalidData
        } catch DecodingError.valueNotFound(let type, let context) {
            print("❌ Multi-item value not found: \(type) in \(context)")
            throw OpenAIError.invalidData
        } catch {
            print("❌ Error processing multi-item response: \(error)")
    
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
    
    @MainActor
    private func parseMultiItemResponse(
        response: OpenAIChatCompletionResponseBody,
        imageCount: Int,
        startTime: Date,
        settings: SettingsManager
    ) async throws -> MultiItemAnalysisResponse {
        guard let choice = response.choices.first else {
            print("❌ No choices in multi-item response")
            throw OpenAIError.invalidData
        }
    
        guard let toolCalls = choice.message.toolCalls, !toolCalls.isEmpty else {
            print("❌ No tool calls in multi-item response")
            print("📝 Response message: \(choice.message)")
            throw OpenAIError.invalidData
        }
    
        let toolCall = toolCalls[0]
        print("🎯 Multi-item tool call received: \(toolCall.function.name)")
    
        // Get arguments as string - AIProxy provides argumentsRaw for JSON string
        let argumentsString = toolCall.function.argumentsRaw ?? ""
        print("📄 Multi-item arguments length: \(argumentsString.count) characters")
    
        guard let responseData = argumentsString.data(using: String.Encoding.utf8) else {
            print("❌ Cannot convert multi-item function arguments to data")
            print("📄 Raw arguments: \(argumentsString)")
            throw OpenAIError.invalidData
        }
    
        // Debug: Print the raw JSON for inspection
        print("🔍 Multi-item JSON to decode:")
        if let prettyJSON = try? JSONSerialization.jsonObject(with: responseData),
           let prettyData = try? JSONSerialization.data(withJSONObject: prettyJSON, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print(prettyString)
        } else {
            print("📄 Raw JSON: \(argumentsString)")
        }
    
        let result: MultiItemAnalysisResponse
        do {
            result = try JSONDecoder().decode(MultiItemAnalysisResponse.self, from: responseData)
            print("✅ Successfully decoded MultiItemAnalysisResponse with \(result.safeItems.count) items")
    
            // Validation: Check if we have a mismatch between detected count and actual items
            if result.detectedCount > 0 && result.safeItems.isEmpty {
                print("⚠️ CRITICAL: OpenAI detected \(result.detectedCount) items but returned empty items array!")
                print("🔄 This indicates a function schema issue - OpenAI is not following the items array requirement")
    
                // For now, we'll continue with the empty result, but log this as a major issue
                // In the future, we could implement a fallback single-item analysis
            } else if result.detectedCount != result.safeItems.count {
                print("⚠️ WARNING: Count mismatch - detected: \(result.detectedCount), actual items: \(result.safeItems.count)")
            }
        } catch {
            print("❌ Failed to decode MultiItemAnalysisResponse: \(error)")
            print("📄 Raw JSON that failed: \(argumentsString)")
            if let decodingError = error as? DecodingError {
                print("🔍 Decoding error details:")
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: \(type) at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type) at \(context.codingPath)")
                case .keyNotFound(let key, let context):
                    print("   Key not found: \(key) at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("   Data corrupted at \(context.codingPath): \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error: \(error)")
                }
            }
            throw OpenAIError.invalidData
        }
    
        // Apply item limit if needed (max 10 items)
        var limitedItems = result.safeItems
        if limitedItems.count > 10 {
            limitedItems = Array(limitedItems.prefix(10))
            print("⚠️ Limited multi-item response to 10 items (originally \(result.safeItems.count))")
        }
    
        let finalResult = MultiItemAnalysisResponse(
            items: limitedItems,
            detectedCount: result.detectedCount,
            analysisType: result.analysisType,
            confidence: result.confidence
        )
    
        // Log token usage if available
        if let usage = response.usage {
            self.logAIProxyTokenUsage(
                usage: usage,
                elapsedTime: Date().timeIntervalSince(startTime),
                imageCount: imageCount,
                settings: settings
            )
        }
    
        return finalResult
    }
    */

    // MARK: - Single-Item Analysis (Function Calling - Working)

    private func performRequestWithRetry(
        images: [UIImage], settings: SettingsManager, modelContext: ModelContext, maxAttempts: Int = 3
    ) async throws -> ImageDetails {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            // Check for task cancellation
            try Task.checkCancellation()

            do {
                return try await performSingleRequest(
                    images: images, settings: settings, modelContext: modelContext, attempt: attempt,
                    maxAttempts: maxAttempts)
            } catch {
                lastError = error

                // Handle task cancellation errors
                if error is CancellationError {
                    throw error
                }

                // Handle AIProxy specific errors
                if let aiProxyError = error as? AIProxyError {
                    switch aiProxyError {
                    case .unsuccessfulRequest(let statusCode, let responseBody):
                        print("🌐 AIProxy error \(statusCode): \(responseBody)")

                        // Handle specific HTTP status codes
                        switch statusCode {
                        case 429:  // Rate limited
                            if attempt < maxAttempts {
                                print("⏱️ Rate limited, retrying attempt \(attempt + 1)/\(maxAttempts)")
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw OpenAIError.rateLimitExceeded
                            }
                        case 413:  // Payload too large
                            throw OpenAIError.invalidResponse(statusCode: statusCode, responseData: responseBody)
                        case 500...599:  // Server errors - retryable
                            if attempt < maxAttempts {
                                print("🔄 Server error \(statusCode), retrying attempt \(attempt + 1)/\(maxAttempts)")
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw OpenAIError.serverError("Server error \(statusCode)")
                            }
                        case 400...499:  // Client errors - not retryable
                            throw OpenAIError.invalidResponse(statusCode: statusCode, responseData: responseBody)
                        default:
                            if attempt < maxAttempts {
                                print(
                                    "🔄 Unknown AIProxy error \(statusCode), retrying attempt \(attempt + 1)/\(maxAttempts)"
                                )
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw OpenAIError.serverError("Unknown AIProxy error occurred")
                            }
                        }
                    case .assertion, .deviceCheckIsUnavailable, .deviceCheckBypassIsMissing:
                        throw OpenAIError.serverError("AIProxy configuration error")
                    }
                }

                // Handle URLError for network-level issues
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
                        if attempt < maxAttempts {
                            print(
                                "🌐 Network error: \(urlError.localizedDescription), retrying attempt \(attempt + 1)/\(maxAttempts)"
                            )
                            let delay = min(pow(2.0, Double(attempt)), 8.0)
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            try Task.checkCancellation()
                            continue
                        } else {
                            throw OpenAIError.networkUnavailable
                        }
                    default:
                        throw OpenAIError.serverError(urlError.localizedDescription)
                    }
                }

                // For other errors, throw immediately
                throw error
            }
        }

        // If we get here, all attempts failed
        throw lastError ?? OpenAIError.invalidResponse(statusCode: 0, responseData: "Unknown error")
    }

    private func performSingleRequest(
        images: [UIImage], settings: SettingsManager, modelContext: ModelContext, attempt: Int, maxAttempts: Int
    ) async throws -> ImageDetails {
        let startTime = Date()
        let imageCount = images.count

        // Build request body using AIProxy with UIImages directly - no base64 conversion needed
        // AIProxy handles image encoding internally via encodeImageAsURL
        let requestBody = await requestBuilder.buildRequestBody(
            with: images,
            settings: settings,
            modelContext: modelContext
        )

        if attempt == 1 {
            // Calculate and log the token limit being used
            let adjustedMaxTokens = calculateTokenLimit(imageCount: imageCount, settings: settings)
            let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled

            // Track analysis start (only on first attempt)
            print("🚀 Sending \(imageCount == 1 ? "single" : "multi") image request via AIProxy")
            print("📊 Images: \(imageCount)")
            print("⚙️ Quality: \(isHighQuality ? "High" : "Standard")")
            print("📝 Max tokens: \(adjustedMaxTokens)")
        } else {
            print("🔄 Retry attempt \(attempt)/\(maxAttempts)")
        }

        let response: OpenAIChatCompletionResponseBody = try await requestBuilder.openAIService.chatCompletionRequest(
            body: requestBody, secondsToWait: 60)

        print("✅ Received AIProxy response with \(response.choices.count) choices")

        do {
            // Parse AIProxy response directly
            let parseResult = try await responseParser.parseAIProxyResponse(
                response: response,
                imageCount: imageCount,
                startTime: startTime,
                settings: settings
            )

            return parseResult.imageDetails
        } catch {
            print("❌ Failed to parse response: \(error)")
            throw error
        }
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
            print(
                "⚠️ WARNING: Token usage at \(String(format: "%.1f", usagePercentage))% of limit (\(totalTokens)/\(adjustedMaxTokens))"
            )
        } else if usagePercentage > 75.0 {
            print(
                "⚡ High token usage: \(String(format: "%.1f", usagePercentage))% of limit (\(totalTokens)/\(adjustedMaxTokens))"
            )
        } else {
            print(
                "✅ Token usage: \(String(format: "%.1f", usagePercentage))% of limit (\(totalTokens)/\(adjustedMaxTokens))"
            )
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
    let categories: [String]  // Multiple categories support (1-3 categories)
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

        // Handle both single category and multiple categories formats
        let decodedCategory = try container.decodeIfPresent(String.self, forKey: .category) ?? "Uncategorized"
        let decodedCategories = try container.decodeIfPresent([String].self, forKey: .categories)

        // If categories array is provided, use it; otherwise fall back to single category
        if let cats = decodedCategories, !cats.isEmpty {
            categories = Array(cats.prefix(3))  // Limit to 3 categories
            category = cats.first ?? decodedCategory
        } else {
            category = decodedCategory
            categories = decodedCategory.isEmpty || decodedCategory == "Uncategorized" ? [] : [decodedCategory]
        }

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
        case title, quantity, description, make, model, category, categories, location, price, serialNumber
        case condition, color, dimensions, dimensionLength, dimensionWidth, dimensionHeight, dimensionUnit
        case weightValue, weightUnit, purchaseLocation, replacementCost, depreciationRate, storageRequirements,
            isFragile
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
            categories: [],
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
    init(
        title: String, quantity: String, description: String, make: String, model: String,
        category: String, categories: [String] = [], location: String, price: String, serialNumber: String,
        condition: String? = nil, color: String? = nil, dimensions: String? = nil,
        dimensionLength: String? = nil, dimensionWidth: String? = nil, dimensionHeight: String? = nil,
        dimensionUnit: String? = nil, weightValue: String? = nil,
        weightUnit: String? = nil, purchaseLocation: String? = nil, replacementCost: String? = nil,
        depreciationRate: String? = nil, storageRequirements: String? = nil, isFragile: String? = nil
    ) {

        self.title = title
        self.quantity = quantity
        self.description = description
        self.make = make
        self.model = model
        self.category = category
        // If categories not provided, default to single category
        self.categories = categories.isEmpty ? (category.isEmpty || category == "None" ? [] : [category]) : categories
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
