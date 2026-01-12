import CloudKit
import SwiftData
import SwiftUI

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

        if let existingHome = homes.last {
            return existingHome
        }

        // If using iCloud, wait briefly for potential sync
        let isUsingICloud = modelContext.container.configurations.first?.cloudKitDatabase != nil

        if isUsingICloud {
            print("🔍 Checking for Home in iCloud...")
            // Wait for a short time to allow initial sync
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000)  // 2 seconds

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

    static func checkForExistingObjects<T>(of type: T.Type, in context: ModelContext) async -> Bool
    where T: PersistentModel {
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
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)  // 2 seconds

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

    static func populateDefaultLocations(modelContext: ModelContext) async {
        let hasExistingLocations = await checkForExistingObjects(
            of: InventoryLocation.self, in: modelContext)

        if !hasExistingLocations {
            print("📍 No existing locations found, creating default rooms...")
            await createDefaultRooms(context: modelContext)

            do {
                try modelContext.save()
                print("✅ Default rooms saved successfully")
            } catch {
                print("❌ Error saving default rooms: \(error)")
            }
        } else {
            print("📍 Existing locations found, skipping default room creation")
        }
    }

    private static func createDefaultRooms(context: ModelContext) async {
        for roomData in TestData.defaultRooms {
            let location = InventoryLocation(
                name: roomData.name,
                desc: roomData.desc
            )
            location.sfSymbolName = roomData.sfSymbol
            context.insert(location)
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

    private static func hasExistingICloudData(modelContext: ModelContext) async -> Bool {
        func hasAnyObjects<T: PersistentModel>(_ type: T.Type) -> Bool {
            let descriptor = FetchDescriptor<T>()
            return (try? modelContext.fetch(descriptor).isEmpty == false) ?? false
        }

        if hasAnyObjects(Home.self)
            || hasAnyObjects(InventoryItem.self)
            || hasAnyObjects(InventoryLocation.self)
            || hasAnyObjects(InventoryLabel.self)
        {
            return true
        }

        let isUsingICloud = modelContext.container.configurations.first?.cloudKitDatabase != nil
        guard isUsingICloud else {
            return false
        }

        print("🔍 Checking for existing iCloud data before creating defaults...")
        try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)

        return hasAnyObjects(Home.self)
            || hasAnyObjects(InventoryItem.self)
            || hasAnyObjects(InventoryLocation.self)
            || hasAnyObjects(InventoryLabel.self)
    }

    @MainActor
    static func populateDefaultData(modelContext: ModelContext) async {
        if !ProcessInfo.processInfo.arguments.contains("Use-Test-Data") {
            do {
                let shouldCheckDefaults = !OnboardingManager.hasCompletedOnboarding()
                let hasExistingICloudData =
                    shouldCheckDefaults ? await hasExistingICloudData(modelContext: modelContext) : false

                let _ = try await getOrCreateHome(modelContext: modelContext)

                // Only populate defaults for first launch
                if shouldCheckDefaults {
                    print("🔎 Default data gate - existing iCloud data: \(hasExistingICloudData)")
                    if hasExistingICloudData {
                        print("☁️ Existing iCloud data found, skipping default data creation")
                        try modelContext.save()
                        return
                    }

                    await populateDefaultLabels(modelContext: modelContext)
                    await populateDefaultLocations(modelContext: modelContext)
                }

                try modelContext.save()
            } catch {
                print("❌ Error setting up default data: \(error)")
            }
        }
    }
}
