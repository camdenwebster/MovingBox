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
    @EnvironmentObject var settingsManager: SettingsManager
    @Query(sort: [SortDescriptor(\InventoryLabel.name)]) private var allLabels: [InventoryLabel]
    @Query(sort: \Home.purchaseDate) private var homes: [Home]

    // Support both single and multi-select modes
    @Binding var selectedLabels: [InventoryLabel]
    @State private var searchText = ""

    private let maxLabels = 5

    // Single-select convenience initializer
    init(selectedLabel: Binding<InventoryLabel?>) {
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
    init(selectedLabels: Binding<[InventoryLabel]>) {
        self._selectedLabels = selectedLabels
    }

    private var activeHome: Home? {
        guard let activeIdString = settingsManager.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    // Filter labels by active home
    private var labels: [InventoryLabel] {
        guard let activeHome = activeHome else {
            return allLabels
        }
        return allLabels.filter { $0.home?.id == activeHome.id }
    }

    private var filteredLabels: [InventoryLabel] {
        if searchText.isEmpty {
            return labels
        }
        return labels.filter { label in
            label.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func isSelected(_ label: InventoryLabel) -> Bool {
        selectedLabels.contains { $0.id == label.id }
    }

    private func toggleLabel(_ label: InventoryLabel) {
        if isSelected(label) {
            selectedLabels.removeAll { $0.id == label.id }
        } else if selectedLabels.count < maxLabels {
            selectedLabels.append(label)
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
                        selectedLabels.removeAll()
                    }
                    .font(.subheadline)
                }

                // Show selected labels as capsules
                FlowLayout(spacing: 8) {
                    ForEach(selectedLabels) { label in
                        selectedLabelCapsule(for: label)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func selectedLabelCapsule(for label: InventoryLabel) -> some View {
        HStack(spacing: 4) {
            Text(label.emoji)
            Text(label.name)
            Button(action: {
                selectedLabels.removeAll { $0.id == label.id }
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
    private func labelRow(for label: InventoryLabel) -> some View {
        Button(action: { toggleLabel(label) }) {
            labelRowContent(for: label)
        }
        .buttonStyle(.plain)
        .disabled(!isSelected(label) && selectedLabels.count >= maxLabels)
    }

    @ViewBuilder
    private func labelRowContent(for label: InventoryLabel) -> some View {
        HStack {
            Text("\(label.emoji) \(label.name)")
                .foregroundStyle(.primary)
            Spacer()
            labelCheckmark(for: label)
        }
    }

    @ViewBuilder
    private func labelCheckmark(for label: InventoryLabel) -> some View {
        if isSelected(label) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)
        } else if selectedLabels.count >= maxLabels {
            Image(systemName: "circle")
                .foregroundStyle(.secondary.opacity(0.5))
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
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
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                Button(action: addNewLabel) {
                    Image(systemName: "plus")
                }

                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
    }

    private func addNewLabel() {
        let newLabel = InventoryLabel(name: "New Label", emoji: "📦")
        newLabel.home = activeHome
        modelContext.insert(newLabel)
        if selectedLabels.count < maxLabels {
            selectedLabels.append(newLabel)
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
    @Previewable @State var labels: [InventoryLabel] = []
    return LabelSelectionView(selectedLabels: $labels)
        .environmentObject(SettingsManager())
}
