//
//  DataManagerTests.swift
//  MovingBoxTests
//
//  Created by Alex (AI) on 6/10/25.
//

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
    
    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: InventoryItem.self, configurations: config)
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
        await MainActor.run {
            item.title = "Test Item"
            item.desc = "Test Description"
        }
        context.insert(item)
        
        // When
        let url = try await DataManager.shared.exportInventory(modelContext: context)
        
        // Then
        #expect(FileManager.default.fileExists(atPath: url.path))
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
        // Create a test image and save it
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        let image = UIImage(systemName: "star.fill")!
        let imageData = image.pngData()!
        try imageData.write(to: tempURL)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let item = InventoryItem()
        await MainActor.run {
            item.title = "Test Item"
            item.imageURL = tempURL
        }
        context.insert(item)
        
        // When
        let url = try await DataManager.shared.exportInventory(modelContext: context)
        defer {
            try? FileManager.default.removeItem(at: url)
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
}
