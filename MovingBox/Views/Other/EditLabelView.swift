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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router
    var label: InventoryLabel?
    var presentedInSheet: Bool
    var onDismiss: (() -> Void)?
    var onLabelCreated: ((InventoryLabel) -> Void)?
    @State private var labelName = ""
    @State private var labelDesc = ""
    @State private var labelColor = Color.red
    @State private var labelEmoji = "🏷️"
    @State private var isEditing = false
    @State private var showEmojiPicker = false
    @Query(sort: [
        SortDescriptor(\InventoryLabel.name)
    ]) var labels: [InventoryLabel]

    // MARK: - Add initializer to accept isEditing parameter
    init(
        label: InventoryLabel? = nil, isEditing: Bool = false, presentedInSheet: Bool = false,
        onDismiss: (() -> Void)? = nil,
        onLabelCreated: ((InventoryLabel) -> Void)? = nil
    ) {
        self.label = label
        self._isEditing = State(initialValue: isEditing)
        self.presentedInSheet = presentedInSheet
        self.onDismiss = onDismiss
        self.onLabelCreated = onLabelCreated
    }

    // Computed properties
    private var isNewLabel: Bool {
        label == nil
    }

    private var isEditingEnabled: Bool {
        isNewLabel || isEditing
    }

    var body: some View {
        Form {
            Section("Details") {
                FormTextFieldRow(
                    label: "Name", text: $labelName, isEditing: $isEditing, placeholder: "Electronics",
                    textFieldIdentifier: "label-name-field"
                )
                .disabled(!isEditingEnabled)
                ColorPicker("Color", selection: $labelColor, supportsOpacity: false)
                    .disabled(!isEditingEnabled)
                HStack {
                    Text("Emoji")
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                    Button(action: {
                        if isEditingEnabled {
                            showEmojiPicker = true
                        }
                    }) {
                        Text(labelEmoji)
                            .font(.system(size: 32))
                            .frame(width: 50, height: 40)
                            .background(isEditingEnabled ? Color.gray.opacity(0.2) : Color.clear)
                            .cornerRadius(UIConstants.cornerRadius)
                    }
                    .disabled(!isEditingEnabled)
                    .sheet(isPresented: $showEmojiPicker) {
                        EmojiPickerView(selectedEmoji: $labelEmoji)
                    }
                }

            }
            if isEditingEnabled || !labelDesc.isEmpty {
                Section("Description") {
                    TextEditor(text: $labelDesc)
                        .disabled(!isEditingEnabled)
                        .foregroundColor(isEditingEnabled ? .primary : .secondary)
                        .frame(height: 100)
                }
            }
        }
        .navigationTitle(isNewLabel ? "New Label" : "Edit \(label?.name ?? "Label")")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: labelColor, setColor)
        .toolbar {
            if presentedInSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("label-dismiss-button")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if !isNewLabel {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            label?.name = labelName
                            label?.desc = labelDesc
                            label?.color = UIColor(labelColor)
                            label?.emoji = labelEmoji
                            isEditing = false
                            if presentedInSheet {
                                dismissView()
                            }
                        } else {
                            isEditing = true
                        }
                    }
                    .accessibilityIdentifier("label-edit-save-button")
                } else {
                    Button("Save") {
                        let newLabel = InventoryLabel(
                            name: labelName, desc: labelDesc, color: UIColor(labelColor), emoji: labelEmoji)

                        modelContext.insert(newLabel)
                        TelemetryManager.shared.trackLabelCreated(name: newLabel.name)
                        print("EditLabelView: Created new label - \(newLabel.name)")
                        print("EditLabelView: Total number of labels after save: \(labels.count)")
                        onLabelCreated?(newLabel)
                        isEditing = false
                        dismissView()
                    }
                    .disabled(labelName.isEmpty)
                    .bold()
                    .accessibilityIdentifier("label-save-button")
                }
            }
        }
        .onAppear {
            if let existingLabel = label {
                // Initialize editing fields with existing values
                labelName = existingLabel.name
                labelDesc = existingLabel.desc
                labelColor = Color(existingLabel.color ?? .red)
                labelEmoji = existingLabel.emoji
            }
        }
    }

    private func dismissView() {
        if presentedInSheet {
            onDismiss?()
            dismiss()
        } else {
            router.navigateBack()
        }
    }

    func setColor() {

    }
}

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(LabelEmojiCatalog.categories, id: \.0) { category in
                        VStack(alignment: .leading) {
                            Text(category.0)
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                                ForEach(category.1, id: \.self) { emoji in
                                    Button(action: {
                                        selectedEmoji = emoji
                                        dismiss()
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 28))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear
                                            )
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()

        return EditLabelView(label: previewer.label)
            .modelContainer(previewer.container)
            .environmentObject(Router())
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
