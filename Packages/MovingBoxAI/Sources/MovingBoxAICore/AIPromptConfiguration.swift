import Foundation

public struct AIPropertyConfig: Sendable {
    public let enabled: Bool
    public let description: String
    public let enumValues: [String]?

    public init(enabled: Bool = true, description: String, enumValues: [String]? = nil) {
        self.enabled = enabled
        self.description = description
        self.enumValues = enumValues
    }
}

public enum AIPromptConfiguration {
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

    public static func allEnabledProperties(categories: [String], locations: [String]) -> [String: AIPropertyConfig] {
        var allProperties = coreProperties

        for (key, config) in extendedProperties where config.enabled {
            allProperties[key] = config
        }

        allProperties["category"] = AIPropertyConfig(
            description: coreProperties["category"]?.description ?? "",
            enumValues: categories
        )

        allProperties["location"] = AIPropertyConfig(
            description: coreProperties["location"]?.description ?? "",
            enumValues: locations
        )

        return allProperties
    }
}

public struct FunctionParameterItems: Codable, Sendable {
    public let type: String
    public let properties: [String: FunctionParameterProperty]?
    public let required: [String]?

    public init(type: String, properties: [String: FunctionParameterProperty]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

public struct ArrayItemSchema: Codable, Sendable {
    public let type: String
    public let description: String?
    public let additionalProperties: Bool

    public init(type: String, description: String? = nil, additionalProperties: Bool = false) {
        self.type = type
        self.description = description
        self.additionalProperties = additionalProperties
    }
}

public struct FunctionParameterProperty: Codable, Sendable {
    public let type: String
    public let description: String?
    public let enumValues: [String]?
    public let items: ArrayItemSchema?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
        case items
    }

    public init(type: String, description: String? = nil, enumValues: [String]? = nil, items: ArrayItemSchema? = nil) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.items = items
    }
}

public struct FunctionParameter: Codable, Sendable {
    public let type: String
    public let description: String?
    public let enumValues: [String]?
    public let items: FunctionParameterItems?
    public let properties: [String: FunctionParameterProperty]?
    public let required: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
        case items
        case properties
        case required
    }

    public init(
        type: String,
        description: String? = nil,
        enumValues: [String]? = nil,
        items: FunctionParameterItems? = nil,
        properties: [String: FunctionParameterProperty]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.items = items
        self.properties = properties
        self.required = required
    }
}

public struct FunctionDefinition: Codable, Sendable {
    public let name: String
    public let description: String
    public let parameters: Parameters
    public let strict: Bool?

    public init(name: String, description: String, parameters: Parameters, strict: Bool?) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
    }

    public struct Parameters: Codable, Sendable {
        public let type: String
        public let properties: [String: FunctionParameterProperty]
        public let required: [String]
        public let additionalProperties: Bool

        public init(
            type: String, properties: [String: FunctionParameterProperty], required: [String],
            additionalProperties: Bool
        ) {
            self.type = type
            self.properties = properties
            self.required = required
            self.additionalProperties = additionalProperties
        }
    }
}
