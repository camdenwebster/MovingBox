//
//  EditLabelView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import SwiftUI

struct EditLabelView: View {
    @Bindable var label: InventoryLabel

    var body: some View {
        Form {
            Section("Label Name") {
                TextField("Appliances, Electronics, etc.", text: $label.name)
            }
            Section("Label Description") {
                TextField("Enter a Description", text: $label.desc)
            }
        }
        .navigationTitle("Edit Label")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        
        return EditLabelView(label: previewer.label)
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
