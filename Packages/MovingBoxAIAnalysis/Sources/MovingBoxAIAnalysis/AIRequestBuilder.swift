//
//  AIRequestBuilder.swift
//  MovingBoxAIAnalysis
//

import AIProxy
import Foundation
import UIKit

// MARK: - AI Property Configuration

public struct AIPropertyConfig {
    public let enabled: Bool
    public let description: String
    public let enumValues: [String]?

    public init(enabled: Bool = true, description: String, enumValues: [String]? = nil) {
        self.enabled = enabled
        self.description = description
        self.enumValues = enumValues
    }
}

public struct AIPromptConfiguration {
    public static let coreProperties: [String: AIPropertyConfig] = [
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

    public static let extendedProperties: [String: AIPropertyConfig] = [
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

    public static func getAllEnabledProperties(categories: [String], locations: [String]) -> [String: AIPropertyConfig]
    {
        var allProperties = coreProperties

        for (key, config) in extendedProperties where config.enabled {
            allProperties[key] = config
        }

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

// MARK: - Function Definition Schema Types

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

// MARK: - Request Builder

public struct AIRequestBuilder {
    public let openRouterService = AIProxy.openRouterService(
        partialKey: "v2|dd24c1ca|qVU7FksJSPDTvLtM",
        serviceURL: "https://api.aiproxy.com/1530daf2/f9f2c62b"
    )

    let imageOptimizer: AIImageOptimizer

    public init(imageOptimizer: AIImageOptimizer) {
        self.imageOptimizer = imageOptimizer
    }

    @MainActor
    public func buildRequestBody(
        with images: [UIImage],
        settings: AIAnalysisSettings,
        context: AIAnalysisContext
    ) async -> OpenRouterChatCompletionRequestBody {
        return await buildRequestBody(with: images, settings: settings, context: context, isMultiItem: false)
    }

    @MainActor
    public func buildMultiItemRequestBody(
        with images: [UIImage],
        settings: AIAnalysisSettings,
        context: AIAnalysisContext,
        narrationContext: String? = nil
    ) async -> OpenRouterChatCompletionRequestBody {
        return await buildRequestBody(
            with: images,
            settings: settings,
            context: context,
            isMultiItem: true,
            narrationContext: narrationContext
        )
    }

    @MainActor
    private func buildRequestBody(
        with images: [UIImage],
        settings: AIAnalysisSettings,
        context: AIAnalysisContext,
        isMultiItem: Bool,
        narrationContext: String? = nil
    ) async -> OpenRouterChatCompletionRequestBody {
        let categories = ["None"] + context.labels
        let locations = ["None"] + context.locations

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

        let adjustedMaxTokens = calculateAITokenLimit(
            imageCount: images.count,
            isPro: settings.isPro,
            highQualityEnabled: settings.highQualityAnalysisEnabled,
            isMultiItem: isMultiItem
        )

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

    func createImagePrompt(
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
        settings: AIAnalysisSettings
    ) async -> [OpenRouterChatCompletionRequestBody.Message] {
        var parts: [OpenRouterChatCompletionRequestBody.Message.UserContent.Part] = []

        parts.append(.text(prompt))

        for image in images {
            let targetResolution = settings.effectiveImageResolution
            let resizedImage = await imageOptimizer.optimizeImage(image, maxDimension: targetResolution)

            if let imageURL = AIProxy.encodeImageAsURL(image: resizedImage, compressionQuality: 0.8) {
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
            return "string"
        default:
            return "string"
        }
    }

    func buildFunctionParameters(function: FunctionDefinition) -> [String: AIProxyJSONValue] {
        var parametersDict: [String: AIProxyJSONValue] = [:]

        parametersDict["type"] = .string(function.parameters.type)
        parametersDict["additionalProperties"] = .bool(function.parameters.additionalProperties)
        parametersDict["required"] = .array(function.parameters.required.map { .string($0) })

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

            if parameter.type == "array" && key == "items" && function.name == "process_multiple_inventory_items" {
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
