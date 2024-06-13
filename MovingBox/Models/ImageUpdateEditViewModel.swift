//
//  ImageUpdateEditViewModel.swift
//  MovingBox
//
//  Created by Camden Webster on 6/9/24.
//

import UIKit

class ImageUpdateEditViewModel {
    var data: Data?
    
    var inventoryItem: InventoryItem?
//    var inventoryLocation: InventoryLocation?
    
    var image: UIImage {
        if let data, let uiImage = UIImage(data: data) {
            return uiImage
        } else {
            return Constants.placeholderImage
        }
    }
    
    init() {}
    init(inventoryItem: InventoryItem) {
        self.inventoryItem = inventoryItem
//        self.inventoryLocation = inventoryLocation
    }
    
    @MainActor
    func clearImge() {
        data = nil
    }
    
    var isUpdating: Bool { inventoryItem != nil }
//    var isDisabled: Bool { }
}
