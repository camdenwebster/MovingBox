import Foundation
import SwiftData
import UIKit

enum LabelAutoAssignment {
    static let maxLabelsPerItem = 5

    private static let ignoredCategoryNames: Set<String> = [
        "unknown", "uncategorized", "n/a", "none", "not specified", "other",
    ]

    private static let colorPalette: [UIColor] = [
        color(from: 0x007AFF),
        color(from: 0x8E4EC6),
        color(from: 0xFF9500),
        color(from: 0x34C759),
        color(from: 0xFF3B30),
        color(from: 0xFFCC02),
        color(from: 0xAF52DE),
        color(from: 0x32D74B),
        color(from: 0x64D2FF),
        color(from: 0xBF5AF2),
        color(from: 0xFF6482),
    ]

    private static let minimumSimilarityForExistingLabel = 0.58

    static func labels(
        for categories: [String],
        existingLabels: [InventoryLabel],
        modelContext: ModelContext?
    ) -> [InventoryLabel] {
        let cleanedCategories = categories.compactMap { normalizedCategoryName($0) }
        guard !cleanedCategories.isEmpty else { return [] }

        var labels: [InventoryLabel] = []
        var seen = Set<String>()
        let labelLookup = Dictionary(
            uniqueKeysWithValues: existingLabels.map { ($0.name.lowercased(), $0) }
        )

        for category in cleanedCategories {
            guard labels.count < maxLabelsPerItem else { break }
            let key = category.lowercased()
            guard !seen.contains(key) else { continue }

            if let existing = labelLookup[key] {
                labels.append(existing)
            } else if let similar = bestMatchingExistingLabel(for: category, in: existingLabels) {
                labels.append(similar)
            } else if let context = modelContext {
                let newLabel = InventoryLabel(
                    name: normalizedLabelName(category),
                    desc: "",
                    color: randomLabelColor(),
                    emoji: emojiForCategory(category)
                )
                context.insert(newLabel)
                labels.append(newLabel)
            }

            seen.insert(key)
        }

        return labels
    }

    private static func normalizedCategoryName(_ category: String) -> String? {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.lowercased()
        if ignoredCategoryNames.contains(lowered) {
            return nil
        }

        return trimmed
    }

    private static func normalizedLabelName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if trimmed == trimmed.lowercased() {
            return trimmed.capitalized
        }

        return trimmed
    }

    private static func randomLabelColor() -> UIColor {
        colorPalette.randomElement() ?? UIColor.systemBlue
    }

    private static func bestMatchingExistingLabel(
        for category: String,
        in existingLabels: [InventoryLabel]
    ) -> InventoryLabel? {
        let normalizedCategory = normalizeForMatching(category)
        guard !normalizedCategory.isEmpty else { return nil }

        var best: (label: InventoryLabel, score: Double)?

        for label in existingLabels {
            let score = similarityScore(
                lhs: normalizedCategory,
                rhs: normalizeForMatching(label.name)
            )

            if let currentBest = best {
                if score > currentBest.score {
                    best = (label, score)
                }
            } else {
                best = (label, score)
            }
        }

        guard let best, best.score >= minimumSimilarityForExistingLabel else { return nil }
        return best.label
    }

    private static func similarityScore(lhs: String, rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0.0 }
        if lhs == rhs { return 1.0 }

        let lhsTokens = Set(lhs.split(separator: " ").map(String.init))
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init))
        let common = lhsTokens.intersection(rhsTokens).count
        let tokenSimilarity =
            lhsTokens.isEmpty || rhsTokens.isEmpty
            ? 0.0
            : Double(common) / Double(max(lhsTokens.count, rhsTokens.count))

        let containsSimilarity: Double
        if lhs.contains(rhs) || rhs.contains(lhs) {
            containsSimilarity = 0.92
        } else {
            containsSimilarity = 0.0
        }

        let distance = levenshtein(lhs, rhs)
        let maxLen = max(lhs.count, rhs.count)
        let levenshteinSimilarity = maxLen == 0 ? 0.0 : 1.0 - (Double(distance) / Double(maxLen))

        return max(tokenSimilarity, containsSimilarity, levenshteinSimilarity)
    }

    private static func normalizeForMatching(_ value: String) -> String {
        let stopWords: Set<String> = ["and", "&", "item", "items", "stuff", "misc", "miscellaneous"]
        return
            value
            .lowercased()
            .split(separator: " ")
            .map { token -> String in
                let cleaned = token.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
                return String(String.UnicodeScalarView(cleaned))
            }
            .filter { !$0.isEmpty && !stopWords.contains($0) }
            .joined(separator: " ")
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

    private static func emojiForCategory(_ category: String) -> String {
        let lowercased = category.lowercased()
        let directMappings: [(keywords: [String], emoji: String)] = [
            (["guitar", "instrument", "music", "audio", "speaker", "amp", "amplifier"], "🎸"),
            (["phone", "laptop", "computer", "tablet", "electronics", "camera", "monitor"], "💻"),
            (["kitchen", "appliance", "cookware", "food", "dish", "utensil"], "🍽️"),
            (["furniture", "chair", "table", "sofa", "desk", "bed"], "🛋️"),
            (["tool", "hardware", "drill", "saw", "wrench", "screwdriver"], "🔧"),
            (["book", "document", "paper", "office", "stationery"], "📚"),
            (["car", "auto", "vehicle", "truck", "motorcycle", "bike"], "🚗"),
            (["clothing", "apparel", "fashion", "shoe", "jewelry", "watch"], "👕"),
            (["sport", "fitness", "exercise", "gym", "golf", "tennis"], "⚽"),
            (["outdoor", "garden", "plant", "nature"], "🌿"),
            (["pet", "animal", "dog", "cat", "bird", "fish"], "🐾"),
        ]

        for mapping in directMappings where containsAny(lowercased, keywords: mapping.keywords) {
            return mapping.emoji
        }

        let fallbackCategory: String
        if containsAny(lowercased, keywords: ["animal", "pet", "dog", "cat", "bird", "fish"]) {
            fallbackCategory = "Animals"
        } else if containsAny(lowercased, keywords: ["food", "kitchen", "cook", "cooking", "drink", "beverage"]) {
            fallbackCategory = "Food"
        } else if containsAny(lowercased, keywords: ["sport", "fitness", "game", "golf", "tennis", "soccer"]) {
            fallbackCategory = "Activity"
        } else if containsAny(
            lowercased,
            keywords: ["travel", "auto", "automotive", "vehicle", "car", "truck", "bike", "bicycle", "motor", "boat"])
        {
            fallbackCategory = "Travel"
        } else if containsAny(lowercased, keywords: ["clothing", "apparel", "shoe", "shoes", "fashion", "jewelry"]) {
            fallbackCategory = "Clothing"
        } else if containsAny(lowercased, keywords: ["garden", "plant", "nature", "outdoor"]) {
            fallbackCategory = "Nature"
        } else {
            fallbackCategory = "Objects"
        }

        // Deterministic fallback to avoid random, unrelated emoji assignment.
        let options = LabelEmojiCatalog.emojis(for: fallbackCategory)
        guard !options.isEmpty else { return "🏷️" }
        let stableHash = normalizedLabelName(category).unicodeScalars.reduce(0) { partial, scalar in
            (partial * 31 + Int(scalar.value)) & 0x7fff_ffff
        }
        return options[stableHash % options.count]
    }

    private static func containsAny(_ value: String, keywords: [String]) -> Bool {
        for keyword in keywords where value.contains(keyword) {
            return true
        }
        return false
    }

    private static func color(from hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
