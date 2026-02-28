import Foundation
import Testing

@testable import MovingBox

@Suite("SQLite Schema & CRUD")
struct SQLiteSchemaTests {

    // MARK: - Label CRUD

    @Test("Insert and fetch a label")
    func labelCRUD() throws {
        let db = try makeInMemoryDatabase()
        let id = UUID()
        let householdID = UUID()

        try db.write { db in
            try SQLiteHousehold.insert(
                SQLiteHousehold(id: householdID, name: "Household")
            ).execute(db)
            try SQLiteInventoryLabel.insert(
                SQLiteInventoryLabel(
                    id: id,
                    householdID: householdID,
                    name: "Electronics",
                    emoji: "💻"
                )
            ).execute(db)
        }

        let fetched = try db.read { db in
            try SQLiteInventoryLabel.find(id).fetchOne(db)
        }
        #expect(fetched != nil)
        #expect(fetched?.name == "Electronics")
        #expect(fetched?.emoji == "💻")
        #expect(fetched?.householdID == householdID)
    }

    // MARK: - Home CRUD

    @Test("Insert and fetch a home")
    func homeCRUD() throws {
        let db = try makeInMemoryDatabase()
        let id = UUID()

        try db.write { db in
            try SQLiteHome.insert(
                SQLiteHome(
                    id: id,
                    name: "Main House",
                    city: "Austin",
                    state: "TX",
                    isPrimary: true
                )
            ).execute(db)
        }

        let fetched = try db.read { db in
            try SQLiteHome.find(id).fetchOne(db)
        }
        #expect(fetched != nil)
        #expect(fetched?.name == "Main House")
        #expect(fetched?.city == "Austin")
        #expect(fetched?.isPrimary == true)
    }

    // MARK: - Location with FK

    @Test("Location references home via FK")
    func locationHomeFK() throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()
        let locationID = UUID()

        try db.write { db in
            try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Home")).execute(db)
            try SQLiteInventoryLocation.insert(
                SQLiteInventoryLocation(id: locationID, name: "Kitchen", homeID: homeID)
            ).execute(db)
        }

        let location = try db.read { db in
            try SQLiteInventoryLocation.find(locationID).fetchOne(db)
        }
        #expect(location?.homeID == homeID)
    }

    // MARK: - Item with FKs

    @Test("Item references location and home")
    func itemForeignKeys() throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()
        let locationID = UUID()
        let itemID = UUID()

        try db.write { db in
            try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Home")).execute(db)
            try SQLiteInventoryLocation.insert(
                SQLiteInventoryLocation(id: locationID, name: "Garage", homeID: homeID)
            ).execute(db)
            try SQLiteInventoryItem.insert(
                SQLiteInventoryItem(
                    id: itemID,
                    title: "Bike",
                    price: Decimal(string: "499.99")!,
                    locationID: locationID,
                    homeID: homeID
                )
            ).execute(db)
        }

        let item = try db.read { db in
            try SQLiteInventoryItem.find(itemID).fetchOne(db)
        }
        #expect(item?.title == "Bike")
        #expect(item?.price == Decimal(string: "499.99"))
        #expect(item?.locationID == locationID)
        #expect(item?.homeID == homeID)
    }

    // MARK: - Join Table: Item-Label

    @Test("Item-Label join table with cascade delete")
    func itemLabelJoin() throws {
        let db = try makeInMemoryDatabase()
        let labelID = UUID()
        let itemID = UUID()

        try db.write { db in
            try SQLiteInventoryLabel.insert(SQLiteInventoryLabel(id: labelID, name: "Fragile"))
                .execute(db)
            try SQLiteInventoryItem.insert(SQLiteInventoryItem(id: itemID, title: "Vase"))
                .execute(db)
            try SQLiteInventoryItemLabel.insert(
                SQLiteInventoryItemLabel(
                    id: UUID(),
                    inventoryItemID: itemID,
                    inventoryLabelID: labelID
                )
            ).execute(db)
        }

        // Verify join row exists
        let joinCount = try db.read { db in
            try SQLiteInventoryItemLabel.count().fetchOne(db)
        }
        #expect(joinCount == 1)

        // Delete the item — join row should cascade-delete
        try db.write { db in
            try SQLiteInventoryItem.find(itemID).delete().execute(db)
        }
        let joinCountAfter = try db.read { db in
            try SQLiteInventoryItemLabel.count().fetchOne(db)
        }
        #expect(joinCountAfter == 0)
    }

    // MARK: - Join Table: Home-Policy

    @Test("Home-Policy join table with cascade delete")
    func homePolicyJoin() throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()
        let policyID = UUID()

        try db.write { db in
            try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Home")).execute(db)
            try SQLiteInsurancePolicy.insert(
                SQLiteInsurancePolicy(id: policyID, providerName: "StateFarm")
            ).execute(db)
            try SQLiteHomeInsurancePolicy.insert(
                SQLiteHomeInsurancePolicy(
                    id: UUID(),
                    homeID: homeID,
                    insurancePolicyID: policyID
                )
            ).execute(db)
        }

        let joinCount = try db.read { db in
            try SQLiteHomeInsurancePolicy.count().fetchOne(db)
        }
        #expect(joinCount == 1)

        // Delete the home — join row should cascade-delete
        try db.write { db in
            try SQLiteHome.find(homeID).delete().execute(db)
        }
        let joinCountAfter = try db.read { db in
            try SQLiteHomeInsurancePolicy.count().fetchOne(db)
        }
        #expect(joinCountAfter == 0)
    }

    // MARK: - ON DELETE SET NULL

    @Test("Deleting home sets location.homeID to NULL")
    func deleteHomeSetsLocationNull() throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()
        let locationID = UUID()

        try db.write { db in
            try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Home")).execute(db)
            try SQLiteInventoryLocation.insert(
                SQLiteInventoryLocation(id: locationID, name: "Room", homeID: homeID)
            ).execute(db)
        }

        // Delete home
        try db.write { db in
            try SQLiteHome.find(homeID).delete().execute(db)
        }

        let location = try db.read { db in
            try SQLiteInventoryLocation.find(locationID).fetchOne(db)
        }
        #expect(location != nil)
        #expect(location?.homeID == nil)
    }

    // MARK: - Insurance Policy

    @Test("Insurance policy stores all coverage amounts precisely")
    func insurancePolicyDecimals() throws {
        let db = try makeInMemoryDatabase()
        let id = UUID()
        let deductible = Decimal(string: "2500.00")!
        let dwelling = Decimal(string: "350000.00")!
        let personalProperty = Decimal(string: "175000.00")!

        try db.write { db in
            try SQLiteInsurancePolicy.insert(
                SQLiteInsurancePolicy(
                    id: id,
                    providerName: "Allstate",
                    deductibleAmount: deductible,
                    dwellingCoverageAmount: dwelling,
                    personalPropertyCoverageAmount: personalProperty
                )
            ).execute(db)
        }

        let policy = try db.read { db in
            try SQLiteInsurancePolicy.find(id).fetchOne(db)
        }
        #expect(policy?.deductibleAmount == deductible)
        #expect(policy?.dwellingCoverageAmount == dwelling)
        #expect(policy?.personalPropertyCoverageAmount == personalProperty)
    }

    // MARK: - Table Existence

    @Test("All expected tables are created")
    func allTablesExist() throws {
        let db = try makeInMemoryDatabase()
        let tables = try fetchTableNames(from: db)
        #expect(tables.contains("inventoryLabels"))
        #expect(tables.contains("homes"))
        #expect(tables.contains("insurancePolicies"))
        #expect(tables.contains("inventoryLocations"))
        #expect(tables.contains("inventoryItems"))
        #expect(tables.contains("inventoryItemLabels"))
        #expect(tables.contains("homeInsurancePolicies"))
        #expect(tables.contains("households"))
        #expect(tables.contains("householdMembers"))
        #expect(tables.contains("householdInvites"))
        #expect(tables.contains("homeAccessOverrides"))
    }

    @Test("Home access overrides enforce household-home-member uniqueness")
    func homeAccessOverrideUniqueConstraint() throws {
        let db = try makeInMemoryDatabase()
        let householdID = UUID()
        let homeID = UUID()
        let memberID = UUID()

        try db.write { db in
            try SQLiteHousehold.insert {
                SQLiteHousehold(id: householdID, name: "Household", sharingEnabled: true)
            }.execute(db)
            try SQLiteHome.insert {
                SQLiteHome(id: homeID, name: "Main", householdID: householdID)
            }.execute(db)
            try SQLiteHouseholdMember.insert {
                SQLiteHouseholdMember(
                    id: memberID,
                    householdID: householdID,
                    displayName: "Alex",
                    role: HouseholdMemberRole.member.rawValue
                )
            }.execute(db)

            try SQLiteHomeAccessOverride.insert {
                SQLiteHomeAccessOverride(
                    id: UUID(),
                    householdID: householdID,
                    homeID: homeID,
                    memberID: memberID,
                    decision: HomeAccessOverrideDecision.allow.rawValue
                )
            }.execute(db)
        }

        #expect(throws: Error.self) {
            try db.write { db in
                try SQLiteHomeAccessOverride.insert {
                    SQLiteHomeAccessOverride(
                        id: UUID(),
                        householdID: householdID,
                        homeID: homeID,
                        memberID: memberID,
                        decision: HomeAccessOverrideDecision.deny.rawValue
                    )
                }.execute(db)
            }
        }
    }

    // MARK: - FK Integrity

    @Test("Foreign key check passes after complex operations")
    func foreignKeyIntegrity() throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()
        let locationID = UUID()
        let itemID = UUID()
        let labelID = UUID()
        let policyID = UUID()

        try db.write { db in
            try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Test Home")).execute(db)
            try SQLiteInsurancePolicy.insert(
                SQLiteInsurancePolicy(id: policyID, providerName: "TestCo")
            ).execute(db)
            try SQLiteInventoryLabel.insert(
                SQLiteInventoryLabel(id: labelID, name: "TestLabel")
            ).execute(db)
            try SQLiteInventoryLocation.insert(
                SQLiteInventoryLocation(id: locationID, name: "Room", homeID: homeID)
            ).execute(db)
            try SQLiteInventoryItem.insert(
                SQLiteInventoryItem(
                    id: itemID, title: "Widget", locationID: locationID, homeID: homeID
                )
            ).execute(db)
            try SQLiteInventoryItemLabel.insert(
                SQLiteInventoryItemLabel(
                    id: UUID(), inventoryItemID: itemID, inventoryLabelID: labelID
                )
            ).execute(db)
            try SQLiteHomeInsurancePolicy.insert(
                SQLiteHomeInsurancePolicy(
                    id: UUID(), homeID: homeID, insurancePolicyID: policyID
                )
            ).execute(db)
        }

        let passes = try checkForeignKeyIntegrity(db: db)
        #expect(passes, "Foreign key violations found")
    }
}
