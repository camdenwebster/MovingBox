import Foundation
import Testing

@testable import MovingBox

@Suite("SQLite Model CRUD")
struct SQLiteModelCRUDTests {

    // MARK: - Update Operations

    @Suite("Updates")
    struct UpdateTests {

        @Test("Update label fields")
        func updateLabel() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryLabel.insert(
                    SQLiteInventoryLabel(id: id, name: "Old", desc: "old desc", emoji: "📦")
                ).execute(db)
            }

            try db.write { db in
                try SQLiteInventoryLabel.find(id)
                    .update {
                        $0.name = "Updated"
                        $0.desc = "new desc"
                        $0.emoji = "🏠"
                    }
                    .execute(db)
            }

            let label = try db.read { db in
                try SQLiteInventoryLabel.find(id).fetchOne(db)
            }
            #expect(label?.name == "Updated")
            #expect(label?.desc == "new desc")
            #expect(label?.emoji == "🏠")
        }

        @Test("Update home fields")
        func updateHome() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteHome.insert(
                    SQLiteHome(id: id, name: "Old Home", city: "Austin", isPrimary: false)
                ).execute(db)
            }

            try db.write { db in
                try SQLiteHome.find(id)
                    .update {
                        $0.name = "New Home"
                        $0.city = "Denver"
                        $0.isPrimary = true
                    }
                    .execute(db)
            }

            let home = try db.read { db in
                try SQLiteHome.find(id).fetchOne(db)
            }
            #expect(home?.name == "New Home")
            #expect(home?.city == "Denver")
            #expect(home?.isPrimary == true)
        }

        @Test("Update location fields")
        func updateLocation() throws {
            let db = try makeInMemoryDatabase()
            let homeID = UUID()
            let locationID = UUID()

            try db.write { db in
                try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Home")).execute(db)
                try SQLiteInventoryLocation.insert(
                    SQLiteInventoryLocation(
                        id: locationID, name: "Kitchen", desc: "Main kitchen", homeID: homeID)
                ).execute(db)
            }

            try db.write { db in
                try SQLiteInventoryLocation.find(locationID)
                    .update {
                        $0.name = "Living Room"
                        $0.desc = "Front living room"
                        $0.sfSymbolName = "sofa"
                    }
                    .execute(db)
            }

            let location = try db.read { db in
                try SQLiteInventoryLocation.find(locationID).fetchOne(db)
            }
            #expect(location?.name == "Living Room")
            #expect(location?.desc == "Front living room")
            #expect(location?.sfSymbolName == "sofa")
        }

        @Test("Update item fields")
        func updateItem() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "Old TV", price: Decimal(string: "500.00")!)
                ).execute(db)
            }

            try db.write { db in
                try SQLiteInventoryItem.find(id)
                    .update {
                        $0.title = "New TV"
                        $0.price = Decimal(string: "999.99")!
                        $0.make = "Samsung"
                        $0.isFragile = true
                        $0.insured = true
                    }
                    .execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item?.title == "New TV")
            #expect(item?.price == Decimal(string: "999.99"))
            #expect(item?.make == "Samsung")
            #expect(item?.isFragile == true)
            #expect(item?.insured == true)
        }

        @Test("Update insurance policy coverage amounts")
        func updatePolicy() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInsurancePolicy.insert(
                    SQLiteInsurancePolicy(
                        id: id, providerName: "StateFarm",
                        deductibleAmount: Decimal(string: "1000.00")!)
                ).execute(db)
            }

            try db.write { db in
                try SQLiteInsurancePolicy.find(id)
                    .update {
                        $0.deductibleAmount = Decimal(string: "2500.00")!
                        $0.dwellingCoverageAmount = Decimal(string: "350000.00")!
                        $0.policyNumber = "POL-12345"
                    }
                    .execute(db)
            }

            let policy = try db.read { db in
                try SQLiteInsurancePolicy.find(id).fetchOne(db)
            }
            #expect(policy?.deductibleAmount == Decimal(string: "2500.00"))
            #expect(policy?.dwellingCoverageAmount == Decimal(string: "350000.00"))
            #expect(policy?.policyNumber == "POL-12345")
        }
    }

    // MARK: - Delete Operations

    @Suite("Deletes")
    struct DeleteTests {

        @Test("Delete a label")
        func deleteLabel() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryLabel.insert(
                    SQLiteInventoryLabel(id: id, name: "ToDelete")
                ).execute(db)
            }

            try db.write { db in
                try SQLiteInventoryLabel.find(id).delete().execute(db)
            }

            let label = try db.read { db in
                try SQLiteInventoryLabel.find(id).fetchOne(db)
            }
            #expect(label == nil)
        }

        @Test("Delete a location")
        func deleteLocation() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryLocation.insert(
                    SQLiteInventoryLocation(id: id, name: "Room")
                ).execute(db)
            }

            try db.write { db in
                try SQLiteInventoryLocation.find(id).delete().execute(db)
            }

            let location = try db.read { db in
                try SQLiteInventoryLocation.find(id).fetchOne(db)
            }
            #expect(location == nil)
        }

        @Test("Delete an item")
        func deleteItem() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "ToDelete")
                ).execute(db)
            }

            try db.write { db in
                try SQLiteInventoryItem.find(id).delete().execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item == nil)
        }

        @Test("Delete an insurance policy")
        func deletePolicy() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInsurancePolicy.insert(
                    SQLiteInsurancePolicy(id: id, providerName: "ToDelete")
                ).execute(db)
            }

            try db.write { db in
                try SQLiteInsurancePolicy.find(id).delete().execute(db)
            }

            let policy = try db.read { db in
                try SQLiteInsurancePolicy.find(id).fetchOne(db)
            }
            #expect(policy == nil)
        }
    }

    // MARK: - Default Values

    @Suite("Default Values")
    struct DefaultValueTests {

        @Test("Item has correct defaults when inserted with minimal fields")
        func itemDefaults() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: id, title: "Minimal")
                ).execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(id).fetchOne(db)
            }
            #expect(item != nil)
            #expect(item?.title == "Minimal")
            #expect(item?.quantityString == "1")
            #expect(item?.quantityInt == 1)
            #expect(item?.price == 0)
            #expect(item?.insured == false)
            #expect(item?.hasUsedAI == false)
            #expect(item?.hasWarranty == false)
            #expect(item?.isFragile == false)
            #expect(item?.movingPriority == 3)
            #expect(item?.dimensionUnit == "inches")
            #expect(item?.weightUnit == "lbs")
            #expect(item?.attachments == [])
            #expect(item?.locationID == nil)
            #expect(item?.homeID == nil)
            #expect(item?.replacementCost == nil)
            #expect(item?.depreciationRate == nil)
        }

        @Test("Home has correct defaults when inserted with minimal fields")
        func homeDefaults() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteHome.insert(SQLiteHome(id: id)).execute(db)
            }

            let home = try db.read { db in
                try SQLiteHome.find(id).fetchOne(db)
            }
            #expect(home != nil)
            #expect(home?.name == "")
            #expect(home?.address1 == "")
            #expect(home?.city == "")
            #expect(home?.isPrimary == false)
            #expect(home?.colorName == "green")
            #expect(home?.purchasePrice == 0)
        }

        @Test("Label has correct defaults when inserted with minimal fields")
        func labelDefaults() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryLabel.insert(SQLiteInventoryLabel(id: id)).execute(db)
            }

            let label = try db.read { db in
                try SQLiteInventoryLabel.find(id).fetchOne(db)
            }
            #expect(label != nil)
            #expect(label?.name == "")
            #expect(label?.desc == "")
            #expect(label?.emoji == "🏷️")
            #expect(label?.color == nil)
        }

        @Test("Location has correct defaults when inserted with minimal fields")
        func locationDefaults() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInventoryLocation.insert(SQLiteInventoryLocation(id: id)).execute(db)
            }

            let location = try db.read { db in
                try SQLiteInventoryLocation.find(id).fetchOne(db)
            }
            #expect(location != nil)
            #expect(location?.name == "")
            #expect(location?.desc == "")
            #expect(location?.sfSymbolName == nil)
            #expect(location?.homeID == nil)
        }

        @Test("Insurance policy has correct defaults when inserted with minimal fields")
        func policyDefaults() throws {
            let db = try makeInMemoryDatabase()
            let id = UUID()

            try db.write { db in
                try SQLiteInsurancePolicy.insert(SQLiteInsurancePolicy(id: id)).execute(db)
            }

            let policy = try db.read { db in
                try SQLiteInsurancePolicy.find(id).fetchOne(db)
            }
            #expect(policy != nil)
            #expect(policy?.providerName == "")
            #expect(policy?.policyNumber == "")
            #expect(policy?.deductibleAmount == 0)
            #expect(policy?.dwellingCoverageAmount == 0)
            #expect(policy?.personalPropertyCoverageAmount == 0)
            #expect(policy?.lossOfUseCoverageAmount == 0)
            #expect(policy?.liabilityCoverageAmount == 0)
            #expect(policy?.medicalPaymentsCoverageAmount == 0)
        }
    }
}
