//
//  AIAnalysisService.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import AIProxy
import CryptoKit
import Foundation
import SwiftData
import UIKit

enum AnalysisPhotoLimits {
    static let maxPhotos = 60
}

// MARK: - Mock Service for Testing

#if DEBUG
    @MainActor
    class MockAIAnalysisService: AIAnalysisServiceProtocol {
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
                    confidence: 0.92,
                    detections: [ItemDetection(sourceImageIndex: 0, boundingBox: [50, 100, 600, 450])]
                ),
                DetectedInventoryItem(
                    title: "MacBook Pro",
                    description: "15-inch laptop with silver finish",
                    category: "Electronics",
                    make: "Apple",
                    model: "MacBook Pro 15-inch",
                    estimatedPrice: "$2,399.00",
                    confidence: 0.95,
                    detections: [ItemDetection(sourceImageIndex: 0, boundingBox: [200, 500, 550, 900])]
                ),
                DetectedInventoryItem(
                    title: "Standing Desk",
                    description: "Height-adjustable standing desk with electric controls",
                    category: "Furniture",
                    make: "Uplift",
                    model: "V2",
                    estimatedPrice: "$799.00",
                    confidence: 0.88,
                    detections: [ItemDetection(sourceImageIndex: 0, boundingBox: [300, 50, 950, 950])]
                ),
            ],
            detectedCount: 3,
            analysisType: "multi_item",
            confidence: 0.92
        )

        func getImageDetails(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws
            -> ImageDetails
        {
            print("🧪 MockAIAnalysisService: getImageDetails called with \(images.count) images")
            if shouldFail {
                print("🧪 MockAIAnalysisService: Simulating failure")
                throw AIAnalysisError.invalidData
            }

            print("🧪 MockAIAnalysisService: Simulating analysis delay...")
            try await Task.sleep(nanoseconds: 500_000_000)

            print("🧪 MockAIAnalysisService: Returning mock response")
            return mockResponse
        }

        func analyzeItem(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws
            -> ImageDetails
        {
            print("🧪 MockAIAnalysisService: analyzeItem called with \(images.count) images")
            if shouldFail {
                print("🧪 MockAIAnalysisService: Simulating failure")
                throw AIAnalysisError.invalidData
            }

            print("🧪 MockAIAnalysisService: Simulating analysis delay...")
            try await Task.sleep(nanoseconds: 500_000_000)

            print("🧪 MockAIAnalysisService: Returning mock response")
            return mockResponse
        }

        func getMultiItemDetails(
            from images: [UIImage],
            settings: SettingsManager,
            modelContext: ModelContext,
            narrationContext: String? = nil
        )
            async throws -> MultiItemAnalysisResponse
        {
            print("🧪 MockAIAnalysisService: getMultiItemDetails called with \(images.count) images")
            if shouldFailMultiItem {
                print("🧪 MockAIAnalysisService: Simulating multi-item failure")
                throw AIAnalysisError.invalidData
            }

            print("🧪 MockAIAnalysisService: Simulating multi-item analysis delay...")
            try await Task.sleep(nanoseconds: 500_000_000)

            print(
                "🧪 MockAIAnalysisService: Returning mock multi-item response with \(mockMultiItemResponse.items?.count ?? 0) items"
            )
            return mockMultiItemResponse
        }

        func cancelCurrentRequest() {
        }
    }
#endif

// MARK: - Service Factory

@MainActor
enum AIAnalysisServiceFactory {
    static func create() -> AIAnalysisServiceProtocol {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("Mock-AI") {
                print("🧪 AIAnalysisServiceFactory: Creating MockAIAnalysisService for testing")
                return MockAIAnalysisService()
            }
        #endif
        print("🔧 AIAnalysisServiceFactory: Creating real AIAnalysisService")
        return AIAnalysisService()
    }
}

// MARK: - Multi-Item Analysis Types

struct ItemDetection: Codable, Equatable {
    let sourceImageIndex: Int  // Which photo (0-indexed)
    let boundingBox: [Int]  // [ymin, xmin, ymax, xmax] normalized 0-1000
}

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
    let detections: [ItemDetection]?

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        category: String,
        make: String,
        model: String,
        estimatedPrice: String,
        confidence: Double,
        detections: [ItemDetection]? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.make = make
        self.model = model
        self.estimatedPrice = estimatedPrice
        self.confidence = confidence
        self.detections = detections
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case category
        case make
        case model
        case estimatedPrice
        case confidence
        case detections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        make = try container.decodeIfPresent(String.self, forKey: .make) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        estimatedPrice = try container.decodeIfPresent(String.self, forKey: .estimatedPrice) ?? ""
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.0
        detections = try container.decodeIfPresent([ItemDetection].self, forKey: .detections)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(category, forKey: .category)
        try container.encode(make, forKey: .make)
        try container.encode(model, forKey: .model)
        try container.encode(estimatedPrice, forKey: .estimatedPrice)
        try container.encode(confidence, forKey: .confidence)
        try container.encodeIfPresent(detections, forKey: .detections)
    }
}

// MARK: - Service Protocols

protocol AIAnalysisServiceProtocol {
    func getImageDetails(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws
        -> ImageDetails
    func analyzeItem(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws
        -> ImageDetails
    func getMultiItemDetails(
        from images: [UIImage],
        settings: SettingsManager,
        modelContext: ModelContext,
        narrationContext: String?
    ) async throws -> MultiItemAnalysisResponse
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

// MARK: - AI Request Builder

struct AIRequestBuilder {
    let openRouterService = AIProxy.openRouterService(
        partialKey: "v2|dd24c1ca|qVU7FksJSPDTvLtM",
        serviceURL: "https://api.aiproxy.com/1530daf2/f9f2c62b"
    )

    @MainActor
    func buildRequestBody(
        with images: [UIImage],
        settings: SettingsManager,
        modelContext: ModelContext
    ) async -> OpenRouterChatCompletionRequestBody {
        return await buildRequestBody(with: images, settings: settings, modelContext: modelContext, isMultiItem: false)
    }

    @MainActor
    func buildMultiItemRequestBody(
        with images: [UIImage],
        settings: SettingsManager,
        modelContext: ModelContext,
        narrationContext: String? = nil
    ) async -> OpenRouterChatCompletionRequestBody {
        return await buildRequestBody(
            with: images,
            settings: settings,
            modelContext: modelContext,
            isMultiItem: true,
            narrationContext: narrationContext
        )
    }

    @MainActor
    private func buildRequestBody(
        with images: [UIImage],
        settings: SettingsManager,
        modelContext: ModelContext,
        isMultiItem: Bool,
        narrationContext: String? = nil
    ) async -> OpenRouterChatCompletionRequestBody {
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

        let imagePrompt = createImagePrompt(
            for: images.count,
            isMultiItem: isMultiItem,
            narrationContext: narrationContext
        )
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

        return OpenRouterChatCompletionRequestBody(
            messages: messageContent,
            maxTokens: adjustedMaxTokens,
            model: settings.effectiveAIModel,
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

    private func createImagePrompt(
        for imageCount: Int,
        isMultiItem: Bool = false,
        narrationContext: String? = nil
    ) -> String {
        if isMultiItem {
            let basePrompt = """
                Analyze the provided image\(imageCount > 1 ? "s" : "") and identify ALL distinct items visible. Each item should be a separate inventory item that would be individually cataloged. Look for objects like electronics, furniture, appliances, books, tools, clothing, etc.
                \(imageCount > 1 ? "\nImages are labeled Image 0 through Image \(imageCount - 1).\n" : "")
                CRITICAL REQUIREMENTS:
                1. You MUST use the process_multiple_inventory_items function
                2. You MUST include an "items" array in your response - this field is REQUIRED
                3. The "items" array must contain objects, even if empty: []
                4. Each item object must have: title, description, category, make, model, estimatedPrice, confidence, detections
                5. The "detectedCount" must match the length of the "items" array
                6. Set "analysisType" to "multi_item"
                7. Provide an overall "confidence" score
                8. Each item MUST include a "detections" array with bounding box coordinates
                9. Each detection has "sourceImageIndex" (0-indexed image number) and "boundingBox" [ymin, xmin, ymax, xmax] normalized to 0-1000 scale
                10. If the same item appears in multiple images, include multiple detections for that item
                11. The first detection should be the clearest/best view of the item
                12. Do NOT cap the number of items at 10 or any other limit; include ALL distinct items visible
                13. For any unknown or unclear field, return an empty string (do NOT use "unknown", "n/a", "no serial number found", etc.)

                EXAMPLE RESPONSE FORMAT:
                {
                    "items": [
                        {"title": "Laptop", "description": "Silver laptop computer", "category": "Electronics", "make": "Apple", "model": "MacBook Pro", "estimatedPrice": "$2000", "confidence": 0.95, "detections": [{"sourceImageIndex": 0, "boundingBox": [100, 200, 500, 800]}]}
                    ],
                    "detectedCount": 1,
                    "analysisType": "multi_item",
                    "confidence": 0.90
                }

                Pay attention to text, labels, or model numbers on each item.
                """
            if let narrationContext, !narrationContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return """
                    The person recording provided this narration during this segment:
                    \"\(narrationContext)\"
                    Use this narration as context to identify items, locations, and details mentioned.

                    \(basePrompt)
                    """
            }

            return basePrompt
        } else if imageCount > 1 {
            return
                "Analyze these \(imageCount) images which show the same item from different angles and perspectives. Combine all the visual information from all images to create ONE comprehensive description of this single item. Pay special attention to any text, labels, stickers, or engravings that might contain a serial number, model number, or product identification. For any unknown or unclear field, return an empty string (do NOT use \"unknown\", \"n/a\", \"no serial number found\", etc.). Return only ONE response that describes the item based on all the photos together."
        } else {
            return
                "Analyze this image and identify the item which is the primary subject of the photo, along with its attributes. Pay special attention to any text, labels, stickers, or engravings that might contain a serial number, model number, or product identification. For any unknown or unclear field, return an empty string (do NOT use \"unknown\", \"n/a\", \"no serial number found\", etc.)."
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
                ? "Process and structure information about MULTIPLE distinct inventory items visible in the image. You MUST return a JSON object with an 'items' array containing a separate object for each unique item that would be individually cataloged. Always include the items array, even if empty. Do NOT cap the number of items; include all distinct items visible."
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
    ) async -> [OpenRouterChatCompletionRequestBody.Message] {
        var parts: [OpenRouterChatCompletionRequestBody.Message.UserContent.Part] = []

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
    private func calculateTokenLimit(imageCount: Int, settings: SettingsManager, isMultiItem: Bool = false) -> Int {
        // Base token limit for single image with low quality
        let baseTokens = 3000

        // Add 300 tokens for each additional image (up to 60 images max)
        let imageCount = min(imageCount, AnalysisPhotoLimits.maxPhotos)
        let additionalTokens = max(0, (imageCount - 1)) * 300
        let lowQualityTokens = baseTokens + additionalTokens

        // Apply 3x multiplier for high quality images (Pro + high quality enabled)
        let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
        var finalTokens = isHighQuality ? lowQualityTokens * 3 : lowQualityTokens

        // Multi-item needs more tokens for bounding box coordinates (~80-120 per item)
        if isMultiItem {
            finalTokens = max(finalTokens, 12000)
        }

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
                // Create a proper items schema that the model expects for arrays
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

// MARK: - AI Response Parser

struct AIResponseParser {

    struct ParseResult {
        let imageDetails: ImageDetails
        let usage: TokenUsage?
    }

    struct MultiItemParseResult {
        let response: MultiItemAnalysisResponse
        let usage: TokenUsage?
    }

    private func sanitizeString(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ""
        }

        let normalized = trimmed.lowercased()
        let badExactValues: Set<String> = [
            "unknown",
            "unknown item",
            "n/a",
            "na",
            "none",
            "not available",
            "not specified",
            "unavailable",
            "not found",
        ]

        if badExactValues.contains(normalized) {
            return ""
        }

        let badSubstrings = [
            "no serial number",
            "serial number not found",
            "serial not found",
            "not visible",
            "unable to determine",
            "could not determine",
        ]

        if badSubstrings.contains(where: { normalized.contains($0) }) {
            return ""
        }

        return trimmed
    }

    private func sanitizeOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let sanitized = sanitizeString(value)
        return sanitized.isEmpty ? nil : sanitized
    }

    private func sanitizeCategories(_ categories: [String]) -> [String] {
        categories
            .map { sanitizeString($0) }
            .filter { !$0.isEmpty }
    }

    private func sanitizeImageDetails(_ details: ImageDetails) -> ImageDetails {
        let sanitizedCategories = sanitizeCategories(details.categories)
        let sanitizedCategory = sanitizeString(details.category)
        let finalCategory = sanitizedCategory.isEmpty ? (sanitizedCategories.first ?? "") : sanitizedCategory

        return ImageDetails(
            title: sanitizeString(details.title),
            quantity: sanitizeString(details.quantity),
            description: sanitizeString(details.description),
            make: sanitizeString(details.make),
            model: sanitizeString(details.model),
            category: finalCategory,
            categories: sanitizedCategories,
            location: sanitizeString(details.location),
            price: sanitizeString(details.price),
            serialNumber: sanitizeString(details.serialNumber),
            condition: sanitizeOptional(details.condition),
            color: sanitizeOptional(details.color),
            dimensions: sanitizeOptional(details.dimensions),
            dimensionLength: sanitizeOptional(details.dimensionLength),
            dimensionWidth: sanitizeOptional(details.dimensionWidth),
            dimensionHeight: sanitizeOptional(details.dimensionHeight),
            dimensionUnit: sanitizeOptional(details.dimensionUnit),
            weightValue: sanitizeOptional(details.weightValue),
            weightUnit: sanitizeOptional(details.weightUnit),
            purchaseLocation: sanitizeOptional(details.purchaseLocation),
            replacementCost: sanitizeOptional(details.replacementCost),
            depreciationRate: sanitizeOptional(details.depreciationRate),
            storageRequirements: sanitizeOptional(details.storageRequirements),
            isFragile: sanitizeOptional(details.isFragile)
        )
    }

    private func sanitizeDetectedItem(_ item: DetectedInventoryItem) -> DetectedInventoryItem {
        return DetectedInventoryItem(
            id: item.id,
            title: sanitizeString(item.title),
            description: sanitizeString(item.description),
            category: sanitizeString(item.category),
            make: sanitizeString(item.make),
            model: sanitizeString(item.model),
            estimatedPrice: sanitizeString(item.estimatedPrice),
            confidence: item.confidence,
            detections: item.detections
        )
    }

    func sanitizeMultiItemResponse(_ response: MultiItemAnalysisResponse) -> MultiItemAnalysisResponse {
        let sanitizedItems = response.items?.map { sanitizeDetectedItem($0) }
        return MultiItemAnalysisResponse(
            items: sanitizedItems,
            detectedCount: response.detectedCount,
            analysisType: response.analysisType,
            confidence: response.confidence
        )
    }
    @MainActor
    private func calculateTokenLimit(imageCount: Int, settings: SettingsManager, isMultiItem: Bool = false) -> Int {
        // Base token limit for single image with low quality
        let baseTokens = 3000

        // Add 300 tokens for each additional image (up to 60 images max)
        let imageCount = min(imageCount, AnalysisPhotoLimits.maxPhotos)
        let additionalTokens = max(0, (imageCount - 1)) * 300
        let lowQualityTokens = baseTokens + additionalTokens

        // Apply 3x multiplier for high quality images (Pro + high quality enabled)
        let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
        var finalTokens = isHighQuality ? lowQualityTokens * 3 : lowQualityTokens

        // Multi-item needs more tokens for bounding box coordinates (~80-120 per item)
        if isMultiItem {
            finalTokens = max(finalTokens, 12000)
        }

        return finalTokens
    }

    @MainActor
    func parseAIProxyResponse(
        response: OpenRouterChatCompletionResponseBody,
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
            throw AIAnalysisError.invalidData
        }

        guard let toolCalls = choice.message.toolCalls, !toolCalls.isEmpty else {
            print("❌ No tool calls in response")
            print("📝 Response message: \(choice.message)")
            throw AIAnalysisError.invalidData
        }

        let toolCall = toolCalls[0]
        guard let function = toolCall.function else {
            print("❌ Tool call missing function payload")
            throw AIAnalysisError.invalidData
        }
        print("🎯 Tool call received: \(function.name)")

        // Get arguments as string - AIProxy provides argumentsRaw for JSON string
        let argumentsString = function.argumentsRaw ?? ""
        print("📄 Arguments length: \(argumentsString.count) characters")

        guard let responseData = argumentsString.data(using: String.Encoding.utf8) else {
            print("❌ Cannot convert function arguments to data")
            print("📄 Raw arguments: \(argumentsString)")
            throw AIAnalysisError.invalidData
        }

        let decoded = try JSONDecoder().decode(ImageDetails.self, from: responseData)
        let result = sanitizeImageDetails(decoded)

        // Convert AIProxy usage to our TokenUsage type for compatibility
        let tokenUsage = response.usage != nil ? convertAIProxyUsage(response.usage!) : nil

        return ParseResult(imageDetails: result, usage: tokenUsage)
    }

    @MainActor
    func parseAIProxyMultiItemResponse(
        response: OpenRouterChatCompletionResponseBody,
        imageCount: Int,
        startTime: Date,
        settings: SettingsManager
    ) throws -> MultiItemParseResult {
        print("✅ Processing multi-item AIProxy response with \(response.choices.count) choices")

        if response.usage == nil {
            print("⚠️ No token usage information in response")
        }

        guard let choice = response.choices.first else {
            print("❌ No choices in response")
            throw AIAnalysisError.invalidData
        }

        guard let toolCalls = choice.message.toolCalls, !toolCalls.isEmpty else {
            print("❌ No tool calls in response")
            print("📝 Response message: \(choice.message)")
            throw AIAnalysisError.invalidData
        }

        let toolCall = toolCalls[0]
        guard let function = toolCall.function else {
            print("❌ Tool call missing function payload")
            throw AIAnalysisError.invalidData
        }
        print("🎯 Tool call received: \(function.name)")

        let argumentsString = function.argumentsRaw ?? ""
        print("📄 Arguments length: \(argumentsString.count) characters")

        guard let responseData = argumentsString.data(using: String.Encoding.utf8) else {
            print("❌ Cannot convert function arguments to data")
            print("📄 Raw arguments: \(argumentsString)")
            throw AIAnalysisError.invalidData
        }

        let decoded = try JSONDecoder().decode(MultiItemAnalysisResponse.self, from: responseData)
        let result = sanitizeMultiItemResponse(decoded)
        let tokenUsage = response.usage != nil ? convertAIProxyUsage(response.usage!) : nil

        return MultiItemParseResult(response: result, usage: tokenUsage)
    }

    private func convertAIProxyUsage(_ aiProxyUsage: OpenRouterChatCompletionResponseBody.Usage) -> TokenUsage {
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

enum AIAnalysisError: Error {
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
            // Try to parse AIProxy error messages
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
class AIAnalysisService: AIAnalysisServiceProtocol {

    @MainActor
    private func calculateTokenLimit(imageCount: Int, settings: SettingsManager, isMultiItem: Bool = false) -> Int {
        // Base token limit for single image with low quality
        let baseTokens = 3000

        // Add 300 tokens for each additional image (up to 60 images max)
        let imageCount = min(imageCount, AnalysisPhotoLimits.maxPhotos)
        let additionalTokens = max(0, (imageCount - 1)) * 300
        let lowQualityTokens = baseTokens + additionalTokens

        // Apply 3x multiplier for high quality images (Pro + high quality enabled)
        let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
        var finalTokens = isHighQuality ? lowQualityTokens * 3 : lowQualityTokens

        // Multi-item needs more tokens for bounding box coordinates (~80-120 per item)
        if isMultiItem {
            finalTokens = max(finalTokens, 12000)
        }

        return finalTokens
    }
    // Track current request to allow cancellation
    private var currentTask: Task<ImageDetails, Error>?

    private let requestBuilder = AIRequestBuilder()
    private let responseParser = AIResponseParser()

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

    func analyzeItem(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws
        -> ImageDetails
    {
        return try await performRequestWithRetry(images: images, settings: settings, modelContext: modelContext)
    }

    func getMultiItemDetails(
        from images: [UIImage],
        settings: SettingsManager,
        modelContext: ModelContext,
        narrationContext: String? = nil
    ) async throws -> MultiItemAnalysisResponse {
        // Cancel any existing request
        currentTask?.cancel()

        // Create new task for this request (reusing the same cancellation mechanism)
        let multiItemTask = Task<MultiItemAnalysisResponse, Error> {
            return try await performMultiItemStructuredResponseWithRetry(
                images: images,
                settings: settings,
                modelContext: modelContext,
                narrationContext: narrationContext
            )
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
        images: [UIImage],
        settings: SettingsManager,
        modelContext: ModelContext,
        narrationContext: String?,
        maxAttempts: Int = 3
    ) async throws -> MultiItemAnalysisResponse {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            // Check for task cancellation
            try Task.checkCancellation()

            do {
                return try await performSingleMultiItemStructuredRequest(
                    images: images,
                    settings: settings,
                    modelContext: modelContext,
                    narrationContext: narrationContext,
                    attempt: attempt,
                    maxAttempts: maxAttempts
                )
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
                                throw AIAnalysisError.rateLimitExceeded
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
                                throw AIAnalysisError.serverError("Server error \(statusCode)")
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
                                throw AIAnalysisError.serverError("AIProxy error \(statusCode)")
                            }
                        }
                    case .assertion, .deviceCheckIsUnavailable, .deviceCheckBypassIsMissing:
                        throw AIAnalysisError.serverError("AIProxy configuration error")
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
                        throw AIAnalysisError.networkUnavailable
                    }
                }

                // For other errors, throw immediately without retry
                throw error
            }
        }

        // If we get here, all attempts failed
        throw lastError ?? AIAnalysisError.invalidResponse(statusCode: 0, responseData: "Unknown error")
    }

    private func performSingleMultiItemStructuredRequest(
        images: [UIImage],
        settings: SettingsManager,
        modelContext: ModelContext,
        narrationContext: String?,
        attempt: Int,
        maxAttempts: Int
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
                    "description": "Array of detected inventory items (include ALL distinct items; do not cap at 10)",
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
                            "detections": [
                                "type": "array",
                                "description": "Bounding box detections for this item across source images",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "sourceImageIndex": [
                                            "type": "integer",
                                            "description": "0-indexed image number this detection is from",
                                        ],
                                        "boundingBox": [
                                            "type": "array",
                                            "description": "[ymin, xmin, ymax, xmax] normalized 0-1000",
                                            "items": ["type": "integer"],
                                        ],
                                    ],
                                    "required": ["sourceImageIndex", "boundingBox"],
                                    "additionalProperties": false,
                                ],
                            ],
                        ],
                        "required": [
                            "id", "title", "description", "category", "make", "model", "estimatedPrice", "confidence",
                            "detections",
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
            modelContext: modelContext,
            narrationContext: narrationContext
        )

        // Calculate token limit (multi-item needs more tokens for bounding boxes)
        let adjustedMaxTokens = calculateTokenLimit(imageCount: imageCount, settings: settings, isMultiItem: true)
        let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled

        print("🚀 Sending multi-item structured response request via AIProxy")
        print("📊 Images: \(imageCount)")
        print("⚙️ Quality: \(isHighQuality ? "High" : "Standard")")
        print("📝 Max tokens: \(adjustedMaxTokens)")

        // Make the request using structured responses instead of function calling
        let response: OpenRouterChatCompletionResponseBody
        do {
            response = try await requestBuilder.openRouterService
                .chatCompletionRequest(
                    body: .init(
                        messages: baseRequestBody.messages,
                        maxTokens: adjustedMaxTokens,
                        model: baseRequestBody.model,
                        responseFormat: .jsonSchema(
                            name: "multi_item_analysis",
                            description: "Analysis of multiple inventory items in the image",
                            schema: multiItemSchema,
                            strict: true
                        )
                    ),
                    secondsToWait: 60
                )
        } catch {
            if shouldFallbackToFunctionCalling(error) {
                print("⚠️ Structured response failed; falling back to function calling: \(error)")
                return try await performSingleMultiItemFunctionRequest(
                    images: images,
                    settings: settings,
                    modelContext: modelContext,
                    narrationContext: narrationContext,
                    attempt: attempt,
                    maxAttempts: maxAttempts
                )
            }
            throw error
        }

        print("✅ Received multi-item structured response with \(response.choices.count) choices")

        // Parse the structured response
        guard let choice = response.choices.first,
            let content = choice.message.content
        else {
            throw AIAnalysisError.invalidResponse(statusCode: 200, responseData: "No content in response")
        }

        print("📄 Structured response content length: \(content.count) characters")

        guard let responseData = content.data(using: .utf8) else {
            throw AIAnalysisError.invalidData
        }

        let result: MultiItemAnalysisResponse
        do {
            let decoded = try JSONDecoder().decode(MultiItemAnalysisResponse.self, from: responseData)
            result = responseParser.sanitizeMultiItemResponse(decoded)
            print("✅ Successfully decoded MultiItemAnalysisResponse with \(result.safeItems.count) items")
        } catch {
            print("❌ Failed to decode multi-item response: \(error)")
            print("📄 Raw response: \(content)")
            print("↩️ Falling back to function calling for multi-item")
            return try await performSingleMultiItemFunctionRequest(
                images: images,
                settings: settings,
                modelContext: modelContext,
                narrationContext: narrationContext,
                attempt: attempt,
                maxAttempts: maxAttempts
            )
        }

        // Log token usage if available
        if let usage = response.usage {
            let adjustedMaxTokens = calculateTokenLimit(imageCount: imageCount, settings: settings, isMultiItem: true)
            let totalTokens = usage.totalTokens ?? 0
            let usagePercentage = Double(totalTokens) / Double(adjustedMaxTokens) * 100.0
            print(
                "📦 Multi-item response: \(result.safeItems.count) items (detectedCount: \(result.detectedCount)); token usage \(String(format: "%.1f", usagePercentage))% (\(totalTokens)/\(adjustedMaxTokens))"
            )
            self.logAIProxyTokenUsage(
                usage: usage,
                elapsedTime: Date().timeIntervalSince(startTime),
                imageCount: imageCount,
                settings: settings
            )
        } else {
            print(
                "📦 Multi-item response: \(result.safeItems.count) items (detectedCount: \(result.detectedCount)); token usage unavailable"
            )
        }

        return result
    }

    private func performSingleMultiItemFunctionRequest(
        images: [UIImage],
        settings: SettingsManager,
        modelContext: ModelContext,
        narrationContext: String?,
        attempt: Int,
        maxAttempts: Int
    ) async throws -> MultiItemAnalysisResponse {
        let startTime = Date()
        let imageCount = images.count

        let requestBody = await requestBuilder.buildMultiItemRequestBody(
            with: images,
            settings: settings,
            modelContext: modelContext,
            narrationContext: narrationContext
        )

        if attempt == 1 {
            let adjustedMaxTokens = calculateTokenLimit(imageCount: imageCount, settings: settings, isMultiItem: true)
            let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
            print("🚀 Sending multi-item function request via AIProxy (fallback)")
            print("📊 Images: \(imageCount)")
            print("⚙️ Quality: \(isHighQuality ? "High" : "Standard")")
            print("📝 Max tokens: \(adjustedMaxTokens)")
        } else {
            print("🔄 Retry attempt \(attempt)/\(maxAttempts) (fallback)")
        }

        let response: OpenRouterChatCompletionResponseBody = try await requestBuilder.openRouterService
            .chatCompletionRequest(body: requestBody, secondsToWait: 60)

        print("✅ Received multi-item function response with \(response.choices.count) choices")

        let parseResult = try responseParser.parseAIProxyMultiItemResponse(
            response: response,
            imageCount: imageCount,
            startTime: startTime,
            settings: settings
        )

        if let usage = response.usage {
            let adjustedMaxTokens = calculateTokenLimit(imageCount: imageCount, settings: settings, isMultiItem: true)
            let totalTokens = usage.totalTokens ?? 0
            let usagePercentage = Double(totalTokens) / Double(adjustedMaxTokens) * 100.0
            let formattedUsage = String(format: "%.1f", usagePercentage)
            print(
                "📦 Multi-item response (fallback): \(parseResult.response.safeItems.count) items (detectedCount: \(parseResult.response.detectedCount)); token usage \(formattedUsage)% (\(totalTokens)/\(adjustedMaxTokens))"
            )
            self.logAIProxyTokenUsage(
                usage: usage,
                elapsedTime: Date().timeIntervalSince(startTime),
                imageCount: imageCount,
                settings: settings
            )
        } else {
            print(
                "📦 Multi-item response (fallback): \(parseResult.response.safeItems.count) items (detectedCount: \(parseResult.response.detectedCount)); token usage unavailable"
            )
        }

        return parseResult.response
    }

    private func shouldFallbackToFunctionCalling(_ error: Error) -> Bool {
        if error is DecodingError {
            return true
        }

        if let aiProxyError = error as? AIProxyError {
            switch aiProxyError {
            case .unsuccessfulRequest(_, let responseBody):
                let lowerBody = responseBody.lowercased()
                if lowerBody.contains("response_format")
                    || lowerBody.contains("json_schema")
                    || lowerBody.contains("json schema")
                    || (lowerBody.contains("schema") && lowerBody.contains("unsupported"))
                {
                    return true
                }
            default:
                break
            }
        }

        let lowerDescription = error.localizedDescription.lowercased()
        if lowerDescription.contains("choices") && lowerDescription.contains("keynotfound") {
            return true
        }

        return false
    }

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
                                throw AIAnalysisError.rateLimitExceeded
                            }
                        case 413:  // Payload too large
                            throw AIAnalysisError.invalidResponse(statusCode: statusCode, responseData: responseBody)
                        case 500...599:  // Server errors - retryable
                            if attempt < maxAttempts {
                                print("🔄 Server error \(statusCode), retrying attempt \(attempt + 1)/\(maxAttempts)")
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw AIAnalysisError.serverError("Server error \(statusCode)")
                            }
                        case 400...499:  // Client errors - not retryable
                            throw AIAnalysisError.invalidResponse(statusCode: statusCode, responseData: responseBody)
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
                                throw AIAnalysisError.serverError("Unknown AIProxy error occurred")
                            }
                        }
                    case .assertion, .deviceCheckIsUnavailable, .deviceCheckBypassIsMissing:
                        throw AIAnalysisError.serverError("AIProxy configuration error")
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
                            throw AIAnalysisError.networkCancelled
                        }
                    case .timedOut:
                        if attempt < maxAttempts {
                            print("⏱️ Request timed out, retrying attempt \(attempt + 1)/\(maxAttempts)")
                            let delay = min(pow(2.0, Double(attempt)), 8.0)
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            try Task.checkCancellation()
                            continue
                        } else {
                            throw AIAnalysisError.networkTimeout
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
                            throw AIAnalysisError.networkUnavailable
                        }
                    default:
                        throw AIAnalysisError.serverError(urlError.localizedDescription)
                    }
                }

                // For other errors, throw immediately
                throw error
            }
        }

        // If we get here, all attempts failed
        throw lastError ?? AIAnalysisError.invalidResponse(statusCode: 0, responseData: "Unknown error")
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

        let response: OpenRouterChatCompletionResponseBody = try await requestBuilder.openRouterService
            .chatCompletionRequest(
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
        usage: OpenRouterChatCompletionResponseBody.Usage,
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
        let adjustedMaxTokens = calculateTokenLimit(imageCount: imageCount, settings: settings, isMultiItem: true)
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
