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
            // Only create default data if onboarding hasn't been completed
            if !OnboardingManager.hasCompletedOnboarding() {
                print("🆕 First launch detected, creating default data...")
                let defaultHome = Home()
                modelContext.insert(defaultHome)
                await populateDefaultLabels(modelContext: modelContext)
            } else {
                // If onboarding is complete, check iCloud for existing data
                let hasExistingHome = await checkForExistingHome(modelContext: modelContext)
                
                if !hasExistingHome {
                    print("🏠 No existing home found, creating default home...")
                    let defaultHome = Home()
                    modelContext.insert(defaultHome)
                } else {
                    print("🏠 Existing home found, skipping default home creation")
                }
                
                // Only check for labels if we don't have a home (new device setup)
                if !hasExistingHome {
                    await populateDefaultLabels(modelContext: modelContext)
                }
            }
            
            do {
                try modelContext.save()
            } catch {
                print("❌ Error saving default data: \(error)")
            }
        }
    }
}
