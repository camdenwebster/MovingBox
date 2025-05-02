//
//  ExportManagerTests.swift
//  MovingBoxTests
//
//  Created by Alex (AI) on 6/10/25.
//

import XCTest
@testable import MovingBox
import SwiftData
import ZIPFoundation

@MainActor
final class ExportManagerTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: InventoryItem.self, Home.self, configurations: config)
        context = container.mainContext

        // Seed a home & item
        let home = Home(name: "Sample Home")
        context.insert(home)

        let item = InventoryItem()
        item.title = "Couch"
        item.desc = "Comfortable"
        item.location = nil
        context.insert(item)
    }

    func testExportCreatesZip() async throws {
        let url = try await ExportManager.shared.exportInventory(modelContext: context)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        // Inspect archive contains inventory.csv
        guard let archive = Archive(url: url, accessMode: .read) else {
            XCTFail("Unable to open archive"); return
        }
        XCTAssertNotNil(archive["inventory.csv"])
    }
}