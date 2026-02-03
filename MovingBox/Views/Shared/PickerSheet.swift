//
//  PickerSheet.swift
//  MovingBox
//
//  Created by Claude on 8/19/25.
//

import SQLiteData
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
                                .foregroundStyle(.secondary)
                            Text(noSelectionLabel)
                                .foregroundStyle(.primary)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

// MARK: - Convenience extensions for common picker types

extension PickerSheet where T == SQLiteInventoryLocation {
    static func locationPicker(
        locations: [SQLiteInventoryLocation],
        onSelect: @escaping (SQLiteInventoryLocation?) -> Void,
        onCancel: @escaping () -> Void
    ) -> PickerSheet<SQLiteInventoryLocation> {
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
                        .foregroundStyle(.primary)
                    if !location.desc.isEmpty {
                        Text(location.desc)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            )
        }
    }
}

extension PickerSheet where T == SQLiteInventoryLabel {
    static func labelPicker(
        labels: [SQLiteInventoryLabel],
        onSelect: @escaping (SQLiteInventoryLabel?) -> Void,
        onCancel: @escaping () -> Void
    ) -> PickerSheet<SQLiteInventoryLabel> {
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
                        .fill(Color(label.color ?? .blue))
                        .frame(width: 16, height: 16)
                    if !label.emoji.isEmpty {
                        Text(label.emoji)
                    }
                    Text(label.name)
                        .foregroundStyle(.primary)
                }
            )
        }
    }
}
