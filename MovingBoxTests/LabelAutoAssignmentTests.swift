import SwiftData
import Testing
import UIKit

@testable import MovingBox

@MainActor
@Suite("Label Auto Assignment Tests")
struct LabelAutoAssignmentTests {
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self,
            Home.self,
            InsurancePolicy.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @Test("Reuses a similar existing label instead of creating a new one")
    func testReusesSimilarExistingLabel() throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let kitchen = InventoryLabel(name: "Kitchen", desc: "", color: .systemOrange, emoji: "🍽️")
        context.insert(kitchen)
        try context.save()

        let assigned = LabelAutoAssignment.labels(
            for: ["Kitchen Appliance"],
            existingLabels: [kitchen],
            modelContext: context
        )

        let labelsInStore = try context.fetch(FetchDescriptor<InventoryLabel>())
        #expect(assigned.count == 1)
        #expect(assigned.first?.id == kitchen.id)
        #expect(labelsInStore.count == 1)
    }

    @Test("Creates a context-aware emoji for new labels")
    func testContextAwareEmojiForNewLabel() throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let assigned = LabelAutoAssignment.labels(
            for: ["Guitar Equipment"],
            existingLabels: [],
            modelContext: context
        )

        #expect(assigned.count == 1)
        #expect(assigned.first?.emoji == "🎸")
    }
}
