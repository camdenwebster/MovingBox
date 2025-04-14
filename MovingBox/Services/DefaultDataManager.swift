import SwiftUI
import SwiftData
import CloudKit

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
    
    static func getOrCreateHome(modelContext: ModelContext) async throws -> Home {
        let descriptor = FetchDescriptor<Home>()
        let homes = try modelContext.fetch(descriptor)
        
        if let existingHome = homes.first {
            return existingHome
        }
        
        // If using iCloud, wait briefly for potential sync
        let isUsingICloud = modelContext.container.configurations.first?.cloudKitDatabase != nil
        
        if isUsingICloud {
            print("🔍 Checking for Home in iCloud...")
            // Wait for a short time to allow initial sync
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds
            
            // Check again after waiting
            let secondCheck = try modelContext.fetch(descriptor)
            if let syncedHome = secondCheck.first {
                return syncedHome
            }
        }
        
        // If we still don't have a home, create one
        print("🏠 No existing home found, creating new home...")
        let newHome = Home()
        modelContext.insert(newHome)
        try modelContext.save()
        return newHome
    }
    
    static func checkForExistingObjects<T>(of type: T.Type, in context: ModelContext) async -> Bool where T: PersistentModel {
        // First check if we can fetch any objects
        let descriptor = FetchDescriptor<T>()
        if let objects = try? context.fetch(descriptor), !objects.isEmpty {
            return true
        }
        
        // If using iCloud, wait briefly for potential sync
        let isUsingICloud = context.container.configurations.first?.cloudKitDatabase != nil
        
        if isUsingICloud {
            print("🔍 Checking for \(String(describing: T.self)) in iCloud...")
            // Wait for a short time to allow initial sync
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds
            
            // Check again after waiting
            let secondFetch = try? context.fetch(descriptor)
            return (secondFetch?.isEmpty ?? true) == false
        }
        
        return false
    }
    
    static func populateDefaultLabels(modelContext: ModelContext) async {
        let hasExistingLabels = await checkForExistingObjects(of: InventoryLabel.self, in: modelContext)
        
        if !hasExistingLabels {
            print("🏷️ No existing labels found, creating default labels...")
            await TestData.loadDefaultData(context: modelContext)
            
            do {
                try modelContext.save()
                print("✅ Default labels saved successfully")
            } catch {
                print("❌ Error saving default labels: \(error)")
            }
        } else {
            print("🏷️ Existing labels found, skipping default label creation")
        }
    }
    
    @MainActor
    static func populateTestData(modelContext: ModelContext) async {
        await TestData.loadTestData(modelContext: modelContext)
        
        do {
            try modelContext.save()
            print("✅ Test data saved successfully")
        } catch {
            print("❌ Error saving test data: \(error)")
        }
    }
    
    static func checkForExistingHome(modelContext: ModelContext) async -> Bool {
        return await checkForExistingObjects(of: Home.self, in: modelContext)
    }
    
    @MainActor
    static func populateDefaultData(modelContext: ModelContext) async {
        if !ProcessInfo.processInfo.arguments.contains("Use-Test-Data") {
            do {
                let _ = try await getOrCreateHome(modelContext: modelContext)
                
                // Only populate labels for first launch
                if !OnboardingManager.hasCompletedOnboarding() {
                    await populateDefaultLabels(modelContext: modelContext)
                }
                
                try modelContext.save()
            } catch {
                print("❌ Error setting up default data: \(error)")
            }
        }
    }
}
