import CoreGraphics
import Testing

@testable import MovingBoxAIAnalysis

@Suite("AI Request Builder")
struct AIRequestBuilderTests {

    // MARK: - createImagePrompt tests

    @Test("Single image prompt mentions analyzing 'this image'")
    func singleImagePrompt() {
        let builder = makeBuilder()
        let prompt = builder.createImagePrompt(for: 1)
        #expect(prompt.contains("Analyze this image"))
        #expect(!prompt.contains("multi_item"))
    }

    @Test("Multi-image prompt references combining multiple photos")
    func multiImagePrompt() {
        let builder = makeBuilder()
        let prompt = builder.createImagePrompt(for: 3)
        #expect(prompt.contains("3 images"))
        #expect(prompt.contains("same item"))
    }

    @Test("Multi-item prompt includes critical requirements")
    func multiItemPrompt() {
        let builder = makeBuilder()
        let prompt = builder.createImagePrompt(for: 5, isMultiItem: true)
        #expect(prompt.contains("multi_item"))
        #expect(prompt.contains("items"))
        #expect(prompt.contains("CRITICAL REQUIREMENTS"))
        #expect(prompt.contains("Image 0 through Image 4"))
    }

    @Test("Multi-item prompt with narration context includes narration")
    func multiItemPromptWithNarration() {
        let builder = makeBuilder()
        let prompt = builder.createImagePrompt(
            for: 2,
            isMultiItem: true,
            narrationContext: "This is my living room with a couch and TV"
        )
        #expect(prompt.contains("living room with a couch and TV"))
        #expect(prompt.contains("narration"))
        #expect(prompt.contains("multi_item"))
    }

    @Test("Multi-item prompt with empty narration ignores narration section")
    func multiItemPromptEmptyNarration() {
        let builder = makeBuilder()
        let promptWithEmpty = builder.createImagePrompt(for: 2, isMultiItem: true, narrationContext: "   ")
        let promptWithoutNarration = builder.createImagePrompt(for: 2, isMultiItem: true)
        #expect(promptWithEmpty == promptWithoutNarration)
    }

    // MARK: - Helper

    private func makeBuilder() -> AIRequestBuilder {
        AIRequestBuilder(imageOptimizer: MockImageOptimizer())
    }
}

// MARK: - Test Doubles

private struct MockImageOptimizer: AIImageOptimizer {
    func optimizeImage(_ image: AIImage, maxDimension: CGFloat) async -> AIImage {
        image
    }
}
