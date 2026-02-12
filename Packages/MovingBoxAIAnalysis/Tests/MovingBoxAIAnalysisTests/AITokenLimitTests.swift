import Testing

@testable import MovingBoxAIAnalysis

@Suite("AI Token Limit Calculation")
struct AITokenLimitTests {

    @Test("Single image standard quality returns base tokens")
    func singleImageStandard() {
        let result = calculateAITokenLimit(imageCount: 1, isPro: false, highQualityEnabled: false)
        #expect(result == 3000)
    }

    @Test("Single image high quality returns 3x base tokens")
    func singleImageHighQuality() {
        let result = calculateAITokenLimit(imageCount: 1, isPro: true, highQualityEnabled: true)
        #expect(result == 9000)
    }

    @Test("Five images standard quality adds 300 per extra image")
    func fiveImagesStandard() {
        let result = calculateAITokenLimit(imageCount: 5, isPro: false, highQualityEnabled: false)
        // base 3000 + (5-1)*300 = 3000 + 1200 = 4200
        #expect(result == 4200)
    }

    @Test("Five images high quality multiplies by 3")
    func fiveImagesHighQuality() {
        let result = calculateAITokenLimit(imageCount: 5, isPro: true, highQualityEnabled: true)
        // (3000 + 1200) * 3 = 12600
        #expect(result == 12600)
    }

    @Test("60 images at max limit")
    func sixtyImagesStandard() {
        let result = calculateAITokenLimit(imageCount: 60, isPro: false, highQualityEnabled: false)
        // base 3000 + (60-1)*300 = 3000 + 17700 = 20700
        #expect(result == 20700)
    }

    @Test("61 images clamped to 60 max")
    func sixtyOneImagesClamped() {
        let result60 = calculateAITokenLimit(imageCount: 60, isPro: false, highQualityEnabled: false)
        let result61 = calculateAITokenLimit(imageCount: 61, isPro: false, highQualityEnabled: false)
        #expect(result60 == result61)
    }

    @Test("Multi-item has 12000 minimum floor")
    func multiItemMinimumFloor() {
        let result = calculateAITokenLimit(imageCount: 1, isPro: false, highQualityEnabled: false, isMultiItem: true)
        // base 3000 but multi-item floor is 12000
        #expect(result == 12000)
    }

    @Test("Multi-item high quality exceeds floor")
    func multiItemHighQualityExceedsFloor() {
        let result = calculateAITokenLimit(imageCount: 5, isPro: true, highQualityEnabled: true, isMultiItem: true)
        // (3000 + 1200) * 3 = 12600, which > 12000 floor
        #expect(result == 12600)
    }

    @Test("Pro without high quality enabled uses standard rate")
    func proWithoutHighQuality() {
        let result = calculateAITokenLimit(imageCount: 1, isPro: true, highQualityEnabled: false)
        #expect(result == 3000)
    }
}
