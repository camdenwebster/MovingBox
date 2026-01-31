//
//  SFSymbolPickerView.swift
//  MovingBox
//
//  Created by Claude on 1/29/26.
//

import SwiftUI

struct SFSymbolPickerView: View {
    @Binding var selectedSymbol: String?
    @Environment(\.dismiss) private var dismiss

    // Home-relevant SF Symbol categories
    let symbolCategories: [(String, [String])] = [
        (
            "Rooms",
            [
                "sofa.fill", "bed.double.fill", "bed.double", "chair.fill",
                "table.furniture.fill", "lamp.floor.fill", "lamp.desk.fill",
                "fireplace.fill", "stairs", "door.left.hand.open",
                "door.left.hand.closed",
            ]
        ),
        (
            "Kitchen & Dining",
            [
                "fork.knife", "cooktop.fill", "refrigerator.fill",
                "oven.fill", "microwave.fill", "cup.and.saucer.fill",
                "wineglass.fill", "mug.fill",
            ]
        ),
        (
            "Bedroom & Bath",
            [
                "shower.fill", "bathtub.fill", "toilet.fill",
                "comb.fill", "tshirt.fill", "alarm.fill",
            ]
        ),
        (
            "Outdoor",
            [
                "sun.max.fill", "leaf.fill", "tree.fill",
                "tent.fill", "figure.pool.swim",
                "sprinkler.and.droplets.fill",
            ]
        ),
        (
            "Office & Work",
            [
                "desktopcomputer", "laptopcomputer", "printer.fill",
                "externaldrive.fill", "display", "keyboard.fill",
                "headphones",
            ]
        ),
        (
            "Storage & Utility",
            [
                "door.garage.closed", "building.columns.fill",
                "house.lodge.fill", "washer.fill", "dryer.fill",
                "cabinet.fill", "archivebox.fill", "shippingbox.fill",
            ]
        ),
        (
            "General",
            [
                "house.fill", "house.circle.fill", "mappin.circle.fill",
                "location.fill", "star.fill", "heart.fill",
                "tag.fill", "folder.fill",
            ]
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // "No Icon" option to clear selection
                    Button {
                        selectedSymbol = nil
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "minus.circle")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("No Icon")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedSymbol == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("symbol-picker-none")

                    ForEach(symbolCategories, id: \.0) { category in
                        VStack(alignment: .leading) {
                            Text(category.0)
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible()), count: 6),
                                spacing: 10
                            ) {
                                ForEach(category.1, id: \.self) { symbolName in
                                    Button {
                                        selectedSymbol = symbolName
                                        dismiss()
                                    } label: {
                                        Image(systemName: symbolName)
                                            .font(.title2)
                                            .frame(width: 44, height: 44)
                                            .background(
                                                selectedSymbol == symbolName
                                                    ? Color.accentColor.opacity(0.2)
                                                    : Color.clear
                                            )
                                            .clipShape(.rect(cornerRadius: 8))
                                            .foregroundStyle(
                                                selectedSymbol == symbolName
                                                    ? Color.accentColor
                                                    : .secondary
                                            )
                                    }
                                    .accessibilityIdentifier("symbol-picker-\(symbolName)")
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SFSymbolPickerView(selectedSymbol: .constant("sofa.fill"))
}
