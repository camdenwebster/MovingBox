import SwiftUI
import SwiftData

@MainActor
enum DefaultDataManager {
    static func getAllLabels(from context: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<InventoryLabel>()
        do {
            let labels = try context.fetch(descriptor)
            return ["None"] + labels.map { $0.name }
        } catch {
            print("Error fetching labels: \(error)")
            return ["None"]
        }
    }
    
    static func getAllLocations(from context: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<InventoryLocation>()
        do {
            let locations = try context.fetch(descriptor)
            return ["None"] + locations.map { $0.name }
        } catch {
            print("Error fetching locations: \(error)")
            return ["None"]
        }
    }
    
    static func populateDefaultLabels(modelContext: ModelContext) async {
        // Load only the default labels from TestData
        await TestData.loadDefaultData(context: modelContext)
        
        do {
            try modelContext.save()
            print("✅ Default labels saved successfully")
        } catch {
            print("❌ Error saving default labels: \(error)")
        }
    }
    
    static func populateTestData(modelContext: ModelContext) async {
        // Load test data directly
        await TestData.loadTestData(context: modelContext)
        
        do {
            try modelContext.save()
            print("✅ Test data saved successfully")
        } catch {
            print("❌ Error saving test data: \(error)")
        }
    }
    
    static func populateDefaultData(modelContext: ModelContext) async {
        
    }
}
