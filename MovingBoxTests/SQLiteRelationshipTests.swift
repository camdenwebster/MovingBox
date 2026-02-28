import Foundation
import Testing

@testable import MovingBox

@Suite("SQLite Relationships & Constraints")
struct SQLiteRelationshipTests {

    // MARK: - Cascade Deletes (Other Side)

    @Suite("Cascade Deletes")
    struct CascadeDeleteTests {

        @Test("Deleting a label cascades to item-label join rows")
        func deleteLabelCascadesJoin() throws {
            let db = try makeInMemoryDatabase()
            let itemID = UUID()
            let label1ID = UUID()
            let label2ID = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: itemID, title: "Widget")
                ).execute(db)
                try SQLiteInventoryLabel.insert(
                    SQLiteInventoryLabel(id: label1ID, name: "Fragile")
                ).execute(db)
                try SQLiteInventoryLabel.insert(
                    SQLiteInventoryLabel(id: label2ID, name: "Heavy")
                ).execute(db)
                try SQLiteInventoryItemLabel.insert(
                    SQLiteInventoryItemLabel(id: UUID(), inventoryItemID: itemID, inventoryLabelID: label1ID)
                ).execute(db)
                try SQLiteInventoryItemLabel.insert(
                    SQLiteInventoryItemLabel(id: UUID(), inventoryItemID: itemID, inventoryLabelID: label2ID)
                ).execute(db)
            }

            // Delete one label
            try db.write { db in
                try SQLiteInventoryLabel.find(label1ID).delete().execute(db)
            }

            let joinCount = try db.read { db in
                try SQLiteInventoryItemLabel.count().fetchOne(db)
            }
            #expect(joinCount == 1, "Only the join row for label2 should remain")

            // Item should still exist
            let item = try db.read { db in
                try SQLiteInventoryItem.find(itemID).fetchOne(db)
            }
            #expect(item != nil)
        }

        @Test("Deleting a policy cascades to home-policy join rows")
        func deletePolicyCascadesJoin() throws {
            let db = try makeInMemoryDatabase()
            let homeID = UUID()
            let policy1ID = UUID()
            let policy2ID = UUID()

            try db.write { db in
                try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Home")).execute(db)
                try SQLiteInsurancePolicy.insert(
                    SQLiteInsurancePolicy(id: policy1ID, providerName: "StateFarm")
                ).execute(db)
                try SQLiteInsurancePolicy.insert(
                    SQLiteInsurancePolicy(id: policy2ID, providerName: "Allstate")
                ).execute(db)
                try SQLiteHomeInsurancePolicy.insert(
                    SQLiteHomeInsurancePolicy(id: UUID(), homeID: homeID, insurancePolicyID: policy1ID)
                ).execute(db)
                try SQLiteHomeInsurancePolicy.insert(
                    SQLiteHomeInsurancePolicy(id: UUID(), homeID: homeID, insurancePolicyID: policy2ID)
                ).execute(db)
            }

            // Delete one policy
            try db.write { db in
                try SQLiteInsurancePolicy.find(policy1ID).delete().execute(db)
            }

            let joinCount = try db.read { db in
                try SQLiteHomeInsurancePolicy.count().fetchOne(db)
            }
            #expect(joinCount == 1, "Only the join row for policy2 should remain")

            // Home should still exist
            let home = try db.read { db in
                try SQLiteHome.find(homeID).fetchOne(db)
            }
            #expect(home != nil)
        }
    }

    // MARK: - ON DELETE SET NULL

    @Suite("ON DELETE SET NULL")
    struct SetNullTests {

        @Test("Deleting a location leaves item.locationID unchanged when location FK is removed")
        func deleteLocationLeavesItemLocationUnchanged() throws {
            let db = try makeInMemoryDatabase()
            let homeID = UUID()
            let locationID = UUID()
            let itemID = UUID()

            try db.write { db in
                try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Home")).execute(db)
                try SQLiteInventoryLocation.insert(
                    SQLiteInventoryLocation(id: locationID, name: "Kitchen", homeID: homeID)
                ).execute(db)
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(
                        id: itemID, title: "Toaster", locationID: locationID, homeID: homeID)
                ).execute(db)
            }

            // Delete the location
            try db.write { db in
                try SQLiteInventoryLocation.find(locationID).delete().execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(itemID).fetchOne(db)
            }
            #expect(item != nil, "Item should survive location deletion")
            #expect(item?.locationID == locationID, "locationID should remain unchanged after location deleted")
            #expect(item?.homeID == homeID, "homeID should be unchanged")
        }

        @Test("Deleting a home sets item.homeID to NULL")
        func deleteHomeNullsItemHome() throws {
            let db = try makeInMemoryDatabase()
            let homeID = UUID()
            let itemID = UUID()

            try db.write { db in
                try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Home")).execute(db)
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: itemID, title: "Sofa", homeID: homeID)
                ).execute(db)
            }

            try db.write { db in
                try SQLiteHome.find(homeID).delete().execute(db)
            }

            let item = try db.read { db in
                try SQLiteInventoryItem.find(itemID).fetchOne(db)
            }
            #expect(item != nil, "Item should survive home deletion")
            #expect(item?.homeID == nil, "homeID should be NULL after home deleted")
        }

        @Test("Deleting a home sets both location.homeID and item.homeID to NULL")
        func deleteHomeCascadesFullChain() throws {
            let db = try makeInMemoryDatabase()
            let homeID = UUID()
            let locationID = UUID()
            let itemID = UUID()

            try db.write { db in
                try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Home")).execute(db)
                try SQLiteInventoryLocation.insert(
                    SQLiteInventoryLocation(id: locationID, name: "Room", homeID: homeID)
                ).execute(db)
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(
                        id: itemID, title: "Lamp", locationID: locationID, homeID: homeID)
                ).execute(db)
            }

            try db.write { db in
                try SQLiteHome.find(homeID).delete().execute(db)
            }

            let location = try db.read { db in
                try SQLiteInventoryLocation.find(locationID).fetchOne(db)
            }
            let item = try db.read { db in
                try SQLiteInventoryItem.find(itemID).fetchOne(db)
            }
            #expect(location?.homeID == nil)
            #expect(item?.homeID == nil)
            #expect(item?.locationID == locationID, "locationID should be unaffected")
        }
    }

    // MARK: - Join Table Constraints
    // Note: SyncEngine does not support UNIQUE constraints, so join tables
    // use non-unique composite indexes. Duplicate rows are allowed at the
    // database level; the app layer is responsible for deduplication.

    @Suite("Join Table Constraints")
    struct JoinTableConstraintTests {

        @Test("Duplicate item-label join row is allowed (non-unique index)")
        func duplicateItemLabelAllowed() throws {
            let db = try makeInMemoryDatabase()
            let itemID = UUID()
            let labelID = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: itemID, title: "Widget")
                ).execute(db)
                try SQLiteInventoryLabel.insert(
                    SQLiteInventoryLabel(id: labelID, name: "Tag")
                ).execute(db)
                try SQLiteInventoryItemLabel.insert(
                    SQLiteInventoryItemLabel(id: UUID(), inventoryItemID: itemID, inventoryLabelID: labelID)
                ).execute(db)
            }

            // Inserting the same pair again should succeed (non-unique composite index)
            try db.write { db in
                try SQLiteInventoryItemLabel.insert(
                    SQLiteInventoryItemLabel(
                        id: UUID(), inventoryItemID: itemID, inventoryLabelID: labelID)
                ).execute(db)
            }

            let joinCount = try db.read { db in
                try SQLiteInventoryItemLabel.count().fetchOne(db)
            }
            #expect(joinCount == 2, "Both join rows should exist")
        }

        @Test("Duplicate home-policy join row is allowed (non-unique index)")
        func duplicateHomePolicyAllowed() throws {
            let db = try makeInMemoryDatabase()
            let homeID = UUID()
            let policyID = UUID()

            try db.write { db in
                try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Home")).execute(db)
                try SQLiteInsurancePolicy.insert(
                    SQLiteInsurancePolicy(id: policyID, providerName: "Provider")
                ).execute(db)
                try SQLiteHomeInsurancePolicy.insert(
                    SQLiteHomeInsurancePolicy(id: UUID(), homeID: homeID, insurancePolicyID: policyID)
                ).execute(db)
            }

            // Inserting the same pair again should succeed (non-unique composite index)
            try db.write { db in
                try SQLiteHomeInsurancePolicy.insert(
                    SQLiteHomeInsurancePolicy(
                        id: UUID(), homeID: homeID, insurancePolicyID: policyID)
                ).execute(db)
            }

            let joinCount = try db.read { db in
                try SQLiteHomeInsurancePolicy.count().fetchOne(db)
            }
            #expect(joinCount == 2, "Both join rows should exist")
        }

        @Test("Same label applied to different items is allowed")
        func sameLabelDifferentItems() throws {
            let db = try makeInMemoryDatabase()
            let item1ID = UUID()
            let item2ID = UUID()
            let labelID = UUID()

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: item1ID, title: "Item 1")
                ).execute(db)
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: item2ID, title: "Item 2")
                ).execute(db)
                try SQLiteInventoryLabel.insert(
                    SQLiteInventoryLabel(id: labelID, name: "Shared")
                ).execute(db)
                try SQLiteInventoryItemLabel.insert(
                    SQLiteInventoryItemLabel(id: UUID(), inventoryItemID: item1ID, inventoryLabelID: labelID)
                ).execute(db)
                try SQLiteInventoryItemLabel.insert(
                    SQLiteInventoryItemLabel(id: UUID(), inventoryItemID: item2ID, inventoryLabelID: labelID)
                ).execute(db)
            }

            let joinCount = try db.read { db in
                try SQLiteInventoryItemLabel.count().fetchOne(db)
            }
            #expect(joinCount == 2)
        }
    }

    // MARK: - Multi-Relationship Queries

    @Suite("Multi-Relationship Queries")
    struct MultiRelationshipTests {

        @Test("Multiple items in one location")
        func multipleItemsPerLocation() throws {
            let db = try makeInMemoryDatabase()
            let locationID = UUID()

            try db.write { db in
                try SQLiteInventoryLocation.insert(
                    SQLiteInventoryLocation(id: locationID, name: "Kitchen")
                ).execute(db)
                for i in 1...5 {
                    try SQLiteInventoryItem.insert(
                        SQLiteInventoryItem(
                            id: UUID(), title: "Item \(i)", locationID: locationID)
                    ).execute(db)
                }
            }

            let allItems = try db.read { db in
                try SQLiteInventoryItem.fetchAll(db)
            }
            let items = allItems.filter { $0.locationID == locationID }
            #expect(items.count == 5)
        }

        @Test("Multiple labels on one item")
        func multipleLabelsPerItem() throws {
            let db = try makeInMemoryDatabase()
            let itemID = UUID()
            var labelIDs: [UUID] = []

            try db.write { db in
                try SQLiteInventoryItem.insert(
                    SQLiteInventoryItem(id: itemID, title: "Multi-Label Item")
                ).execute(db)

                for name in ["Electronics", "Fragile", "Expensive"] {
                    let labelID = UUID()
                    labelIDs.append(labelID)
                    try SQLiteInventoryLabel.insert(
                        SQLiteInventoryLabel(id: labelID, name: name)
                    ).execute(db)
                    try SQLiteInventoryItemLabel.insert(
                        SQLiteInventoryItemLabel(
                            id: UUID(), inventoryItemID: itemID, inventoryLabelID: labelID)
                    ).execute(db)
                }
            }

            let allJoins = try db.read { db in
                try SQLiteInventoryItemLabel.fetchAll(db)
            }
            let joins = allJoins.filter { $0.inventoryItemID == itemID }
            #expect(joins.count == 3)
        }

        @Test("Multiple locations per home")
        func multipleLocationsPerHome() throws {
            let db = try makeInMemoryDatabase()
            let homeID = UUID()

            try db.write { db in
                try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Home")).execute(db)
                for name in ["Kitchen", "Bedroom", "Garage", "Bathroom"] {
                    try SQLiteInventoryLocation.insert(
                        SQLiteInventoryLocation(id: UUID(), name: name, homeID: homeID)
                    ).execute(db)
                }
            }

            let allLocations = try db.read { db in
                try SQLiteInventoryLocation.fetchAll(db)
            }
            let locations = allLocations.filter { $0.homeID == homeID }
            #expect(locations.count == 4)
        }
    }

    // MARK: - Index Verification

    @Suite("Indexes")
    struct IndexTests {

        @Test("Expected indexes exist on the database")
        func indexesExist() throws {
            let db = try makeInMemoryDatabase()

            let indexes = try db.read { db in
                try String.fetchAll(
                    db,
                    sql: """
                        SELECT name FROM sqlite_master
                        WHERE type='index' AND name LIKE 'idx_%'
                        ORDER BY name
                        """
                )
            }

            #expect(indexes.contains("idx_inventoryLocations_homeID"))
            #expect(indexes.contains("idx_inventoryItems_locationID"))
            #expect(indexes.contains("idx_inventoryItems_homeID"))
            #expect(indexes.contains("idx_inventoryItemLabels_inventoryItemID"))
            #expect(indexes.contains("idx_inventoryItemLabels_inventoryLabelID"))
            #expect(indexes.contains("idx_homeInsurancePolicies_homeID"))
            #expect(indexes.contains("idx_homeInsurancePolicies_insurancePolicyID"))
            #expect(indexes.contains("idx_inventoryItemLabels_composite"))
            #expect(indexes.contains("idx_homeInsurancePolicies_composite"))
        }
    }
}
