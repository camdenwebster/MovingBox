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
class InventoryLabel {
    var id: UUID = UUID()
    var name: String = ""
    var desc: String = ""
    @Attribute(.transformable(by: UIColorValueTransformer.self)) var color: UIColor?
    var emoji: String = "🏷️"  // Default emoji
    var inventoryItems: [InventoryItem]? = [InventoryItem]()

    init(
        id: UUID = UUID(),
        name: String = "", desc: String = "", color: UIColor? = nil, inventoryItems: [InventoryItem]? = nil,
        emoji: String = "🏷️"
    ) {
        self.id = id
        self.name = name
        self.desc = desc
        self.color = color
        self.inventoryItems = inventoryItems
        self.emoji = emoji
    }

}
