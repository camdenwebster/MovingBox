import XCTest

@testable import MovingBoxAICore

final class AITokenBudgetCalculatorTests: XCTestCase {
    func testSingleImageStandardQuality() {
        let tokens = AITokenBudgetCalculator.maxCompletionTokens(
            imageCount: 1,
            isPro: false,
            highQualityAnalysisEnabled: false
        )
        XCTAssertEqual(tokens, 3000)
    }

    func testMultipleImagesAddsBudgetAndCapsAtFive() {
        let tokens3 = AITokenBudgetCalculator.maxCompletionTokens(
            imageCount: 3,
            isPro: false,
            highQualityAnalysisEnabled: false
        )
        XCTAssertEqual(tokens3, 3600)

        let tokens10 = AITokenBudgetCalculator.maxCompletionTokens(
            imageCount: 10,
            isPro: false,
            highQualityAnalysisEnabled: false
        )
        XCTAssertEqual(tokens10, 4200)
    }

    func testHighQualityMultiplierAppliedOnlyForPro() {
        let pro = AITokenBudgetCalculator.maxCompletionTokens(
            imageCount: 2,
            isPro: true,
            highQualityAnalysisEnabled: true
        )
        XCTAssertEqual(pro, 9900)

        let nonPro = AITokenBudgetCalculator.maxCompletionTokens(
            imageCount: 2,
            isPro: false,
            highQualityAnalysisEnabled: true
        )
        XCTAssertEqual(nonPro, 3300)
    }
}
