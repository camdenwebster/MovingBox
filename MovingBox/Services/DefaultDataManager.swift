import SwiftUI
import SwiftData

@MainActor
class DefaultDataManager {
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
        await TestData.loadDefaultData(context: modelContext)
        
        do {
            try modelContext.save()
            print("✅ Default labels saved successfully")
        } catch {
            print("❌ Error saving default labels: \(error)")
        }
    }
    
    static func populateTestData(modelContext: ModelContext) async {
        await TestData.loadTestData(context: modelContext)
        
        do {
            try modelContext.save()
            print("✅ Test data saved successfully")
        } catch {
            print("❌ Error saving test data: \(error)")
        }
    }
    
    static func populateDefaultData(modelContext: ModelContext) async {
        if !ProcessInfo.processInfo.arguments.contains("UI-Testing") {
            let homesFetch = try? modelContext.fetch(FetchDescriptor<Home>())
            if homesFetch?.isEmpty ?? true {
                let defaultHome = Home()
                modelContext.insert(defaultHome)
            }
        }
        
        // Create default labels if needed
        let _ = await populateDefaultLabels(modelContext: modelContext)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error saving default data: \(error)")
        }
    }
}
