import Testing
import Foundation
import SwiftData
import ZIPFoundation
import UIKit
@testable import MovingBox

@MainActor
struct DataManagerTests {
    func createContainer() throws -> ModelContainer {
        let schema = Schema([InventoryItem.self, InventoryLocation.self, InventoryLabel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
    
    func createContext(with container: ModelContainer) -> ModelContext {
        return ModelContext(container)
    }
    
    let fileManager = FileManager.default
    
    @Test("Empty inventory throws error")
    func emptyInventoryThrowsError() async throws {
        let container = try createContainer()
        let context = createContext(with: container)
        
        do {
            _ = try await DataManager.shared.exportInventory(modelContext: context)
            Issue.record("Expected error to be thrown")
        } catch let error as DataManager.DataError {
            #expect(error == .nothingToExport)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("Export with items creates zip file")
    func exportWithItemsCreatesZip() async throws {
        // Given
        let container = try createContainer()
        let context = createContext(with: container)
        
        let item = InventoryItem()
        item.title = "Test Item"
        item.desc = "Test Description"
        context.insert(item)
        try context.save()
        
        // When
        let url = try await DataManager.shared.exportInventory(modelContext: context)
        defer {
            try? fileManager.removeItem(at: url)
        }
        
        // Then
        #expect(fileManager.fileExists(atPath: url.path))
        #expect(url.lastPathComponent.hasPrefix("MovingBox-export"))
        #expect(url.lastPathComponent.hasSuffix(".zip"))
        
        do {
            let archive = try Archive(url: url, accessMode: .read, pathEncoding: .utf8)
            #expect(archive.contains { $0.path == "inventory.csv" })
        } catch {
            Issue.record("Unable to open archive: \(error)")
        }
    }
    
    @Test("Export with photos includes photos in zip")
    func exportWithPhotosIncludesPhotos() async throws {
        // Given
        let container = try createContainer()
        let context = createContext(with: container)
        
        let tempURL = try getTestFileURL(named: "test.png")
        let image = UIImage(systemName: "star.fill")!
        let imageData = image.pngData()!
        try imageData.write(to: tempURL)
        
        defer {
            try? fileManager.removeItem(at: tempURL)
        }
        
        let item = InventoryItem()
        item.title = "Test Item"
        item.imageURL = tempURL
        context.insert(item)
        try context.save()
        
        // When
        let url = try await DataManager.shared.exportInventory(modelContext: context)
        defer {
            try? fileManager.removeItem(at: url)
        }
        
        // Then
        do {
            let archive = try Archive(url: url, accessMode: .read, pathEncoding: .utf8)
            let hasPhotosFolder = archive.contains { $0.path.hasPrefix("photos/") }
            #expect(hasPhotosFolder)
        } catch {
            Issue.record("Unable to open archive: \(error)")
        }
    }
    
    @Test("Export with locations includes locations.csv and photos")
    func exportWithLocationsIncludesLocationsData() async throws {
        // Given
        let container = try createContainer()
        let context = createContext(with: container)
        
        let location = InventoryLocation(name: "Test Location")
        location.desc = "Test Notes"
        location.imageURL = try createTestImage(named: "location.png")
        context.insert(location)
        try context.save()
        
        let item = InventoryItem()
        item.title = "Test Item"
        item.location = location
        context.insert(item)
        try context.save()
        
        // When
        let url = try await DataManager.shared.exportInventory(modelContext: context)
        defer {
            try? fileManager.removeItem(at: url)
        }
        
        // Then
        do {
            let archive = try Archive(url: url, accessMode: .read, pathEncoding: .utf8)
            #expect(archive.contains { $0.path == "locations.csv" })
            #expect(archive.contains { $0.path.hasPrefix("photos/") })
        } catch {
            Issue.record("Unable to open archive: \(error)")
        }
    }
    
    @Test("Import with locations and items returns correct counts")
    func importWithLocationsAndItemsReturnsCounts() async throws {
        // Given
        let container = try createContainer()
        let context = createContext(with: container)
        let zipURL = try createTestImportFile()
        
        // When
        var importedItemCount = 0
        var importedLocationCount = 0
        
        for try await progress in await DataManager.shared.importInventory(
            from: zipURL,
            modelContext: context
        ) {
            if case .completed(let result) = progress {
                importedItemCount = result.itemCount
                importedLocationCount = result.locationCount
            }
        }
        
        // Then
        #expect(importedItemCount == 2)
        #expect(importedLocationCount == 2)
        
        let locations = try context.fetch(FetchDescriptor<InventoryLocation>())
        #expect(locations.count == 2)
        
        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        #expect(items.count == 2)
        
        // Cleanup
        try? FileManager.default.removeItem(at: zipURL)
    }
    
    @Test("Import with invalid zip throws error")
    func importWithInvalidZipThrowsError() async throws {
        // Given
        let container = try createContainer()
        let context = createContext(with: container)
        
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let invalidZipURL = documentsURL.appendingPathComponent("invalid.zip")
        if fileManager.fileExists(atPath: invalidZipURL.path) {
            try fileManager.removeItem(at: invalidZipURL)
        }
        
        // Write invalid zip data
        let invalidData = "This is not a valid zip file".data(using: .utf8)!
        try invalidData.write(to: invalidZipURL)
        
        defer {
            try? fileManager.removeItem(at: invalidZipURL)
        }
        
        // When
        var receivedError: Error?
        
        for try await progress in await DataManager.shared.importInventory(
            from: invalidZipURL,
            modelContext: context
        ) {
            if case .error(let error) = progress {
                receivedError = error
                break
            }
        }
        
        // Then
        guard let error = receivedError else {
            Issue.record("Expected error to be received")
            return
        }
        
        if let dataError = error as? DataManager.DataError {
            #expect(dataError == .invalidZipFile)
        } else if error is Archive.ArchiveError {
            #expect(true, "Received expected ZIPFoundation ArchiveError")
        } else {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test("Export respects configuration flags")
    func exportRespectsConfiguration() async throws {
        // Given
        let container = try createContainer()
        let context = createContext(with: container)
        
        let item = InventoryItem()
        item.title = "Test Item"
        context.insert(item)
        
        let location = InventoryLocation(name: "Test Location")
        context.insert(location)
        
        let label = InventoryLabel(name: "Test Label")
        context.insert(label)
        
        try context.save()
        
        // When exporting only items
        let itemsOnlyConfig = DataManager.ExportConfig(
            includeItems: true,
            includeLocations: false,
            includeLabels: false
        )
        
        let itemsOnlyURL = try await DataManager.shared.exportInventory(
            modelContext: context,
            config: itemsOnlyConfig
        )
        
        // Then
        do {
            let archive = try Archive(url: itemsOnlyURL, accessMode: .read, pathEncoding: .utf8)
            #expect(archive.contains { $0.path == "inventory.csv" })
            #expect(!archive.contains { $0.path == "locations.csv" })
            #expect(!archive.contains { $0.path == "labels.csv" })
        } catch {
            Issue.record("Unable to open archive: \(error)")
        }
        
        try? FileManager.default.removeItem(at: itemsOnlyURL)
    }
    
    @Test("Import respects configuration flags")
    func importRespectsConfiguration() async throws {
        // Given
        let container = try createContainer()
        let context = createContext(with: container)
        
        let importURL = try createTestImportFile()
        
        // When importing only items
        let itemsOnlyConfig = DataManager.ImportConfig(
            includeItems: true,
            includeLocations: false,
            includeLabels: false
        )
        
        var importedItemCount = 0
        var importedLocationCount = 0
        var importedLabelCount = 0
        
        for try await progress in await DataManager.shared.importInventory(
            from: importURL,
            modelContext: context,
            config: itemsOnlyConfig
        ) {
            if case .completed(let result) = progress {
                importedItemCount = result.itemCount
                importedLocationCount = result.locationCount
                importedLabelCount = result.labelCount
            }
        }
        
        // Then
        #expect(importedItemCount > 0)
        #expect(importedLocationCount == 0)
        #expect(importedLabelCount == 0)
        
        try? FileManager.default.removeItem(at: importURL)
    }
    
    // MARK: - Helper Methods
    
    private func getTestFileURL(named filename: String) throws -> URL {
        try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent(filename)
    }
    
    private func createTestImage(named filename: String) throws -> URL {
        let imageURL = try getTestFileURL(named: filename)
        try "test".data(using: .utf8)?.write(to: imageURL)
        return imageURL
    }
    
    private func createTestImage(named filename: String, in directory: URL) throws {
        let imageURL = directory.appendingPathComponent(filename)
        try "test".data(using: .utf8)?.write(to: imageURL)
    }
    
    private func createTestImportFile() throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let workingDir = documentsURL.appendingPathComponent("test-export-\(UUID().uuidString)")
        try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true)
        
        let photosDir = workingDir.appendingPathComponent("photos")
        try fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)
        
        // Create test CSVs
        let inventoryCSV = """
        Title,Description,Location,Label,Quantity,Serial,Model,Make,Price,Insured,Notes,PhotoFilename,HasUsedAI
        Test Item 1,Test Description,Test Location 1,,1,,,,,false,,test1.png,false
        Test Item 2,Test Description,Test Location 2,,1,,,,,false,,test2.png,false
        """
        try inventoryCSV.write(to: workingDir.appendingPathComponent("inventory.csv"), atomically: true, encoding: .utf8)
        
        let locationsCSV = """
        Name,Description,PhotoFilename
        Test Location 1,Test Description,location1.png
        Test Location 2,Test Description,location2.png
        """
        try locationsCSV.write(to: workingDir.appendingPathComponent("locations.csv"), atomically: true, encoding: .utf8)
        
        let labelsCSV = """
        Name,Description,ColorHex,Emoji
        Test Label,Test Description,#FF0000,📦
        """
        try labelsCSV.write(to: workingDir.appendingPathComponent("labels.csv"), atomically: true, encoding: .utf8)
        
        // Create dummy photo files
        try createTestImage(named: "test1.png", in: photosDir)
        try createTestImage(named: "test2.png", in: photosDir)
        try createTestImage(named: "location1.png", in: photosDir)
        try createTestImage(named: "location2.png", in: photosDir)
        
        // Create zip
        let zipURL = documentsURL.appendingPathComponent("test-import.zip")
        try? fileManager.removeItem(at: zipURL)
        try fileManager.zipItem(at: workingDir, to: zipURL, shouldKeepParent: false)
        
        try? fileManager.removeItem(at: workingDir)
        
        return zipURL
    }
}
