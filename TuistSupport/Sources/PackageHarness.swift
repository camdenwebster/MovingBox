import Foundation
import MovingBoxAICore
import MovingBoxAIDomain

public enum PackageHarness {
    public static func smokeCheck() -> Bool {
        let budget = AITokenBudgetCalculator.maxCompletionTokens(
            imageCount: 1,
            isPro: false,
            highQualityAnalysisEnabled: false
        )
        return budget == 3000 && ImageDetails.empty().title.isEmpty
    }
}
