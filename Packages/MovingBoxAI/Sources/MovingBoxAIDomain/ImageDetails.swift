import Foundation

public struct ImageDetails: Decodable, Sendable {
    public let title: String
    public let quantity: String
    public let description: String
    public let make: String
    public let model: String
    public let category: String
    public let categories: [String]
    public let location: String
    public let price: String
    public let serialNumber: String

    public let condition: String?
    public let color: String?
    public let dimensions: String?
    public let dimensionLength: String?
    public let dimensionWidth: String?
    public let dimensionHeight: String?
    public let dimensionUnit: String?
    public let weightValue: String?
    public let weightUnit: String?
    public let purchaseLocation: String?
    public let replacementCost: String?
    public let depreciationRate: String?
    public let storageRequirements: String?
    public let isFragile: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Unknown Item"
        quantity = try container.decodeIfPresent(String.self, forKey: .quantity) ?? "1"
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? "Item details not available"
        make = try container.decodeIfPresent(String.self, forKey: .make) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""

        let decodedCategory = try container.decodeIfPresent(String.self, forKey: .category) ?? "Uncategorized"
        let decodedCategories = try container.decodeIfPresent([String].self, forKey: .categories)

        if let cats = decodedCategories, !cats.isEmpty {
            categories = Array(cats.prefix(3))
            category = cats.first ?? decodedCategory
        } else {
            category = decodedCategory
            categories = decodedCategory.isEmpty || decodedCategory == "Uncategorized" ? [] : [decodedCategory]
        }

        location = try container.decodeIfPresent(String.self, forKey: .location) ?? "Unknown"
        price = try container.decodeIfPresent(String.self, forKey: .price) ?? "$0.00"
        serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber) ?? ""

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

    public init(
        title: String,
        quantity: String,
        description: String,
        make: String,
        model: String,
        category: String,
        categories: [String] = [],
        location: String,
        price: String,
        serialNumber: String,
        condition: String? = nil,
        color: String? = nil,
        dimensions: String? = nil,
        dimensionLength: String? = nil,
        dimensionWidth: String? = nil,
        dimensionHeight: String? = nil,
        dimensionUnit: String? = nil,
        weightValue: String? = nil,
        weightUnit: String? = nil,
        purchaseLocation: String? = nil,
        replacementCost: String? = nil,
        depreciationRate: String? = nil,
        storageRequirements: String? = nil,
        isFragile: String? = nil
    ) {
        self.title = title
        self.quantity = quantity
        self.description = description
        self.make = make
        self.model = model
        self.category = category
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

    public static func empty() -> ImageDetails {
        ImageDetails(
            title: "",
            quantity: "",
            description: "",
            make: "",
            model: "",
            category: "None",
            categories: [],
            location: "None",
            price: "",
            serialNumber: ""
        )
    }

    enum CodingKeys: String, CodingKey {
        case title
        case quantity
        case description
        case make
        case model
        case category
        case categories
        case location
        case price
        case serialNumber
        case condition
        case color
        case dimensions
        case dimensionLength
        case dimensionWidth
        case dimensionHeight
        case dimensionUnit
        case weightValue
        case weightUnit
        case purchaseLocation
        case replacementCost
        case depreciationRate
        case storageRequirements
        case isFragile
    }
}
