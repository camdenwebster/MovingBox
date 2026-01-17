//
//  LabelsListView.swift
//  MovingBox
//
//  Created by Claude Code on 1/17/26.
//

import SwiftData
import SwiftUI

struct LabelsListView: View {
    let showAllHomes: Bool

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @State private var searchText = ""

    @Query(sort: [
        SortDescriptor(\InventoryLabel.name)
    ]) private var allLabels: [InventoryLabel]

    @Query(sort: \Home.purchaseDate) private var homes: [Home]

    private var activeHome: Home? {
        guard let activeIdString = settings.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    // Filter labels by active home
    private var labels: [InventoryLabel] {
        guard !showAllHomes, let activeHome = activeHome else {
            return allLabels
        }
        return allLabels.filter { $0.home?.id == activeHome.id }
    }

    // Filtered labels based on search
    private var filteredLabels: [InventoryLabel] {
        if searchText.isEmpty {
            return labels
        }
        return labels.filter { label in
            label.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var columns: [GridItem] {
        let minimumCardWidth: CGFloat = 160
        let maximumCardWidth: CGFloat = 220
        return [GridItem(.adaptive(minimum: minimumCardWidth, maximum: maximumCardWidth))]
    }

    var body: some View {
        Group {
            if filteredLabels.isEmpty && searchText.isEmpty {
                ContentUnavailableView(
                    "No Labels",
                    systemImage: "tag",
                    description: Text("Add labels to categorize your items.")
                )
                .toolbar {
                    ToolbarItem {
                        Button {
                            router.navigate(to: .editLabelView(label: nil, isEditing: true))
                        } label: {
                            Label("Add Label", systemImage: "plus")
                        }
                        .accessibilityIdentifier("addLabel")
                    }
                }
            } else if filteredLabels.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No labels found matching '\(searchText)'")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredLabels) { label in
                            NavigationLink(value: Router.Destination.inventoryListViewForLabel(label: label)) {
                                LabelItemCard(label: label)
                                    .frame(maxWidth: 180)
                            }
                        }
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItem {
                        Button {
                            router.navigate(to: .editLabelView(label: nil, isEditing: true))
                        } label: {
                            Label("Add Label", systemImage: "plus")
                        }
                        .accessibilityIdentifier("addLabel")
                    }
                }
            }
        }
        .navigationTitle("Labels")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search labels")
        .background(Color(.systemGroupedBackground))
        .onAppear {
            print("LabelsListView: Total number of labels: \(labels.count)")
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return LabelsListView(showAllHomes: false)
            .modelContainer(previewer.container)
            .environmentObject(Router())
            .environmentObject(SettingsManager())
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
