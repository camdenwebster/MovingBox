//
//  IntentParameters.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents
import SwiftData

// MARK: - Inventory Item Parameters

@available(iOS 16.0, *)
struct InventoryItemEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Inventory Item"
    
    let id: String
    let title: String
    let quantity: String
    let description: String
    let location: String?
    let label: String?
    
    var displayRepresentation: DisplayRepresentation {
        let subtitle = [location, label].compactMap { $0 }.joined(separator: " • ")
        return DisplayRepresentation(
            title: "\(title)",
            subtitle: subtitle.isEmpty ? quantity : "\(quantity) • \(subtitle)"
        )
    }
    
    static let defaultQuery = InventoryItemQuery()
    
    init(from item: InventoryItem) {
        self.id = item.persistentModelID.uriRepresentation().absoluteString
        self.title = item.title
        self.quantity = item.quantityString
        self.description = item.desc
        self.location = item.location?.name
        self.label = item.label?.name
    }
}

@available(iOS 16.0, *)
struct InventoryItemQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [InventoryItemEntity] {
        let context = BaseDataIntent.sharedContainer.mainContext
        let items = try await getInventoryItems(context: context, identifiers: identifiers)
        return items.map { InventoryItemEntity(from: $0) }
    }
    
    func entities(matching string: String) async throws -> [InventoryItemEntity] {
        let context = BaseDataIntent.sharedContainer.mainContext
        let predicate = #Predicate<InventoryItem> { item in
            item.title.localizedStandardContains(string) ||
            item.desc.localizedStandardContains(string)
        }
        let descriptor = FetchDescriptor<InventoryItem>(predicate: predicate)
        let items = try context.fetch(descriptor)
        return items.map { InventoryItemEntity(from: $0) }
    }
    
    func suggestedEntities() async throws -> [InventoryItemEntity] {
        let context = BaseDataIntent.sharedContainer.mainContext
        let descriptor = FetchDescriptor<InventoryItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        let items = try context.fetch(descriptor)
        return items.map { InventoryItemEntity(from: $0) }
    }
    
    private func getInventoryItems(context: ModelContext, identifiers: [String]) async throws -> [InventoryItem] {
        var items: [InventoryItem] = []
        for identifier in identifiers {
            guard let url = URL(string: identifier),
                  let modelID = context.model.persistentModelID(for: url) else { continue }
            if let item = context.model.registeredModel(for: modelID) as? InventoryItem {
                items.append(item)
            }
        }
        return items
    }
}

// MARK: - Location Parameters

@available(iOS 16.0, *)
struct LocationEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Location"
    
    let id: String
    let name: String
    let itemCount: Int
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(itemCount) item\(itemCount == 1 ? "" : "s")"
        )
    }
    
    static let defaultQuery = LocationQuery()
    
    init(from location: InventoryLocation, itemCount: Int = 0) {
        self.id = location.persistentModelID.uriRepresentation().absoluteString
        self.name = location.name
        self.itemCount = itemCount
    }
}

@available(iOS 16.0, *)
struct LocationQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LocationEntity] {
        let context = BaseDataIntent.sharedContainer.mainContext
        let locations = try await getLocations(context: context, identifiers: identifiers)
        return await withTaskGroup(of: LocationEntity.self) { group in
            for location in locations {
                group.addTask {
                    let itemCount = await getItemCount(for: location, context: context)
                    return LocationEntity(from: location, itemCount: itemCount)
                }
            }
            
            var results: [LocationEntity] = []
            for await entity in group {
                results.append(entity)
            }
            return results
        }
    }
    
    func entities(matching string: String) async throws -> [LocationEntity] {
        let context = BaseDataIntent.sharedContainer.mainContext
        let predicate = #Predicate<InventoryLocation> { location in
            location.name.localizedStandardContains(string)
        }
        let descriptor = FetchDescriptor<InventoryLocation>(predicate: predicate)
        let locations = try context.fetch(descriptor)
        
        return await withTaskGroup(of: LocationEntity.self) { group in
            for location in locations {
                group.addTask {
                    let itemCount = await getItemCount(for: location, context: context)
                    return LocationEntity(from: location, itemCount: itemCount)
                }
            }
            
            var results: [LocationEntity] = []
            for await entity in group {
                results.append(entity)
            }
            return results
        }
    }
    
    func suggestedEntities() async throws -> [LocationEntity] {
        let context = BaseDataIntent.sharedContainer.mainContext
        let descriptor = FetchDescriptor<InventoryLocation>(
            sortBy: [SortDescriptor(\.name)]
        )
        let locations = try context.fetch(descriptor)
        
        return await withTaskGroup(of: LocationEntity.self) { group in
            for location in locations {
                group.addTask {
                    let itemCount = await getItemCount(for: location, context: context)
                    return LocationEntity(from: location, itemCount: itemCount)
                }
            }
            
            var results: [LocationEntity] = []
            for await entity in group {
                results.append(entity)
            }
            return results
        }
    }
    
    private func getLocations(context: ModelContext, identifiers: [String]) async throws -> [InventoryLocation] {
        var locations: [InventoryLocation] = []
        for identifier in identifiers {
            guard let url = URL(string: identifier),
                  let modelID = context.model.persistentModelID(for: url) else { continue }
            if let location = context.model.registeredModel(for: modelID) as? InventoryLocation {
                locations.append(location)
            }
        }
        return locations
    }
    
    private func getItemCount(for location: InventoryLocation, context: ModelContext) async -> Int {
        let predicate = #Predicate<InventoryItem> { item in
            item.location?.name == location.name
        }
        let descriptor = FetchDescriptor<InventoryItem>(predicate: predicate)
        return (try? context.fetch(descriptor).count) ?? 0
    }
}

// MARK: - Label Parameters

@available(iOS 16.0, *)
struct LabelEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Label"
    
    let id: String
    let name: String
    let colorHex: String
    let itemCount: Int
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(itemCount) item\(itemCount == 1 ? "" : "s")"
        )
    }
    
    static let defaultQuery = LabelQuery()
    
    init(from label: InventoryLabel, itemCount: Int = 0) {
        self.id = label.persistentModelID.uriRepresentation().absoluteString
        self.name = label.name
        self.colorHex = label.colorHex
        self.itemCount = itemCount
    }
}

@available(iOS 16.0, *)
struct LabelQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LabelEntity] {
        let context = BaseDataIntent.sharedContainer.mainContext
        let labels = try await getLabels(context: context, identifiers: identifiers)
        return await withTaskGroup(of: LabelEntity.self) { group in
            for label in labels {
                group.addTask {
                    let itemCount = await getItemCount(for: label, context: context)
                    return LabelEntity(from: label, itemCount: itemCount)
                }
            }
            
            var results: [LabelEntity] = []
            for await entity in group {
                results.append(entity)
            }
            return results
        }
    }
    
    func entities(matching string: String) async throws -> [LabelEntity] {
        let context = BaseDataIntent.sharedContainer.mainContext
        let predicate = #Predicate<InventoryLabel> { label in
            label.name.localizedStandardContains(string)
        }
        let descriptor = FetchDescriptor<InventoryLabel>(predicate: predicate)
        let labels = try context.fetch(descriptor)
        
        return await withTaskGroup(of: LabelEntity.self) { group in
            for label in labels {
                group.addTask {
                    let itemCount = await getItemCount(for: label, context: context)
                    return LabelEntity(from: label, itemCount: itemCount)
                }
            }
            
            var results: [LabelEntity] = []
            for await entity in group {
                results.append(entity)
            }
            return results
        }
    }
    
    func suggestedEntities() async throws -> [LabelEntity] {
        let context = BaseDataIntent.sharedContainer.mainContext
        let descriptor = FetchDescriptor<InventoryLabel>(
            sortBy: [SortDescriptor(\.name)]
        )
        let labels = try context.fetch(descriptor)
        
        return await withTaskGroup(of: LabelEntity.self) { group in
            for label in labels {
                group.addTask {
                    let itemCount = await getItemCount(for: label, context: context)
                    return LabelEntity(from: label, itemCount: itemCount)
                }
            }
            
            var results: [LabelEntity] = []
            for await entity in group {
                results.append(entity)
            }
            return results
        }
    }
    
    private func getLabels(context: ModelContext, identifiers: [String]) async throws -> [InventoryLabel] {
        var labels: [InventoryLabel] = []
        for identifier in identifiers {
            guard let url = URL(string: identifier),
                  let modelID = context.model.persistentModelID(for: url) else { continue }
            if let label = context.model.registeredModel(for: modelID) as? InventoryLabel {
                labels.append(label)
            }
        }
        return labels
    }
    
    private func getItemCount(for label: InventoryLabel, context: ModelContext) async -> Int {
        let predicate = #Predicate<InventoryItem> { item in
            item.label?.name == label.name
        }
        let descriptor = FetchDescriptor<InventoryItem>(predicate: predicate)
        return (try? context.fetch(descriptor).count) ?? 0
    }
}

// MARK: - Common Input Parameters

/// Parameter for text-based item descriptions
@available(iOS 16.0, *)
struct ItemDescriptionParameter: Codable, Hashable, Sendable {
    let description: String
    
    init(description: String) {
        self.description = description
    }
}

/// Parameter for photo inputs
@available(iOS 16.0, *)
struct PhotoInputParameter: Codable, Hashable, Sendable {
    let imageData: Data
    
    init(imageData: Data) {
        self.imageData = imageData
    }
}

/// Parameter for field updates
@available(iOS 16.0, *)
enum ItemField: String, AppEnum, CaseIterable, Sendable {
    case title = "title"
    case quantity = "quantity"
    case description = "description"
    case serial = "serial"
    case model = "model"
    case make = "make"
    case price = "price"
    case insured = "insured"
    case notes = "notes"
    
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Item Field"
    
    static let caseDisplayRepresentations: [ItemField: DisplayRepresentation] = [
        .title: "Title",
        .quantity: "Quantity", 
        .description: "Description",
        .serial: "Serial Number",
        .model: "Model",
        .make: "Make/Brand",
        .price: "Price",
        .insured: "Insured",
        .notes: "Notes"
    ]
}