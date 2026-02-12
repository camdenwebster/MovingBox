import Foundation
import MovingBoxAIAnalysis

enum VideoItemDeduplicator {
    struct MergedItem {
        var item: DetectedInventoryItem
        var confidenceSum: Double
        var count: Int
        var detections: [ItemDetection]
        var normalizedTitle: String
    }

    static func deduplicate(
        batchResults: [(response: MultiItemAnalysisResponse, batchOffset: Int)]
    ) -> MultiItemAnalysisResponse {
        var mergedItems: [MergedItem] = []

        for batch in batchResults {
            let items = batch.response.safeItems
            for item in items {
                let adjustedDetections = adjustDetections(item.detections, offset: batch.batchOffset)
                let normalizedTitle = normalizeTitle(item.title)

                if let index = mergedItems.firstIndex(where: {
                    isMatch(candidate: item, normalizedCandidate: normalizedTitle, existing: $0)
                }) {
                    merge(
                        into: &mergedItems[index], newItem: item, normalizedTitle: normalizedTitle,
                        detections: adjustedDetections)
                } else {
                    let merged = MergedItem(
                        item: DetectedInventoryItem(
                            id: item.id,
                            title: item.title,
                            description: item.description,
                            category: item.category,
                            make: item.make,
                            model: item.model,
                            estimatedPrice: item.estimatedPrice,
                            confidence: item.confidence,
                            detections: adjustedDetections
                        ),
                        confidenceSum: item.confidence,
                        count: 1,
                        detections: adjustedDetections,
                        normalizedTitle: normalizedTitle
                    )
                    mergedItems.append(merged)
                }
            }
        }

        let finalItems = mergedItems.map { merged -> DetectedInventoryItem in
            var item = merged.item
            let averagedConfidence = merged.confidenceSum / Double(max(merged.count, 1))
            item = DetectedInventoryItem(
                id: item.id,
                title: item.title,
                description: item.description,
                category: item.category,
                make: item.make,
                model: item.model,
                estimatedPrice: item.estimatedPrice,
                confidence: averagedConfidence,
                detections: merged.detections
            )
            return item
        }

        return MultiItemAnalysisResponse(
            items: finalItems,
            detectedCount: finalItems.count,
            analysisType: "multi_item",
            confidence: averageConfidence(from: finalItems)
        )
    }

    private static func adjustDetections(_ detections: [ItemDetection]?, offset: Int) -> [ItemDetection] {
        guard let detections else { return [] }
        return detections.map { detection in
            ItemDetection(
                sourceImageIndex: detection.sourceImageIndex + offset,
                boundingBox: detection.boundingBox
            )
        }
    }

    private static func isMatch(
        candidate: DetectedInventoryItem,
        normalizedCandidate: String,
        existing: MergedItem
    ) -> Bool {
        let normalizedExisting = existing.normalizedTitle
        if normalizedCandidate.isEmpty || normalizedExisting.isEmpty {
            return false
        }

        if levenshtein(normalizedCandidate, normalizedExisting) <= 3 {
            return true
        }

        let candidateWords = normalizedCandidate.split(separator: " ")
        let existingWords = normalizedExisting.split(separator: " ")
        if candidateWords.count >= 3,
            existingWords.count >= 3,
            candidateWords.prefix(3) == existingWords.prefix(3),
            candidate.category == existing.item.category
        {
            return true
        }

        return false
    }

    private static func merge(
        into merged: inout MergedItem,
        newItem: DetectedInventoryItem,
        normalizedTitle: String,
        detections: [ItemDetection]
    ) {
        merged.confidenceSum += newItem.confidence
        merged.count += 1
        merged.detections.append(contentsOf: detections)

        if newItem.confidence > merged.item.confidence {
            merged.item = DetectedInventoryItem(
                id: merged.item.id,
                title: newItem.title,
                description: merged.item.description,
                category: newItem.category,
                make: newItem.make,
                model: newItem.model,
                estimatedPrice: merged.item.estimatedPrice,
                confidence: merged.item.confidence,
                detections: merged.item.detections
            )
            merged.normalizedTitle = normalizedTitle
        }

        if newItem.description.count > merged.item.description.count {
            merged.item = DetectedInventoryItem(
                id: merged.item.id,
                title: merged.item.title,
                description: newItem.description,
                category: merged.item.category,
                make: merged.item.make,
                model: merged.item.model,
                estimatedPrice: merged.item.estimatedPrice,
                confidence: merged.item.confidence,
                detections: merged.item.detections
            )
        }

        if let higherPrice = pickHigherPrice(current: merged.item.estimatedPrice, candidate: newItem.estimatedPrice) {
            merged.item = DetectedInventoryItem(
                id: merged.item.id,
                title: merged.item.title,
                description: merged.item.description,
                category: merged.item.category,
                make: merged.item.make,
                model: merged.item.model,
                estimatedPrice: higherPrice,
                confidence: merged.item.confidence,
                detections: merged.item.detections
            )
        }
    }

    private static func normalizeTitle(_ title: String) -> String {
        let articles: Set<String> = ["a", "an", "the"]
        let tokens =
            title
            .lowercased()
            .split(separator: " ")
            .map { token -> String in
                let cleaned = token.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
                return String(String.UnicodeScalarView(cleaned))
            }
            .filter { !articles.contains($0) }
            .filter { !$0.isEmpty }

        return tokens.joined(separator: " ")
    }

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)

        if lhsChars.isEmpty { return rhsChars.count }
        if rhsChars.isEmpty { return lhsChars.count }

        var distances = Array(repeating: Array(repeating: 0, count: rhsChars.count + 1), count: lhsChars.count + 1)

        for i in 0...lhsChars.count { distances[i][0] = i }
        for j in 0...rhsChars.count { distances[0][j] = j }

        for i in 1...lhsChars.count {
            for j in 1...rhsChars.count {
                if lhsChars[i - 1] == rhsChars[j - 1] {
                    distances[i][j] = distances[i - 1][j - 1]
                } else {
                    let deletion = distances[i - 1][j] + 1
                    let insertion = distances[i][j - 1] + 1
                    let substitution = distances[i - 1][j - 1] + 1
                    distances[i][j] = min(deletion, insertion, substitution)
                }
            }
        }

        return distances[lhsChars.count][rhsChars.count]
    }

    private static func pickHigherPrice(current: String, candidate: String) -> String? {
        let currentValue = parsePrice(current)
        let candidateValue = parsePrice(candidate)

        switch (currentValue, candidateValue) {
        case (nil, nil):
            return nil
        case (nil, .some):
            return candidate
        case (.some, nil):
            return current
        case (.some(let currentValue), .some(let candidateValue)):
            return candidateValue > currentValue ? candidate : current
        }
    }

    private static func parsePrice(_ value: String) -> Decimal? {
        let cleaned =
            value
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Decimal(string: cleaned)
    }

    private static func averageConfidence(from items: [DetectedInventoryItem]) -> Double {
        guard !items.isEmpty else { return 0.0 }
        let total = items.reduce(0.0) { $0 + $1.confidence }
        return total / Double(items.count)
    }
}
