//
//  LabelSelectionView.swift
//  MovingBox
//
//  Created by AI Assistant on 1/10/25.
//

import SwiftData
import SwiftUI

struct LabelSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\InventoryLabel.name)]) private var labels: [InventoryLabel]
    
    @Binding var selectedLabel: InventoryLabel?
    @State private var searchText = ""
    
    private var filteredLabels: [InventoryLabel] {
        if searchText.isEmpty {
            return labels
        }
        return labels.filter { label in
            label.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // None option
                Button(action: {
                    selectedLabel = nil
                    dismiss()
                }) {
                    HStack {
                        Text("None")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedLabel == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                if !filteredLabels.isEmpty {
                    Section {
                        ForEach(filteredLabels) { label in
                            Button(action: {
                                selectedLabel = label
                                dismiss()
                            }) {
                                HStack {
                                    Text("\(label.emoji) \(label.name)")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedLabel?.id == label.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if filteredLabels.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView(
                        "No Labels Found",
                        systemImage: "magnifyingglass",
                        description: Text("No labels match '\(searchText)'")
                    )
                }
            }
            .searchable(text: $searchText, prompt: "Search labels")
            .navigationTitle("Select Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        addNewLabel()
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private func addNewLabel() {
        let newLabel = InventoryLabel(name: "New Label", emoji: "📦")
        modelContext.insert(newLabel)
        selectedLabel = newLabel
        dismiss()
    }
}

#Preview {
    @Previewable @State var label: InventoryLabel? = nil
    return LabelSelectionView(selectedLabel: $label)
}
