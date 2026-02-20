import Testing

@testable import MovingBox

@MainActor
@Suite("Label Emoji Catalog Tests")
struct LabelAutoAssignmentTests {
    @Test("Returns emojis for known catalog category")
    func testKnownCategoryReturnsEmojis() {
        let emojis = LabelEmojiCatalog.emojis(for: "Food")
        #expect(!emojis.isEmpty)
        #expect(emojis.contains("🍕"))
    }

    @Test("Category lookup is case insensitive")
    func testCategoryLookupCaseInsensitive() {
        let lower = LabelEmojiCatalog.emojis(for: "animals")
        let mixed = LabelEmojiCatalog.emojis(for: "AnImAlS")
        #expect(lower == mixed)
        #expect(!lower.isEmpty)
    }

    @Test("Unknown category returns empty list")
    func testUnknownCategoryReturnsEmpty() {
        #expect(LabelEmojiCatalog.emojis(for: "not-a-category").isEmpty)
    }
}
