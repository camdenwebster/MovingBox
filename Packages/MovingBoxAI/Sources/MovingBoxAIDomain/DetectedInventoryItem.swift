import Foundation

public struct DetectedInventoryItem: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let description: String
    public let category: String
    public let make: String
    public let model: String
    public let estimatedPrice: String
    public let confidence: Double

    public init(
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
