//
//  LabelModel.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Foundation
import SwiftData
import UIKit

@objc(UIColorValueTransformer)
final class UIColorValueTransformer: ValueTransformer {
    
    static func register() {
        ValueTransformer.setValueTransformer(
            UIColorValueTransformer(),
            forName: NSValueTransformerName("UIColorValueTransformer")
        )
    }
    
    override class func transformedValueClass() -> AnyClass {
        return UIColor.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    // return data
    override func transformedValue(_ value: Any?) -> Any? {
        guard let color = value as? UIColor else { return nil }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
            return data
        } catch {
            return nil
        }
    }
    
    // return UIColor
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
    
        do {
            let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)
            return color
        } catch {
            return nil
        }
    }
}

@Model
class InventoryLabel: Syncable {
    var id: UUID = UUID()
    var name: String = ""
    var desc: String = ""
    @Attribute(.transformable(by: UIColorValueTransformer.self)) var color: UIColor?
    var emoji: String = "🏷️" // Default emoji
    var inventoryItems: [InventoryItem]? = [InventoryItem]()
    
    // MARK: - Sync Properties
    var remoteId: String?
    var lastModified: Date = Date()
    var lastSynced: Date?
    var needsSync: Bool = false
    var isDeleted: Bool = false
    var syncServiceType: SyncServiceType?
    var version: Int = 1
    
    init(name: String = "", desc: String = "", color: UIColor? = nil, inventoryItems: [InventoryItem]? = nil, emoji: String = "🏷️") {
        self.name = name
        self.desc = desc
        self.color = color
        self.inventoryItems = inventoryItems
        self.emoji = emoji
        
        // Mark new labels for sync
        self.needsSync = true
        self.lastModified = Date()
    }
    
    /// Mark the label as requiring sync due to local changes
    func markForSync() {
        self.needsSync = true
        self.lastModified = Date()
        self.version += 1
    }

}
