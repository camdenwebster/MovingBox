import Foundation
import GRDB
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

    @Test("Export includes home and insurance policy CSV files")
    func exportIncludesHomeAndInsurancePolicyCSVs() async throws {
        let database = try makeInMemoryDatabase()
        let homeID = UUID()
        let policyID = UUID()

        try await database.write { db in
            try SQLiteHome.insert {
                SQLiteHome(
                    id: homeID,
                    name: "Primary Home",
                    address1: "123 Main St",
                    city: "Nashville",
                    state: "TN",
                    zip: "37201",
                    country: "USA",
                    purchasePrice: Decimal(string: "420000")!,
                    isPrimary: true,
                    colorName: "blue"
                )
            }.execute(db)

            try SQLiteInsurancePolicy.insert {
                SQLiteInsurancePolicy(
                    id: policyID,
                    providerName: "Acme Insurance",
                    policyNumber: "HO-12345",
                    deductibleAmount: Decimal(string: "1500")!,
                    dwellingCoverageAmount: Decimal(string: "500000")!,
                    personalPropertyCoverageAmount: Decimal(string: "200000")!,
                    lossOfUseCoverageAmount: Decimal(string: "100000")!,
                    liabilityCoverageAmount: Decimal(string: "300000")!,
                    medicalPaymentsCoverageAmount: Decimal(string: "10000")!,
                    startDate: Date(timeIntervalSince1970: 1_700_000_000),
                    endDate: Date(timeIntervalSince1970: 1_731_536_000)
                )
            }.execute(db)

            try SQLiteHomeInsurancePolicy.insert {
                SQLiteHomeInsurancePolicy(
                    id: UUID(),
                    homeID: homeID,
                    insurancePolicyID: policyID
                )
            }.execute(db)
        }

        let archiveURL = try await DataManager.shared.exportInventory(
            database: database,
            fileName: uniqueArchiveName(prefix: "homes-export")
        )
        defer {
            try? fileManager.removeItem(at: archiveURL)
        }

        let archiveEntries = try archiveEntryPaths(in: archiveURL)
        #expect(archiveEntries.contains("home-details.csv"))
        #expect(archiveEntries.contains("insurance-policy-details.csv"))

        let homesRows = try csvRows(fromArchiveEntry: "home-details.csv", archiveURL: archiveURL)
        #expect(homesRows.count == 2)
        #expect(homesRows[0].contains("HomeID"))
        #expect(homesRows[1][0].lowercased() == homeID.uuidString.lowercased())
        #expect(homesRows[1][1] == "Primary Home")

        let policiesRows = try csvRows(
            fromArchiveEntry: "insurance-policy-details.csv",
            archiveURL: archiveURL
        )
        #expect(policiesRows.count == 2)
        #expect(policiesRows[0].contains("ProviderName"))
        #expect(policiesRows[1][1] == "Acme Insurance")
        #expect(policiesRows[1][2] == "HO-12345")
        #expect(policiesRows[1].joined(separator: ",").lowercased().contains(homeID.uuidString.lowercased()))
    }

    @Test("Export item CSV includes all inventory attributes and photo filename columns")
    func exportItemCSVIncludesAllAttributesAndPhotoColumns() async throws {
        let database = try makeInMemoryDatabase()

        let homeID = UUID()
        let locationID = UUID()
        let labelID = UUID()
        let itemID = UUID()
        let firstPhotoID = UUID()
        let secondPhotoID = UUID()
        let pngData = UIImage(systemName: "star.fill")!.pngData()!

        try await database.write { db in
            try SQLiteHome.insert {
                SQLiteHome(id: homeID, name: "North House")
            }.execute(db)

            try SQLiteInventoryLocation.insert {
                SQLiteInventoryLocation(
                    id: locationID,
                    name: "Garage",
                    desc: "Storage",
                    homeID: homeID
                )
            }.execute(db)

            try SQLiteInventoryLabel.insert {
                SQLiteInventoryLabel(id: labelID, name: "Electronics")
            }.execute(db)

            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(
                    id: itemID,
                    title: "Camera Kit",
                    quantityString: "2 units",
                    quantityInt: 2,
                    desc: "Mirrorless camera and lenses",
                    serial: "SER-001",
                    model: "X-T5",
                    make: "Fujifilm",
                    price: Decimal(string: "1699.99")!,
                    insured: true,
                    assetId: "ASSET-42",
                    notes: "Packed in hard case",
                    replacementCost: Decimal(string: "1900.50")!,
                    depreciationRate: 4.5,
                    hasUsedAI: true,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    purchaseDate: Date(timeIntervalSince1970: 1_680_000_000),
                    warrantyExpirationDate: Date(timeIntervalSince1970: 1_760_000_000),
                    purchaseLocation: "Downtown Camera",
                    condition: "Excellent",
                    hasWarranty: true,
                    attachments: [AttachmentInfo(url: "file:///manual.pdf", originalName: "manual.pdf")],
                    dimensionLength: "12",
                    dimensionWidth: "8",
                    dimensionHeight: "6",
                    dimensionUnit: "in",
                    weightValue: "4.5",
                    weightUnit: "lb",
                    color: "Black",
                    storageRequirements: "Dry",
                    isFragile: true,
                    movingPriority: 1,
                    roomDestination: "Office",
                    locationID: locationID
                )
            }.execute(db)

            try SQLiteInventoryItemLabel.insert {
                SQLiteInventoryItemLabel(
                    id: UUID(),
                    inventoryItemID: itemID,
                    inventoryLabelID: labelID
                )
            }.execute(db)

            try SQLiteInventoryItemPhoto.insert {
                SQLiteInventoryItemPhoto(
                    id: firstPhotoID,
                    inventoryItemID: itemID,
                    data: pngData,
                    sortOrder: 0
                )
            }.execute(db)

            try SQLiteInventoryItemPhoto.insert {
                SQLiteInventoryItemPhoto(
                    id: secondPhotoID,
                    inventoryItemID: itemID,
                    data: pngData,
                    sortOrder: 1
                )
            }.execute(db)
        }

        let archiveURL = try await DataManager.shared.exportInventory(
            database: database,
            fileName: uniqueArchiveName(prefix: "item-export")
        )
        defer {
            try? fileManager.removeItem(at: archiveURL)
        }

        let rows = try csvRows(fromArchiveEntry: "inventory.csv", archiveURL: archiveURL)
        #expect(rows.count == 2)

        let header = rows[0]
        let row = rows[1]
        let headerIndex = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1, $0) })

        let requiredHeaders = [
            "Title", "Description", "Location", "Label", "Home",
            "QuantityString", "QuantityInt", "Serial", "Model", "Make", "Price",
            "Insured", "AssetID", "Notes", "ReplacementCost", "DepreciationRate",
            "HasUsedAI", "CreatedAt", "PurchaseDate", "WarrantyExpirationDate",
            "PurchaseLocation", "Condition", "HasWarranty", "AttachmentsJSON",
            "DimensionLength", "DimensionWidth", "DimensionHeight", "DimensionUnit",
            "WeightValue", "WeightUnit", "Color", "StorageRequirements",
            "IsFragile", "MovingPriority", "RoomDestination",
            "ItemID", "LocationID", "HomeID", "PhotoFilename", "PhotoFilename2",
        ]
        for requiredHeader in requiredHeaders {
            #expect(header.contains(requiredHeader))
        }

        #expect(row[valueForHeader("Title", in: headerIndex)] == "Camera Kit")
        #expect(row[valueForHeader("Home", in: headerIndex)] == "North House")
        #expect(row[valueForHeader("Location", in: headerIndex)] == "Garage")
        #expect(row[valueForHeader("Label", in: headerIndex)] == "Electronics")
        #expect(row[valueForHeader("QuantityString", in: headerIndex)] == "2 units")
        #expect(row[valueForHeader("QuantityInt", in: headerIndex)] == "2")
        #expect(row[valueForHeader("Serial", in: headerIndex)] == "SER-001")
        #expect(row[valueForHeader("AssetID", in: headerIndex)] == "ASSET-42")
        #expect(row[valueForHeader("HasWarranty", in: headerIndex)] == "true")
        #expect(row[valueForHeader("IsFragile", in: headerIndex)] == "true")
        #expect(row[valueForHeader("MovingPriority", in: headerIndex)] == "1")
        #expect(row[valueForHeader("ItemID", in: headerIndex)].lowercased() == itemID.uuidString.lowercased())
        #expect(
            row[valueForHeader("LocationID", in: headerIndex)].lowercased() == locationID.uuidString.lowercased())
        #expect(row[valueForHeader("HomeID", in: headerIndex)].lowercased() == homeID.uuidString.lowercased())

        let firstPhotoFilename = row[valueForHeader("PhotoFilename", in: headerIndex)]
        let secondPhotoFilename = row[valueForHeader("PhotoFilename2", in: headerIndex)]
        #expect(!firstPhotoFilename.isEmpty)
        #expect(!secondPhotoFilename.isEmpty)
        #expect(firstPhotoFilename != secondPhotoFilename)
    }

    @Test("Export filters CSV rows by selected home IDs")
    func exportFiltersRowsBySelectedHomeIDs() async throws {
        let database = try makeInMemoryDatabase()

        let includedHomeID = UUID()
        let excludedHomeID = UUID()
        let includedLocationID = UUID()
        let excludedLocationID = UUID()
        let includedPolicyID = UUID()
        let excludedPolicyID = UUID()
        let globalPolicyID = UUID()

        try await database.write { db in
            try SQLiteHome.insert {
                SQLiteHome(id: includedHomeID, name: "Included Home")
            }.execute(db)
            try SQLiteHome.insert {
                SQLiteHome(id: excludedHomeID, name: "Excluded Home")
            }.execute(db)

            try SQLiteInventoryLocation.insert {
                SQLiteInventoryLocation(
                    id: includedLocationID,
                    name: "Included Location",
                    homeID: includedHomeID
                )
            }.execute(db)
            try SQLiteInventoryLocation.insert {
                SQLiteInventoryLocation(
                    id: excludedLocationID,
                    name: "Excluded Location",
                    homeID: excludedHomeID
                )
            }.execute(db)

            // Item with no direct homeID should still resolve via location home.
            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(
                    id: UUID(),
                    title: "Included Item",
                    locationID: includedLocationID
                )
            }.execute(db)
            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(
                    id: UUID(),
                    title: "Excluded Item",
                    locationID: excludedLocationID
                )
            }.execute(db)

            try SQLiteInsurancePolicy.insert {
                SQLiteInsurancePolicy(id: includedPolicyID, providerName: "Included Policy")
            }.execute(db)
            try SQLiteInsurancePolicy.insert {
                SQLiteInsurancePolicy(id: excludedPolicyID, providerName: "Excluded Policy")
            }.execute(db)
            try SQLiteInsurancePolicy.insert {
                SQLiteInsurancePolicy(id: globalPolicyID, providerName: "Global Policy")
            }.execute(db)

            try SQLiteHomeInsurancePolicy.insert {
                SQLiteHomeInsurancePolicy(
                    id: UUID(),
                    homeID: includedHomeID,
                    insurancePolicyID: includedPolicyID
                )
            }.execute(db)
            try SQLiteHomeInsurancePolicy.insert {
                SQLiteHomeInsurancePolicy(
                    id: UUID(),
                    homeID: excludedHomeID,
                    insurancePolicyID: excludedPolicyID
                )
            }.execute(db)
        }

        let archiveURL = try await DataManager.shared.exportInventory(
            database: database,
            fileName: uniqueArchiveName(prefix: "filtered-export"),
            config: .init(includedHomeIDs: Set([includedHomeID]))
        )
        defer {
            try? fileManager.removeItem(at: archiveURL)
        }

        let inventoryRows = try csvRows(fromArchiveEntry: "inventory.csv", archiveURL: archiveURL)
        #expect(inventoryRows.count == 2)
        #expect(inventoryRows[1].joined(separator: ",").contains("Included Item"))
        #expect(!inventoryRows[1].joined(separator: ",").contains("Excluded Item"))

        let locationRows = try csvRows(fromArchiveEntry: "locations.csv", archiveURL: archiveURL)
        #expect(locationRows.count == 2)
        #expect(locationRows[1].joined(separator: ",").contains("Included Location"))
        #expect(!locationRows[1].joined(separator: ",").contains("Excluded Location"))

        let homeRows = try csvRows(fromArchiveEntry: "home-details.csv", archiveURL: archiveURL)
        #expect(homeRows.count == 2)
        #expect(homeRows[1].joined(separator: ",").contains("Included Home"))
        #expect(!homeRows[1].joined(separator: ",").contains("Excluded Home"))

        let policyRows = try csvRows(
            fromArchiveEntry: "insurance-policy-details.csv",
            archiveURL: archiveURL
        )
        #expect(policyRows.count == 3)
        let policyText = policyRows.dropFirst().map { $0.joined(separator: ",") }.joined(separator: "\n")
        #expect(policyText.contains("Included Policy"))
        #expect(policyText.contains("Global Policy"))
        #expect(!policyText.contains("Excluded Policy"))
    }

    @Test("Export excludes photo files when photos are disabled")
    func exportExcludesPhotoFilesWhenPhotosDisabled() async throws {
        let database = try makeInMemoryDatabase()
        let itemID = UUID()
        let pngData = UIImage(systemName: "star.fill")!.pngData()!

        try await database.write { db in
            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(id: itemID, title: "Photo Item")
            }.execute(db)
            try SQLiteInventoryItemPhoto.insert {
                SQLiteInventoryItemPhoto(id: UUID(), inventoryItemID: itemID, data: pngData)
            }.execute(db)
        }

        let archiveURL = try await DataManager.shared.exportInventory(
            database: database,
            fileName: uniqueArchiveName(prefix: "no-photos-export"),
            config: .init(includePhotos: false)
        )
        defer {
            try? fileManager.removeItem(at: archiveURL)
        }

        let archiveEntries = try archiveEntryPaths(in: archiveURL)
        #expect(!archiveEntries.contains { $0.hasPrefix("photos/") })

        let inventoryRows = try csvRows(fromArchiveEntry: "inventory.csv", archiveURL: archiveURL)
        let headerIndex = Dictionary(uniqueKeysWithValues: inventoryRows[0].enumerated().map { ($1, $0) })
        let photoFilename = inventoryRows[1][valueForHeader("PhotoFilename", in: headerIndex)]
        #expect(!photoFilename.isEmpty)
    }

    @Test("Import supports multiple photo filename columns")
    func importSupportsMultiplePhotoFilenameColumns() async throws {
        let database = try makeInMemoryDatabase()
        let zipURL = try createMultiPhotoImportFile()
        defer {
            try? fileManager.removeItem(at: zipURL)
        }

        var importResult: DataManager.ImportResult?
        for try await progress in await DataManager.shared.importInventory(
            from: zipURL,
            database: database
        ) {
            if case .completed(let result) = progress {
                importResult = result
            }
        }

        #expect(importResult?.itemCount == 1)

        let itemPhotos = try await database.read { db in
            try SQLiteInventoryItemPhoto.order(by: \.sortOrder).fetchAll(db)
        }
        #expect(itemPhotos.count == 2)
        #expect(itemPhotos.map(\.sortOrder) == [0, 1])
    }

    @Test("Database archive export throws for in-memory database")
    func databaseArchiveExportThrowsForInMemoryDatabase() async throws {
        let database = try makeInMemoryDatabase()

        do {
            _ = try await DataManager.shared.exportDatabaseArchive(database: database)
            Issue.record("Expected containerNotConfigured error")
        } catch let error as DataManager.DataError {
            #expect(error == .containerNotConfigured)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Database archive export includes sqlite file for persistent database")
    func databaseArchiveExportIncludesSQLiteFileForPersistentDatabase() async throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("movingbox-export-test-\(UUID().uuidString).sqlite")
        let database = try makePersistentDatabase(at: dbURL)

        try await database.write { db in
            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(id: UUID(), title: "Persisted Item")
            }.execute(db)
        }

        let archiveURL = try await DataManager.shared.exportDatabaseArchive(
            database: database,
            fileName: uniqueArchiveName(prefix: "database-export")
        )
        defer {
            try? fileManager.removeItem(at: archiveURL)
            try? removeSQLiteSidecars(at: dbURL)
        }

        let archiveEntries = try archiveEntryPaths(in: archiveURL)
        #expect(archiveEntries.contains(dbURL.lastPathComponent))
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

        let zipURL = documentsURL.appendingPathComponent("test-import-\(UUID().uuidString).zip")
        try? fileManager.removeItem(at: zipURL)
        try fileManager.zipItem(at: workingDir, to: zipURL, shouldKeepParent: false)

        try? fileManager.removeItem(at: workingDir)

        return zipURL
    }

    private func createMultiPhotoImportFile() throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let workingDir = documentsURL.appendingPathComponent("test-multi-photo-import-\(UUID().uuidString)")
        try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true)
        let photosDir = workingDir.appendingPathComponent("photos")
        try fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)

        let inventoryCSV = """
            Title,Description,Location,Label,PhotoFilename,PhotoFilename2
            Multi Photo Item,Has two photos,,,photo-1.png,photo-2.png
            """
        try inventoryCSV.write(
            to: workingDir.appendingPathComponent("inventory.csv"),
            atomically: true,
            encoding: .utf8
        )

        try createTestImage(named: "photo-1.png", in: photosDir)
        try createTestImage(named: "photo-2.png", in: photosDir)

        let zipURL = documentsURL.appendingPathComponent("test-multi-photo-import-\(UUID().uuidString).zip")
        try? fileManager.removeItem(at: zipURL)
        try fileManager.zipItem(at: workingDir, to: zipURL, shouldKeepParent: false)
        try? fileManager.removeItem(at: workingDir)

        return zipURL
    }

    private func makePersistentDatabase(at url: URL) throws -> DatabaseQueue {
        try? fileManager.removeItem(at: url)

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.prepareDatabase { db in
            attachMetadatabaseIfPossible(to: db)
        }

        let database = try DatabaseQueue(path: url.path, configuration: configuration)
        var migrator = DatabaseMigrator()
        registerMigrations(&migrator)
        try migrator.migrate(database)
        return database
    }

    private func removeSQLiteSidecars(at baseURL: URL) throws {
        let sqliteFiles = [
            baseURL,
            URL(fileURLWithPath: baseURL.path + "-wal"),
            URL(fileURLWithPath: baseURL.path + "-shm"),
        ]

        for fileURL in sqliteFiles where fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    private func archiveEntryPaths(in archiveURL: URL) throws -> [String] {
        let archive = try Archive(url: archiveURL, accessMode: .read, pathEncoding: .utf8)
        return archive.map(\.path)
    }

    private func csvRows(fromArchiveEntry entryPath: String, archiveURL: URL) throws -> [[String]] {
        let csvText = try archiveEntryText(named: entryPath, archiveURL: archiveURL)
        let lines = csvText.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.map(parseCSVRow)
    }

    private func archiveEntryText(named entryPath: String, archiveURL: URL) throws -> String {
        let archive = try Archive(url: archiveURL, accessMode: .read, pathEncoding: .utf8)
        guard let entry = archive[entryPath] else {
            throw NSError(
                domain: "DataManagerTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Archive entry missing: \(entryPath)"]
            )
        }

        var entryData = Data()
        _ = try archive.extract(entry) { data in
            entryData.append(data)
        }

        guard let text = String(data: entryData, encoding: .utf8) else {
            throw NSError(
                domain: "DataManagerTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 for entry: \(entryPath)"]
            )
        }
        return text
    }

    private func parseCSVRow(_ row: String) -> [String] {
        var values: [String] = []
        var currentValue = ""
        var insideQuotes = false
        var index = row.startIndex

        while index < row.endIndex {
            let character = row[index]

            if character == "\"" {
                let nextIndex = row.index(after: index)
                if insideQuotes, nextIndex < row.endIndex, row[nextIndex] == "\"" {
                    currentValue.append("\"")
                    index = row.index(after: nextIndex)
                    continue
                }
                insideQuotes.toggle()
            } else if character == "," && !insideQuotes {
                values.append(currentValue)
                currentValue = ""
            } else {
                currentValue.append(character)
            }

            index = row.index(after: index)
        }

        values.append(currentValue)
        return values
    }

    private func valueForHeader(_ header: String, in index: [String: Int]) -> Int {
        guard let value = index[header] else {
            Issue.record("Missing expected header: \(header)")
            return 0
        }
        return value
    }

    private func uniqueArchiveName(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString).zip"
    }
}
