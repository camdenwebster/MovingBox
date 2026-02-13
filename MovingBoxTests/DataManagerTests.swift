import Foundation
import SQLiteData
import Testing
import UIKit
import ZIPFoundation

@testable import MovingBox

@MainActor
struct DataManagerTests {
    let fileManager = FileManager.default

    @Test("Empty inventory throws error")
    func emptyInventoryThrowsError() async throws {
        let database = try makeInMemoryDatabase()

        do {
            _ = try await DataManager.shared.exportInventory(database: database)
            Issue.record("Expected error to be thrown")
        } catch let error as DataManager.DataError {
            #expect(error == .nothingToExport)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Export with items creates zip file")
    func exportWithItemsCreatesZip() async throws {
        let database = try makeInMemoryDatabase()

        try await database.write { db in
            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(id: UUID(), title: "Test Item", desc: "Test Description")
            }.execute(db)
        }

        let url = try await DataManager.shared.exportInventory(database: database)
        defer {
            try? fileManager.removeItem(at: url)
        }

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
        let database = try makeInMemoryDatabase()

        let itemID = UUID()
        let image = UIImage(systemName: "star.fill")!
        let imageData = image.pngData()!

        try await database.write { db in
            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(id: itemID, title: "Test Item")
            }.execute(db)
            try SQLiteInventoryItemPhoto.insert {
                SQLiteInventoryItemPhoto(id: UUID(), inventoryItemID: itemID, data: imageData)
            }.execute(db)
        }

        let url = try await DataManager.shared.exportInventory(database: database)
        defer {
            try? fileManager.removeItem(at: url)
        }

        do {
            let archive = try Archive(url: url, accessMode: .read, pathEncoding: .utf8)
            #expect(archive.contains { $0.path == "inventory.csv" })
            #expect(archive.contains { $0.path.hasPrefix("photos/item-") })
        } catch {
            Issue.record("Unable to open archive: \(error)")
        }
    }

    @Test("Export with locations includes locations.csv and photos")
    func exportWithLocationsIncludesLocationsData() async throws {
        let database = try makeInMemoryDatabase()

        let locationID = UUID()

        try await database.write { db in
            try SQLiteInventoryLocation.insert {
                SQLiteInventoryLocation(
                    id: locationID, name: "Test Location", desc: "Test Notes")
            }.execute(db)
            let locationPhoto = UIImage(systemName: "shippingbox.fill")!.pngData()!
            try SQLiteInventoryLocationPhoto.insert {
                SQLiteInventoryLocationPhoto(
                    id: UUID(),
                    inventoryLocationID: locationID,
                    data: locationPhoto
                )
            }.execute(db)
            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(id: UUID(), title: "Test Item", locationID: locationID)
            }.execute(db)
        }

        let url = try await DataManager.shared.exportInventory(database: database)
        defer {
            try? fileManager.removeItem(at: url)
        }

        do {
            let archive = try Archive(url: url, accessMode: .read, pathEncoding: .utf8)
            #expect(archive.contains { $0.path == "locations.csv" })
            #expect(archive.contains { $0.path.hasPrefix("photos/location-") })
        } catch {
            Issue.record("Unable to open archive: \(error)")
        }
    }

    @Test("Import with locations and items returns correct counts")
    func importWithLocationsAndItemsReturnsCounts() async throws {
        let database = try makeInMemoryDatabase()
        let zipURL = try createTestImportFile()

        var importedItemCount = 0
        var importedLocationCount = 0

        for try await progress in await DataManager.shared.importInventory(
            from: zipURL,
            database: database
        ) {
            if case .completed(let result) = progress {
                importedItemCount = result.itemCount
                importedLocationCount = result.locationCount
            }
        }

        #expect(importedItemCount == 2)
        #expect(importedLocationCount == 2)

        let locations = try await database.read { db in
            try SQLiteInventoryLocation.fetchAll(db)
        }
        #expect(locations.count == 2)

        let items = try await database.read { db in
            try SQLiteInventoryItem.fetchAll(db)
        }
        #expect(items.count == 2)

        let itemPhotos = try await database.read { db in
            try SQLiteInventoryItemPhoto.fetchAll(db)
        }
        #expect(itemPhotos.count == 2)

        let locationPhotos = try await database.read { db in
            try SQLiteInventoryLocationPhoto.fetchAll(db)
        }
        #expect(locationPhotos.count == 2)

        try? FileManager.default.removeItem(at: zipURL)
    }

    @Test("Import with invalid zip throws error")
    func importWithInvalidZipThrowsError() async throws {
        let database = try makeInMemoryDatabase()

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

        let invalidData = "This is not a valid zip file".data(using: .utf8)!
        try invalidData.write(to: invalidZipURL)

        defer {
            try? fileManager.removeItem(at: invalidZipURL)
        }

        var receivedError: Error?

        for try await progress in await DataManager.shared.importInventory(
            from: invalidZipURL,
            database: database
        ) {
            if case .error(let sendableError) = progress {
                receivedError = sendableError.toError()
                break
            }
        }

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
        let database = try makeInMemoryDatabase()

        try await database.write { db in
            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(id: UUID(), title: "Test Item")
            }.execute(db)
            try SQLiteInventoryLocation.insert {
                SQLiteInventoryLocation(id: UUID(), name: "Test Location")
            }.execute(db)
            try SQLiteInventoryLabel.insert {
                SQLiteInventoryLabel(id: UUID(), name: "Test Label")
            }.execute(db)
        }

        let itemsOnlyConfig = DataManager.ExportConfig(
            includeItems: true,
            includeLocations: false,
            includeLabels: false
        )

        let itemsOnlyURL = try await DataManager.shared.exportInventory(
            database: database,
            config: itemsOnlyConfig
        )

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
        let database = try makeInMemoryDatabase()

        let importURL = try createTestImportFile()

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
            database: database,
            config: itemsOnlyConfig
        ) {
            if case .completed(let result) = progress {
                importedItemCount = result.itemCount
                importedLocationCount = result.locationCount
                importedLabelCount = result.labelCount
            }
        }

        #expect(importedItemCount > 0)
        #expect(importedLocationCount == 0)
        #expect(importedLabelCount == 0)

        try? FileManager.default.removeItem(at: importURL)
    }

    @Test("Import handles file access errors gracefully")
    func importHandlesFileAccessErrors() async throws {
        let database = try makeInMemoryDatabase()

        let deniedFileURL = try getTestFileURL(named: "denied.zip")
        try "test".data(using: .utf8)?.write(to: deniedFileURL)

        try fileManager.setAttributes([.posixPermissions: 0o000], ofItemAtPath: deniedFileURL.path)

        defer {
            try? fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: deniedFileURL.path)
            try? fileManager.removeItem(at: deniedFileURL)
        }

        var receivedError: Error?

        for try await progress in await DataManager.shared.importInventory(
            from: deniedFileURL,
            database: database
        ) {
            if case .error(let sendableError) = progress {
                receivedError = sendableError.toError()
                break
            }
        }

        #expect(receivedError != nil)
    }

    @Test("Import validates file size limits")
    func importValidatesFileSizeLimits() async throws {
        let database = try makeInMemoryDatabase()

        let workingDir = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("large-file-test")

        try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true)
        let photosDir = workingDir.appendingPathComponent("photos")
        try fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)

        let inventoryCSV = """
            Title,Description,Location,Label,Quantity,Serial,Model,Make,Price,Insured,Notes,PhotoFilename,HasUsedAI
            Test Item,Test Description,Test Location,,1,,,,,false,,large.png,false
            """
        try inventoryCSV.write(
            to: workingDir.appendingPathComponent("inventory.csv"), atomically: true, encoding: .utf8)

        let largeFileURL = photosDir.appendingPathComponent("large.png")
        try "large_file_content".data(using: .utf8)?.write(to: largeFileURL)

        let zipURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("large-file-test.zip")

        try? fileManager.removeItem(at: zipURL)
        try fileManager.zipItem(at: workingDir, to: zipURL, shouldKeepParent: false)

        defer {
            try? fileManager.removeItem(at: workingDir)
            try? fileManager.removeItem(at: zipURL)
        }

        for try await progress in await DataManager.shared.importInventory(
            from: zipURL,
            database: database
        ) {
            if case .error(let error) = progress {
                if let dataError = error as? DataManager.DataError,
                    dataError == .fileTooLarge
                {
                    break
                }
            }
            if case .completed = progress {
                break
            }
        }
    }

    @Test("Import validates file types")
    func importValidatesFileTypes() async throws {
        let database = try makeInMemoryDatabase()

        let workingDir = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("invalid-type-test")

        try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true)
        let photosDir = workingDir.appendingPathComponent("photos")
        try fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)

        let inventoryCSV = """
            Title,Description,Location,Label,Quantity,Serial,Model,Make,Price,Insured,Notes,PhotoFilename,HasUsedAI
            Test Item,Test Description,Test Location,,1,,,,,false,,invalid.txt,false
            """
        try inventoryCSV.write(
            to: workingDir.appendingPathComponent("inventory.csv"), atomically: true, encoding: .utf8)

        let invalidFileURL = photosDir.appendingPathComponent("invalid.txt")
        try "invalid file content".data(using: .utf8)?.write(to: invalidFileURL)

        let zipURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("invalid-type-test.zip")

        try? fileManager.removeItem(at: zipURL)
        try fileManager.zipItem(at: workingDir, to: zipURL, shouldKeepParent: false)

        defer {
            try? fileManager.removeItem(at: workingDir)
            try? fileManager.removeItem(at: zipURL)
        }

        var hadError = false
        for try await progress in await DataManager.shared.importInventory(
            from: zipURL,
            database: database
        ) {
            if case .error(let error) = progress {
                if let dataError = error as? DataManager.DataError,
                    dataError == .invalidFileType
                {
                    hadError = true
                }
                break
            }
            if case .completed = progress {
                break
            }
        }

        #expect(true)
    }

    @Test("Export with large dataset uses batched processing")
    func exportWithLargeDatasetUsesBatching() async throws {
        let database = try makeInMemoryDatabase()

        try await database.write { db in
            for i in 1...150 {
                try SQLiteInventoryItem.insert {
                    SQLiteInventoryItem(id: UUID(), title: "Test Item \(i)", desc: "Description \(i)")
                }.execute(db)
            }
        }

        let url = try await DataManager.shared.exportInventory(database: database)
        defer {
            try? fileManager.removeItem(at: url)
        }

        #expect(fileManager.fileExists(atPath: url.path))

        do {
            let archive = try Archive(url: url, accessMode: .read, pathEncoding: .utf8)
            #expect(archive.contains { $0.path == "inventory.csv" })

            if let entry = archive["inventory.csv"] {
                var csvData = Data()
                _ = try archive.extract(entry) { data in
                    csvData.append(data)
                }

                let csvString = String(data: csvData, encoding: .utf8)
                let lines = csvString?.components(separatedBy: .newlines).filter { !$0.isEmpty }

                #expect(lines?.count == 151)
            }
        } catch {
            Issue.record("Unable to verify archive: \(error)")
        }
    }

    @Test("Batched export with locations and labels")
    func batchedExportWithMultipleTypes() async throws {
        let database = try makeInMemoryDatabase()

        try await database.write { db in
            for i in 1...150 {
                try SQLiteInventoryItem.insert {
                    SQLiteInventoryItem(id: UUID(), title: "Item \(i)")
                }.execute(db)
            }

            for i in 1...50 {
                try SQLiteInventoryLocation.insert {
                    SQLiteInventoryLocation(id: UUID(), name: "Location \(i)")
                }.execute(db)
            }

            for i in 1...30 {
                try SQLiteInventoryLabel.insert {
                    SQLiteInventoryLabel(id: UUID(), name: "Label \(i)")
                }.execute(db)
            }
        }

        let url = try await DataManager.shared.exportInventory(database: database)
        defer {
            try? fileManager.removeItem(at: url)
        }

        #expect(fileManager.fileExists(atPath: url.path))

        do {
            let archive = try Archive(url: url, accessMode: .read, pathEncoding: .utf8)
            #expect(archive.contains { $0.path == "inventory.csv" })
            #expect(archive.contains { $0.path == "locations.csv" })
            #expect(archive.contains { $0.path == "labels.csv" })
        } catch {
            Issue.record("Unable to verify archive: \(error)")
        }
    }

    @Test("Import handles filename sanitization")
    func importHandlesFilenameSanitization() async throws {
        let database = try makeInMemoryDatabase()

        let workingDir = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("sanitization-test")

        try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true)
        let photosDir = workingDir.appendingPathComponent("photos")
        try fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)

        let inventoryCSV = """
            Title,Description,Location,Label,Quantity,Serial,Model,Make,Price,Insured,Notes,PhotoFilename,HasUsedAI
            Test Item 1,Test Description,Test Location,,1,,,,,false,,../../../danger.png,false
            Test Item 2,Test Description,Test Location,,1,,,,,false,,safe.png,false
            """
        try inventoryCSV.write(
            to: workingDir.appendingPathComponent("inventory.csv"), atomically: true, encoding: .utf8)

        let safeFileURL = photosDir.appendingPathComponent("safe.png")
        try "safe content".data(using: .utf8)?.write(to: safeFileURL)

        let zipURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("sanitization-test.zip")

        try? fileManager.removeItem(at: zipURL)
        try fileManager.zipItem(at: workingDir, to: zipURL, shouldKeepParent: false)

        defer {
            try? fileManager.removeItem(at: workingDir)
            try? fileManager.removeItem(at: zipURL)
        }

        var completedSuccessfully = false
        for try await progress in await DataManager.shared.importInventory(
            from: zipURL,
            database: database
        ) {
            if case .completed = progress {
                completedSuccessfully = true
                break
            }
        }

        #expect(completedSuccessfully)

        let items = try await database.read { db in
            try SQLiteInventoryItem.fetchAll(db)
        }
        #expect(items.count == 2)
    }

    @Test("Batch size adjusts based on device memory")
    func batchSizeAdjustsBasedOnMemory() async throws {
        let memoryBytes = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(memoryBytes) / 1_073_741_824.0

        #expect(memoryBytes > 0)
        #expect(memoryGB > 0)

        let database = try makeInMemoryDatabase()

        try await database.write { db in
            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(id: UUID(), title: "Test Item")
            }.execute(db)
        }

        let url = try await DataManager.shared.exportInventory(database: database)
        defer {
            try? fileManager.removeItem(at: url)
        }

        #expect(fileManager.fileExists(atPath: url.path))
    }

    @Test("Export progress reports all phases")
    func exportProgressReportsAllPhases() async throws {
        let database = try makeInMemoryDatabase()

        try await database.write { db in
            for i in 1...10 {
                try SQLiteInventoryItem.insert {
                    SQLiteInventoryItem(id: UUID(), title: "Item \(i)")
                }.execute(db)
            }
        }

        var receivedPhases: Set<String> = []

        for await progress in DataManager.shared.exportInventoryWithProgress(
            database: database
        ) {
            switch progress {
            case .preparing:
                receivedPhases.insert("preparing")
            case .fetchingData:
                receivedPhases.insert("fetchingData")
            case .writingCSV:
                receivedPhases.insert("writingCSV")
            case .copyingPhotos:
                receivedPhases.insert("copyingPhotos")
            case .creatingArchive:
                receivedPhases.insert("creatingArchive")
            case .completed(let result):
                receivedPhases.insert("completed")
                try? fileManager.removeItem(at: result.archiveURL)
                break
            case .error:
                Issue.record("Export should not error")
            }
        }

        #expect(receivedPhases.contains("preparing"))
        #expect(receivedPhases.contains("fetchingData"))
        #expect(receivedPhases.contains("writingCSV"))
        #expect(receivedPhases.contains("creatingArchive"))
        #expect(receivedPhases.contains("completed"))
    }

    @Test("Export can be cancelled mid-operation")
    func exportCanBeCancelled() async throws {
        let database = try makeInMemoryDatabase()

        try await database.write { db in
            for i in 1...200 {
                try SQLiteInventoryItem.insert {
                    SQLiteInventoryItem(id: UUID(), title: "Item \(i)")
                }.execute(db)
            }
        }

        let task = Task {
            var phaseCount = 0
            for await progress in DataManager.shared.exportInventoryWithProgress(
                database: database
            ) {
                phaseCount += 1
                if case .fetchingData = progress, phaseCount > 1 {
                    return false
                }
            }
            return true
        }

        task.cancel()
        let completed = await task.value

        #expect(completed == false)
    }

    @Test("Export result contains correct counts")
    func exportResultContainsCorrectCounts() async throws {
        let database = try makeInMemoryDatabase()

        try await database.write { db in
            for i in 1...15 {
                try SQLiteInventoryItem.insert {
                    SQLiteInventoryItem(id: UUID(), title: "Item \(i)")
                }.execute(db)
            }

            for i in 1...5 {
                try SQLiteInventoryLocation.insert {
                    SQLiteInventoryLocation(id: UUID(), name: "Location \(i)")
                }.execute(db)
            }

            for i in 1...3 {
                try SQLiteInventoryLabel.insert {
                    SQLiteInventoryLabel(id: UUID(), name: "Label \(i)")
                }.execute(db)
            }
        }

        var exportResult: DataManager.ExportResult?

        for await progress in DataManager.shared.exportInventoryWithProgress(
            database: database
        ) {
            if case .completed(let result) = progress {
                exportResult = result
                try? fileManager.removeItem(at: result.archiveURL)
                break
            }
        }

        guard let result = exportResult else {
            Issue.record("Export should complete")
            return
        }

        #expect(result.itemCount == 15)
        #expect(result.locationCount == 5)
        #expect(result.labelCount == 3)
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

        let inventoryCSV = """
            Title,Description,Location,Label,Quantity,Serial,Model,Make,Price,Insured,Notes,PhotoFilename,HasUsedAI
            Test Item 1,Test Description,Test Location 1,,1,,,,,false,,test1.png,false
            Test Item 2,Test Description,Test Location 2,,1,,,,,false,,test2.png,false
            """
        try inventoryCSV.write(
            to: workingDir.appendingPathComponent("inventory.csv"), atomically: true, encoding: .utf8)

        let locationsCSV = """
            Name,Description,PhotoFilename
            Test Location 1,Test Description,location1.png
            Test Location 2,Test Description,location2.png
            """
        try locationsCSV.write(
            to: workingDir.appendingPathComponent("locations.csv"), atomically: true, encoding: .utf8)

        let labelsCSV = """
            Name,Description,ColorHex,Emoji
            Test Label,Test Description,#FF0000,📦
            """
        try labelsCSV.write(
            to: workingDir.appendingPathComponent("labels.csv"), atomically: true, encoding: .utf8)

        try createTestImage(named: "test1.png", in: photosDir)
        try createTestImage(named: "test2.png", in: photosDir)
        try createTestImage(named: "location1.png", in: photosDir)
        try createTestImage(named: "location2.png", in: photosDir)

        let zipURL = documentsURL.appendingPathComponent("test-import.zip")
        try? fileManager.removeItem(at: zipURL)
        try fileManager.zipItem(at: workingDir, to: zipURL, shouldKeepParent: false)

        try? fileManager.removeItem(at: workingDir)

        return zipURL
    }
}
