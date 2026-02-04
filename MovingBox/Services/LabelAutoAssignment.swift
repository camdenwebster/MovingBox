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

    static func labels(
        for categories: [String],
        existingLabels: [InventoryLabel],
        modelContext: ModelContext?
    ) -> [InventoryLabel] {
        let cleanedCategories = categories.compactMap { normalizedCategoryName($0) }
        guard !cleanedCategories.isEmpty else { return [] }

        var labels: [InventoryLabel] = []
        var seen = Set<String>()
        var labelLookup = Dictionary(
            uniqueKeysWithValues: existingLabels.map { ($0.name.lowercased(), $0) }
        )

        for category in cleanedCategories {
            guard labels.count < maxLabelsPerItem else { break }
            let key = category.lowercased()
            guard !seen.contains(key) else { continue }

            if let existing = labelLookup[key] {
                labels.append(existing)
            } else if let context = modelContext {
                let newLabel = InventoryLabel(
                    name: normalizedLabelName(category),
                    desc: "",
                    color: randomLabelColor(),
                    emoji: emojiForCategory(category)
                )
                context.insert(newLabel)
                labels.append(newLabel)
                labelLookup[key] = newLabel
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

    private static func emojiForCategory(_ category: String) -> String {
        let lowercased = category.lowercased()
        let emojiCategory: String

        if containsAny(lowercased, keywords: ["animal", "pet", "dog", "cat", "bird", "fish"]) {
            emojiCategory = "Animals"
        } else if containsAny(lowercased, keywords: ["food", "kitchen", "cook", "cooking", "drink", "beverage"]) {
            emojiCategory = "Food"
        } else if containsAny(lowercased, keywords: ["sport", "fitness", "game", "golf", "tennis", "soccer"]) {
            emojiCategory = "Activity"
        } else if containsAny(
            lowercased,
            keywords: ["travel", "auto", "automotive", "vehicle", "car", "truck", "bike", "bicycle", "motor", "boat"])
        {
            emojiCategory = "Travel"
        } else if containsAny(lowercased, keywords: ["clothing", "apparel", "shoe", "shoes", "fashion", "jewelry"]) {
            emojiCategory = "Clothing"
        } else if containsAny(lowercased, keywords: ["garden", "plant", "nature", "outdoor"]) {
            emojiCategory = "Nature"
        } else {
            emojiCategory = "Objects"
        }

        return LabelEmojiCatalog.randomEmoji(in: emojiCategory)
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
