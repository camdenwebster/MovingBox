//
//  EditLabelView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import SwiftUI

struct EditLabelView: View {
    @Environment(\.self) var environment
    @Bindable var label: InventoryLabel
    @State private var color = Color.red
    
    var body: some View {
        Form {
            Section("Label Name") {
                TextField("Appliances, Electronics, etc.", text: $label.name)
            }
            Section("Color") {
                ColorPicker("Color", selection: $color, supportsOpacity: false)
            }
            Section("Label Description") {
                TextField("Enter a Description", text: $label.desc)
            }
        }
        .navigationTitle("Edit Label")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: color, setColor)
    }
    
    func setColor() {
        label.color = UIColor(color)
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
