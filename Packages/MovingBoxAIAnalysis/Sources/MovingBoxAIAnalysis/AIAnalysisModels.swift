//
//  AIAnalysisModels.swift
//  MovingBoxAIAnalysis
//

import Foundation

// MARK: - Photo Limits

public enum AnalysisPhotoLimits {
    public static let maxPhotos = 10
}

// MARK: - Token Limit Calculation

public func calculateAITokenLimit(
    imageCount: Int,
    isPro: Bool,
    highQualityEnabled: Bool,
    isMultiItem: Bool = false
) -> Int {
    let baseTokens = 3000
    let clampedCount = min(imageCount, AnalysisPhotoLimits.maxPhotos)
    let additionalTokens = max(0, (clampedCount - 1)) * 300
    let lowQualityTokens = baseTokens + additionalTokens
    let isHighQuality = isPro && highQualityEnabled
    var finalTokens = isHighQuality ? lowQualityTokens * 3 : lowQualityTokens
    if isMultiItem {
        finalTokens = max(finalTokens, 12000)
    }
    return finalTokens
}

// MARK: - Single-Item Analysis Response

public struct ImageDetails: Decodable {
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

    private enum CodingKeys: String, CodingKey {
        case title, quantity, description, make, model, category, categories, location, price, serialNumber
        case condition, color, dimensions, dimensionLength, dimensionWidth, dimensionHeight, dimensionUnit
        case weightValue, weightUnit, purchaseLocation, replacementCost, depreciationRate, storageRequirements,
            isFragile
    }

    public static func empty() -> ImageDetails {
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

    public init(
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

// MARK: - Multi-Item Analysis Types

public struct ItemDetection: Codable, Equatable {
    public let sourceImageIndex: Int
    public let boundingBox: [Int]

    public init(sourceImageIndex: Int, boundingBox: [Int]) {
        self.sourceImageIndex = sourceImageIndex
        self.boundingBox = boundingBox
    }
}

public struct MultiItemAnalysisResponse: Codable {
    public let items: [DetectedInventoryItem]?
    public let detectedCount: Int
    public let analysisType: String
    public let confidence: Double

    public var isValid: Bool {
        let actualItems = items ?? []
        return actualItems.count == detectedCount && confidence >= 0.5 && detectedCount > 0 && !actualItems.isEmpty
    }

    public var safeItems: [DetectedInventoryItem] {
        return items ?? []
    }

    public init(
        items: [DetectedInventoryItem]?,
        detectedCount: Int,
        analysisType: String,
        confidence: Double
    ) {
        self.items = items
        self.detectedCount = detectedCount
        self.analysisType = analysisType
        self.confidence = confidence
    }
}

public struct DetectedInventoryItem: Codable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let category: String
    public let make: String
    public let model: String
    public let estimatedPrice: String
    public let confidence: Double
    public let detections: [ItemDetection]?

    public init(
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

    public init(from decoder: Decoder) throws {
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

    public func encode(to encoder: Encoder) throws {
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
