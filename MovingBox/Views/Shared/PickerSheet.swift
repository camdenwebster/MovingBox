//
//  PickerSheet.swift
//  MovingBox
//
//  Created by Claude on 8/19/25.
//

import SwiftData
import SwiftUI

struct PickerSheet<T: Hashable & Identifiable>: View {
    let title: String
    let items: [T]
    let itemContent: (T) -> AnyView
    let onSelect: (T?) -> Void
    let onCancel: () -> Void
    let showNoSelectionOption: Bool
    let noSelectionLabel: String

    init(
        title: String,
        items: [T],
        showNoSelectionOption: Bool = false,
        noSelectionLabel: String = "None",
        onSelect: @escaping (T?) -> Void,
        onCancel: @escaping () -> Void,
        @ViewBuilder itemContent: @escaping (T) -> AnyView
    ) {
        self.title = title
        self.items = items
        self.showNoSelectionOption = showNoSelectionOption
        self.noSelectionLabel = noSelectionLabel
        self.onSelect = onSelect
        self.onCancel = onCancel
        self.itemContent = itemContent
    }

    var body: some View {
        NavigationView {
            List {
                if showNoSelectionOption {
                    Button(action: {
                        onSelect(nil)
                    }) {
                        HStack {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.secondary)
                            Text(noSelectionLabel)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                ForEach(items) { item in
                    Button(action: {
                        onSelect(item)
                    }) {
                        itemContent(item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(title)
            #if os(iOS)
                .movingBoxNavigationTitleDisplayModeInline()
                .toolbar {
                    ToolbarItem(placement: .movingBoxTrailing) {
                        Button("Cancel", action: onCancel)
                    }
                }
            #else
                .toolbar {
                    ToolbarItem {
                        Button("Cancel", action: onCancel)
                    }
                }
            #endif
        }
    }
}

// MARK: - Convenience extensions for common picker types

extension PickerSheet where T == InventoryLocation {
    static func locationPicker(
        locations: [InventoryLocation],
        onSelect: @escaping (InventoryLocation?) -> Void,
        onCancel: @escaping () -> Void
    ) -> PickerSheet<InventoryLocation> {
        PickerSheet(
            title: "Select Location",
            items: locations,
            onSelect: onSelect,
            onCancel: onCancel
        ) { location in
            AnyView(
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if !location.desc.isEmpty {
                        Text(location.desc)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            )
        }
    }
}

extension PickerSheet where T == InventoryLabel {
    static func labelPicker(
        labels: [InventoryLabel],
        onSelect: @escaping (InventoryLabel?) -> Void,
        onCancel: @escaping () -> Void
    ) -> PickerSheet<InventoryLabel> {
        PickerSheet(
            title: "Select Label",
            items: labels,
            showNoSelectionOption: true,
            noSelectionLabel: "No Label",
            onSelect: onSelect,
            onCancel: onCancel
        ) { label in
            AnyView(
                HStack {
                    Circle()
                        .fill(Color(label.color ?? .systemBlue))
                        .frame(width: 16, height: 16)
                    if !label.emoji.isEmpty {
                        Text(label.emoji)
                    }
                    Text(label.name)
                        .foregroundColor(.primary)
                }
            )
        }
    }
}
