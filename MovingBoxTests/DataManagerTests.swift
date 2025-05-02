import Testing
import Foundation
import SwiftData
import ZIPFoundation
import UIKit
@testable import MovingBox

@MainActor
struct DataManagerTests {
    var container: ModelContainer!
    var context: ModelContext!
    let fileManager = FileManager.default
    
    init() throws {
        let schema = Schema([InventoryItem.self, InventoryLocation.self, InventoryLabel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }
    
    @Test("Empty inventory throws error")
    func emptyInventoryThrowsError() async {
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
        let item = InventoryItem()
        item.title = "Test Item"
        item.desc = "Test Description"
        context.insert(item)
        
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
        let location = InventoryLocation(name: "Test Location")
        location.desc = "Test Notes"
        location.imageURL = try createTestImage(named: "location.png")
        context.insert(location)
        
        let item = InventoryItem()
        item.title = "Test Item"
        item.location = location
        context.insert(item)
        
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
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        // Create working directory
        let workingDir = documentsURL.appendingPathComponent("test-export-\(UUID().uuidString)")
        try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true)
        
        // Create photos directory inside working directory
        let photosDir = workingDir.appendingPathComponent("photos")
        try fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)
        
        // Create test images first
        let locationImagePath = photosDir.appendingPathComponent("location.png")
        let itemImagePath = photosDir.appendingPathComponent("item.png")
        try "test image data".data(using: .utf8)?.write(to: locationImagePath)
        try "test image data".data(using: .utf8)?.write(to: itemImagePath)
        
        // Verify images exist
        guard fileManager.fileExists(atPath: locationImagePath.path),
              fileManager.fileExists(atPath: itemImagePath.path) else {
            throw DataManager.DataError.photoNotFound
        }
        
        // Create CSV files
        let locationsCSVPath = workingDir.appendingPathComponent("locations.csv")
        let inventoryCSVPath = workingDir.appendingPathComponent("inventory.csv")
        
        let locationsCSV = """
        Name,Notes,PhotoFilename
        Test Location,Test Notes,location.png
        Second Location,More Notes,
        """
        try locationsCSV.write(to: locationsCSVPath, atomically: true, encoding: .utf8)
        
        let inventoryCSV = """
        Title,Description,Location,Label,Quantity,Serial,Model,Make,Price,Insured,Notes,PhotoFilename,HasUsedAI
        Test Item,Test Description,Test Location,,1,,,,,false,,item.png,false
        Second Item,Another Description,Second Location,,1,,,,,false,,,false
        """
        try inventoryCSV.write(to: inventoryCSVPath, atomically: true, encoding: .utf8)
        
        // Create zip file
        let zipURL = documentsURL.appendingPathComponent("test-import.zip")
        if fileManager.fileExists(atPath: zipURL.path) {
            try fileManager.removeItem(at: zipURL)
        }
        
        // Create archive and add files
        try fileManager.zipItem(at: workingDir, to: zipURL, shouldKeepParent: false)
        
        defer {
            try? fileManager.removeItem(at: workingDir)
            try? fileManager.removeItem(at: zipURL)
        }
        
        // Verify zip exists
        guard fileManager.fileExists(atPath: zipURL.path) else {
            throw DataManager.DataError.failedCreateZip
        }
        
        // When
        let result = try await DataManager.shared.importInventory(from: zipURL, modelContext: context)
        
        // Then
        #expect(result.itemCount == 2)
        #expect(result.locationCount == 2)
        
        let locations = try context.fetch(FetchDescriptor<InventoryLocation>())
        #expect(locations.count == 2)
        
        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        #expect(items.count == 2)
    }
    
    @Test("Import with invalid zip throws error")
    func importWithInvalidZipThrowsError() async throws {
        // Create an invalid file
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
        
        // Attempt to import
        do {
            _ = try await DataManager.shared.importInventory(from: invalidZipURL, modelContext: context)
            Issue.record("Expected error to be thrown")
        } catch {
            // The exact error might vary depending on the ZIP implementation
            // but it should be treated as an invalid zip file by DataManager
            #expect(error is DataManager.DataError)
        }
    }
    
    // MARK: - Helpers
    
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
}
