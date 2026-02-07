//
//  LabelSelectionView.swift
//  MovingBox
//
//  Created by AI Assistant on 1/10/25.
//

import Dependencies
import SQLiteData
import SwiftUI

struct LabelSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @FetchAll(SQLiteInventoryLabel.order(by: \.name), animation: .default)
    private var allLabels: [SQLiteInventoryLabel]

    // Support both single and multi-select modes
    @Binding var selectedLabels: [SQLiteInventoryLabel]
    @State private var searchText = ""
    @State private var showAddLabelSheet = false

    private let maxLabels = 5

    // Single-select convenience initializer
    init(selectedLabel: Binding<SQLiteInventoryLabel?>) {
        self._selectedLabels = Binding(
            get: {
                if let label = selectedLabel.wrappedValue {
                    return [label]
                }
                return []
            },
            set: { newLabels in
                selectedLabel.wrappedValue = newLabels.first
            }
        )
    }

    // Multi-select initializer
    init(selectedLabels: Binding<[SQLiteInventoryLabel]>) {
        self._selectedLabels = selectedLabels
    }

    private var filteredLabels: [SQLiteInventoryLabel] {
        if searchText.isEmpty {
            return allLabels
        }
        return allLabels.filter { label in
            label.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func isSelected(_ label: SQLiteInventoryLabel) -> Bool {
        selectedLabels.contains { $0.id == label.id }
    }

    private func toggleLabel(_ label: SQLiteInventoryLabel) {
        withAnimation(.snappy(duration: 0.25)) {
            if isSelected(label) {
                selectedLabels.removeAll { $0.id == label.id }
            } else if selectedLabels.count < maxLabels {
                selectedLabels.append(label)
            }
        }
    }

    @ViewBuilder
    private var selectedLabelsSection: some View {
        if !selectedLabels.isEmpty {
            Section {
                HStack {
                    Text("Selected: \(selectedLabels.count)/\(maxLabels)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear All") {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedLabels.removeAll()
                        }
                    }
                    .font(.subheadline)
                }

                // Show selected labels as capsules
                FlowLayout(spacing: 8) {
                    ForEach(selectedLabels) { label in
                        selectedLabelCapsule(for: label)
                            .transition(
                                .asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                    }
                }
                .animation(.snappy(duration: 0.25), value: selectedLabels.count)
            }
        }
    }

    @ViewBuilder
    private func selectedLabelCapsule(for label: SQLiteInventoryLabel) -> some View {
        HStack(spacing: 4) {
            Text(label.emoji)
            Text(label.name)
            Button(action: {
                withAnimation(.snappy(duration: 0.25)) {
                    selectedLabels.removeAll { $0.id == label.id }
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(label.color ?? .blue).opacity(0.2))
        .clipShape(Capsule())
    }

    var body: some View {
        NavigationStack {
            listContent
                .searchable(text: $searchText, prompt: "Search labels")
                .navigationTitle("Select Labels")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .sheet(isPresented: $showAddLabelSheet) {
            NavigationStack {
                EditLabelView(
                    labelID: nil,
                    isEditing: true,
                    presentedInSheet: true,
                    onLabelCreated: { newLabel in
                        if selectedLabels.count < maxLabels {
                            withAnimation(.snappy(duration: 0.25)) {
                                selectedLabels.append(newLabel)
                            }
                        }
                    }
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            selectedLabelsSection
            availableLabelsSection
            emptySearchSection
        }
    }

    @ViewBuilder
    private var availableLabelsSection: some View {
        Section("Available Labels") {
            ForEach(filteredLabels) { label in
                labelRow(for: label)
            }
        }
    }

    @ViewBuilder
    private func labelRow(for label: SQLiteInventoryLabel) -> some View {
        Button(action: { toggleLabel(label) }) {
            labelRowContent(for: label)
        }
        .buttonStyle(.plain)
        .disabled(!isSelected(label) && selectedLabels.count >= maxLabels)
    }

    @ViewBuilder
    private func labelRowContent(for label: SQLiteInventoryLabel) -> some View {
        HStack {
            Text("\(label.emoji) \(label.name)")
                .foregroundStyle(.primary)
            Spacer()
            labelCheckmark(for: label)
        }
        .contentShape(Rectangle())  // Makes the whole row tappable
    }

    @ViewBuilder
    private func labelCheckmark(for label: SQLiteInventoryLabel) -> some View {
        let selected = isSelected(label)
        let atMaxCapacity = selectedLabels.count >= maxLabels

        if selected {
            Image(systemName: "checkmark")
                .foregroundStyle(checkmarkColor(selected: selected, atMaxCapacity: atMaxCapacity))
                .bold()
        }
    }

    private func checkmarkColor(selected: Bool, atMaxCapacity: Bool) -> some ShapeStyle {
        if selected {
            return AnyShapeStyle(.tint)
        } else if atMaxCapacity {
            return AnyShapeStyle(Color.secondary.opacity(0.5))
        } else {
            return AnyShapeStyle(Color.secondary)
        }
    }

    @ViewBuilder
    private var emptySearchSection: some View {
        if filteredLabels.isEmpty && !searchText.isEmpty {
            ContentUnavailableView(
                "No Labels Found",
                systemImage: "magnifyingglass",
                description: Text("No labels match '\(searchText)'")
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", systemImage: "xmark") {
                dismiss()
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Add Label", systemImage: "plus") {
                showAddLabelSheet = true
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Done", systemImage: "checkmark") { dismiss() }
                .backport.glassProminentButtonStyle()
        }
    }
}

// Simple flow layout for selected labels
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint])
    {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        let height = currentY + lineHeight
        return (CGSize(width: maxWidth, height: height), positions)
    }
}

#Preview {
    @Previewable @State var labels: [SQLiteInventoryLabel] = []
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    return LabelSelectionView(selectedLabels: $labels)
}
