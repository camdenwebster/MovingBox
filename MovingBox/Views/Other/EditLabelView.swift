//
//  EditLabelView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import SwiftData
import SwiftUI

struct EditLabelView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    var label: InventoryLabel?
    @State private var labelName = ""
    @State private var labelDesc = ""
    @State private var labelColor = Color.red
    @State private var isEditing = false
    @Query(sort: [
        SortDescriptor(\InventoryLabel.name)
    ]) var labels: [InventoryLabel]
    
    // Computed properties
    private var isNewLabel: Bool {
        label == nil
    }
    
    private var isEditingEnabled: Bool {
        isNewLabel || isEditing
    }
    
    var body: some View {
        Form {
            Section("Label Name") {
                TextField("Appliances, Electronics, etc.", text: $labelName)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .black : .secondary)
            }
            Section("Color") {
                ColorPicker("Color", selection: $labelColor, supportsOpacity: false)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .black : .secondary)
            }
            if isEditingEnabled || !labelDesc.isEmpty {
                Section("Label Description") {
                    TextField("Enter a Description", text: $labelDesc)
                        .disabled(!isEditingEnabled)
                        .foregroundColor(isEditingEnabled ? .black : .secondary)
                }
            }
        }
        .navigationTitle(isNewLabel ? "New Label" : "\(label?.name ?? "") Details")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: labelColor, setColor)
        .toolbar {
            if !isNewLabel {
                // Edit/Save button for existing locations
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        // Save changes
                        label?.name = labelName
                        label?.desc = labelDesc
                        label?.color = UIColor(labelColor)
                        isEditing = false
                        router.path.removeLast()
                    } else {
                        isEditing = true
                    }
                }
            } else {
                // Save button for new labels
                Button("Save") {
                    let newLabel = InventoryLabel(name: labelName, desc: labelDesc, color: UIColor(labelColor))
                    modelContext.insert(newLabel)
                    TelemetryManager.shared.trackLabelCreated(name: newLabel.name)
                    print("EditLabelView: Created new label - \(newLabel.name)")
                    print("EditLabelView: Total number of labels after save: \(labels.count)")
                    router.path.removeLast()
                }
                .disabled(labelName.isEmpty)
            }
        }
        .onAppear {
            if let existingLabel = label {
                // Initialize editing fields with existing values
                labelName = existingLabel.name
                labelDesc = existingLabel.desc
                labelColor = Color(existingLabel.color ?? .red)
            }
        }
    }
    
    func setColor() {
        
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
