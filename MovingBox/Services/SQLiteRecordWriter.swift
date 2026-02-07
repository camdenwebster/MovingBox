import Foundation
import GRDB
import UIKit

/// Shared SQL insert functions used by both `SQLiteMigrationCoordinator` and
/// `CloudKitRecoveryCoordinator` to write records to the sqlite-data database.
/// Centralizing these prevents column-list divergence between the two writers.
enum SQLiteRecordWriter {

    // MARK: - Write Data Structs

    struct LabelWriteData {
        let id: String
        let name: String
        let desc: String
        let colorHex: Int64?
        let emoji: String
    }

    struct HomeWriteData {
        let id: String
        let name: String
        let address1: String
        let address2: String
        let city: String
        let state: String
        let zip: String
        let country: String
        let purchaseDate: String
        let purchasePrice: String
        let imageURL: String?
        let secondaryPhotoURLs: String
        let isPrimary: Bool
        let colorName: String
    }

    struct PolicyWriteData {
        let id: String
        let providerName: String
        let policyNumber: String
        let deductibleAmount: String
        let dwellingCoverageAmount: String
        let personalPropertyCoverageAmount: String
        let lossOfUseCoverageAmount: String
        let liabilityCoverageAmount: String
        let medicalPaymentsCoverageAmount: String
        let startDate: String
        let endDate: String
    }

    struct LocationWriteData {
        let id: String
        let name: String
        let desc: String
        let sfSymbolName: String?
        let imageURL: String?
        let secondaryPhotoURLs: String
        let homeID: String?
    }

    struct ItemWriteData {
        let id: String
        let title: String
        let quantityString: String
        let quantityInt: Int
        let desc: String
        let serial: String
        let model: String
        let make: String
        let price: String
        let insured: Bool
        let assetId: String
        let notes: String
        let replacementCost: String?
        let depreciationRate: Double?
        let imageURL: String?
        let secondaryPhotoURLs: String
        let hasUsedAI: Bool
        let createdAt: String
        let purchaseDate: String?
        let warrantyExpirationDate: String?
        let purchaseLocation: String
        let condition: String
        let hasWarranty: Bool
        let attachments: String
        let dimensionLength: String
        let dimensionWidth: String
        let dimensionHeight: String
        let dimensionUnit: String
        let weightValue: String
        let weightUnit: String
        let color: String
        let storageRequirements: String
        let isFragile: Bool
        let movingPriority: Int
        let roomDestination: String
        let locationID: String?
        let homeID: String?
    }

    struct ItemLabelWriteData {
        let id: String
        let inventoryItemID: String
        let inventoryLabelID: String
    }

    struct HomePolicyWriteData {
        let id: String
        let homeID: String
        let insurancePolicyID: String
    }

    // MARK: - Insert Functions

    static func insertLabel(_ data: LabelWriteData, into db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO "inventoryLabels" ("id", "name", "desc", "color", "emoji")
                VALUES (?, ?, ?, ?, ?)
                """,
            arguments: [
                data.id,
                data.name,
                data.desc,
                data.colorHex,
                data.emoji,
            ])
    }

    static func insertHome(_ data: HomeWriteData, into db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO "homes" ("id", "name", "address1", "address2", "city", "state", "zip", "country",
                    "purchaseDate", "purchasePrice", "imageURL", "secondaryPhotoURLs", "isPrimary", "colorName")
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                data.id,
                data.name,
                data.address1,
                data.address2,
                data.city,
                data.state,
                data.zip,
                data.country,
                data.purchaseDate,
                data.purchasePrice,
                data.imageURL,
                data.secondaryPhotoURLs,
                data.isPrimary,
                data.colorName,
            ])
    }

    static func insertPolicy(_ data: PolicyWriteData, into db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO "insurancePolicies" ("id", "providerName", "policyNumber",
                    "deductibleAmount", "dwellingCoverageAmount", "personalPropertyCoverageAmount",
                    "lossOfUseCoverageAmount", "liabilityCoverageAmount", "medicalPaymentsCoverageAmount",
                    "startDate", "endDate")
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                data.id,
                data.providerName,
                data.policyNumber,
                data.deductibleAmount,
                data.dwellingCoverageAmount,
                data.personalPropertyCoverageAmount,
                data.lossOfUseCoverageAmount,
                data.liabilityCoverageAmount,
                data.medicalPaymentsCoverageAmount,
                data.startDate,
                data.endDate,
            ])
    }

    static func insertLocation(_ data: LocationWriteData, into db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO "inventoryLocations" ("id", "name", "desc", "sfSymbolName", "imageURL",
                    "secondaryPhotoURLs", "homeID")
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                data.id,
                data.name,
                data.desc,
                data.sfSymbolName,
                data.imageURL,
                data.secondaryPhotoURLs,
                data.homeID,
            ])
    }

    static func insertItem(_ data: ItemWriteData, into db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO "inventoryItems" ("id", "title", "quantityString", "quantityInt", "desc", "serial",
                    "model", "make", "price", "insured", "assetId", "notes", "replacementCost", "depreciationRate",
                    "imageURL", "secondaryPhotoURLs", "hasUsedAI", "createdAt", "purchaseDate",
                    "warrantyExpirationDate", "purchaseLocation", "condition", "hasWarranty", "attachments",
                    "dimensionLength", "dimensionWidth", "dimensionHeight", "dimensionUnit", "weightValue",
                    "weightUnit", "color", "storageRequirements", "isFragile", "movingPriority", "roomDestination",
                    "locationID", "homeID")
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                data.id,
                data.title,
                data.quantityString,
                data.quantityInt,
                data.desc,
                data.serial,
                data.model,
                data.make,
                data.price,
                data.insured,
                data.assetId,
                data.notes,
                data.replacementCost,
                data.depreciationRate,
                data.imageURL,
                data.secondaryPhotoURLs,
                data.hasUsedAI,
                data.createdAt,
                data.purchaseDate,
                data.warrantyExpirationDate,
                data.purchaseLocation,
                data.condition,
                data.hasWarranty,
                data.attachments,
                data.dimensionLength,
                data.dimensionWidth,
                data.dimensionHeight,
                data.dimensionUnit,
                data.weightValue,
                data.weightUnit,
                data.color,
                data.storageRequirements,
                data.isFragile,
                data.movingPriority,
                data.roomDestination,
                data.locationID,
                data.homeID,
            ])
    }

    static func insertItemLabel(_ data: ItemLabelWriteData, into db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO "inventoryItemLabels" ("id", "inventoryItemID", "inventoryLabelID")
                VALUES (?, ?, ?)
                """,
            arguments: [
                data.id,
                data.inventoryItemID,
                data.inventoryLabelID,
            ])
    }

    static func insertHomePolicy(_ data: HomePolicyWriteData, into db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO "homeInsurancePolicies" ("id", "homeID", "insurancePolicyID")
                VALUES (?, ?, ?)
                """,
            arguments: [
                data.id,
                data.homeID,
                data.insurancePolicyID,
            ])
    }

    // MARK: - Shared Helpers

    /// Converts NSKeyedArchiver UIColor data to hex RGBA Int64.
    /// Returns a fallback gray (0x808080FF) if the BLOB exists but can't be deserialized.
    static func colorHexFromData(_ data: Data) -> Int64? {
        guard let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)
        else { return 0x8080_80FF }

        let converted = color.cgColor.converted(
            to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil
        )
        guard let components = converted?.components, components.count >= 3 else { return nil }
        let r = Int64(components[0] * 0xFF) << 24
        let g = Int64(components[1] * 0xFF) << 16
        let b = Int64(components[2] * 0xFF) << 8
        let a = Int64((components.count >= 4 ? components[3] : 1) * 0xFF)
        return r | g | b | a
    }

    /// Converts a Double value to Decimal via string representation to avoid
    /// IEEE 754 precision loss (e.g. 99.99 → "99.9899999999...").
    static func decimalFromDouble(_ value: Double?) -> Decimal {
        guard let value else { return 0 }
        return Decimal(string: "\(value)") ?? Decimal(value)
    }
}
