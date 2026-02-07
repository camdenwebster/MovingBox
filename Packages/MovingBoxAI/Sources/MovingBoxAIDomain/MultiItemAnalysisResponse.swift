import Foundation

public struct MultiItemAnalysisResponse: Codable, Sendable {
    public let items: [DetectedInventoryItem]?
    public let detectedCount: Int
    public let analysisType: String
    public let confidence: Double

    public init(items: [DetectedInventoryItem]?, detectedCount: Int, analysisType: String, confidence: Double) {
        self.items = items
        self.detectedCount = detectedCount
        self.analysisType = analysisType
        self.confidence = confidence
    }

    public var isValid: Bool {
        let actualItems = items ?? []
        return actualItems.count == detectedCount && confidence >= 0.5 && detectedCount > 0 && !actualItems.isEmpty
    }

    public var safeItems: [DetectedInventoryItem] {
        items ?? []
    }
}
