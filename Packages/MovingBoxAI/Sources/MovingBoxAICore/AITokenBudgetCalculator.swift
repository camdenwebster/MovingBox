import Foundation

public enum AITokenBudgetCalculator {
    public static func maxCompletionTokens(
        imageCount: Int,
        isPro: Bool,
        highQualityAnalysisEnabled: Bool
    ) -> Int {
        let baseTokens = 3000
        let clampedImageCount = min(max(imageCount, 1), 5)
        let additionalTokens = max(0, clampedImageCount - 1) * 300
        let lowQualityTokens = baseTokens + additionalTokens
        let isHighQuality = isPro && highQualityAnalysisEnabled
        return isHighQuality ? lowQualityTokens * 3 : lowQualityTokens
    }
}
