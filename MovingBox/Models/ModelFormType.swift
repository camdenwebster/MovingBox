//
//  ModelFormType.swift
//  MovingBox
//
//  Created by Camden Webster on 6/11/24.
//

import SwiftUI

enum ModelFormType: Identifiable, View {
    case new
    case update(InventoryItem)
    var id: String {
        String(describing: self)
    }
    
    var body: some View {
        switch self {
        case .new:
            ImageUpdateEditView(vm: ImageUpdateEditViewModel())
        case .update(let inventoryItem):
                 ImageUpdateEditView(vm: ImageUpdateEditViewModel(inventoryItem: inventoryItem))
        }
    }
}
