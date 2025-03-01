import SwiftUI
import SwiftData

class DefaultDataManager {
    private static let defaultLocations = ["Kitchen", "Office", "Bedroom", "Bathroom", "Hallway Closet", "Basement", "Attic"]
    private static let defaultLabels = ["Musical instruments", "Kitchen appliances", "Decor", "Cooking Utensils", "Electronics", "Household Items"]
    private static let defaultColors: [UIColor] = [
        .systemBlue,
        .systemGreen,
        .systemRed,
        .systemOrange,
        .systemPurple,
        .systemTeal,
        .systemYellow,
        .systemPink
    ]

    static func populateInitialData(modelContext: ModelContext) {
        let locationDescriptor = FetchDescriptor<InventoryLocation>()
        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        
        do {
            let existingLocations = try modelContext.fetch(locationDescriptor)
            let existingLabels = try modelContext.fetch(labelDescriptor)
            
            // Only populate if both are empty
            if existingLocations.isEmpty && existingLabels.isEmpty {
                print("First launch detected, creating default locations and labels")
                
                // Create default locations
                defaultLocations.forEach { locationName in
                    let location = InventoryLocation(name: locationName, desc: "")
                    modelContext.insert(location)
                }
                
                // Create default labels with colors
                defaultLabels.enumerated().forEach { index, labelName in
                    let color = defaultColors[index % defaultColors.count]
                    let label = InventoryLabel(name: labelName, desc: "", color: color)
                    modelContext.insert(label)
                }
                
                try modelContext.save()
                print("Default locations and labels created successfully")
            }
        } catch {
            print("Error checking or creating default data: \(error)")
        }
    }
    
    static func getAllLabels(from context: ModelContext) -> [String] {
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            var result: [String] = ["None"]
            DispatchQueue.main.sync {
                result = getAllLabels(from: context)
            }
            return result
        }
        
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
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            var result: [String] = ["None"]
            DispatchQueue.main.sync {
                result = getAllLocations(from: context)
            }
            return result
        }
        
        let descriptor = FetchDescriptor<InventoryLocation>()
        do {
            let locations = try context.fetch(descriptor)
            return ["None"] + locations.map { $0.name }
        } catch {
            print("Error fetching locations: \(error)")
            return ["None"]
        }
    }
}
