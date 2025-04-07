//
//  InventoryListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import SwiftData
import SwiftUI

enum Options: Hashable {
    case destination(String)
}

struct InventoryListView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @State private var path = NavigationPath()
    @State private var sortOrder = [SortDescriptor(\InventoryItem.title)]
    @State private var searchText = ""
    @State private var showingPaywall = false
    @State private var showLimitAlert = false
    @State private var showingImageAnalysis = false
    @State private var analyzingImage: UIImage?
    
    @Query private var allItems: [InventoryItem]
    
    let location: InventoryLocation?
    
    var body: some View {
        InventoryListSubView(location: location, searchString: searchText, sortOrder: sortOrder)
            .navigationTitle(location?.name ?? "All Items")
            .navigationDestination(for: InventoryItem.self) { inventoryItem in
                InventoryDetailView(inventoryItemToDisplay: inventoryItem, navigationPath: $path, showSparklesButton: true)
            }
            .toolbar {
                Menu("Sort", systemImage: "arrow.up.arrow.down") {
                    Picker("Sort", selection: $sortOrder) {
                        Text("Title (A-Z)")
                            .tag([SortDescriptor(\InventoryItem.title)])
                        Text("Title (Z-A)")
                            .tag([SortDescriptor(\InventoryItem.title, order: .reverse)])
                    }
                }
                Menu("Add Item", systemImage: "plus") {
                    Button(action: {
                        if settings.shouldShowFirstTimePaywall(itemCount: allItems.count) {
                            showingPaywall = true
                        } else if settings.hasReachedItemLimit(currentCount: allItems.count) {
                            showLimitAlert = true
                        } else {
                            let newItem = InventoryItem(
                                title: "",
                                quantityString: "1",
                                quantityInt: 1,
                                desc: "",
                                serial: "",
                                model: "",
                                make: "",
                                location: location,
                                label: nil,
                                price: Decimal.zero,
                                insured: false,
                                assetId: "",
                                notes: "",
                                showInvalidQuantityAlert: false
                            )
                            router.navigate(to: .inventoryDetailView(item: newItem, showSparklesButton: true, isEditing: true))
                        }
                    }) {
                        Label("Add Manually", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("createManually")
                    
                    Button(action: {
                        if settings.shouldShowFirstTimePaywall(itemCount: allItems.count) {
                            showingPaywall = true
                        } else if settings.hasReachedItemLimit(currentCount: allItems.count) {
                            showLimitAlert = true
                        } else {
                            router.navigate(to: .addInventoryItemView(location: location))
                        }
                    }) {
                        Label("Add from Photo", systemImage: "camera")
                    }
                    .accessibilityIdentifier("createFromCamera")
                }
                .accessibilityIdentifier("addItem")
            }
            .searchable(text: $searchText)
            .sheet(isPresented: $showingPaywall) {
                MovingBoxPaywallView()
            }
            .fullScreenCover(isPresented: $showingImageAnalysis) {
                if let image = analyzingImage {
                    ImageAnalysisView(image: image) {
                        showingImageAnalysis = false
                        analyzingImage = nil
                    }
                }
            }
            .alert("Upgrade to Pro", isPresented: $showLimitAlert) {
                Button("Upgrade") {
                    showingPaywall = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You've reached the maximum number of items (\(SettingsManager.maxFreeItems)) for free users. Upgrade to Pro for unlimited items!")
            }
    }
    
    func handlePhotoCaptured(_ image: UIImage) {
        analyzingImage = image
        showingImageAnalysis = true
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return InventoryListView(location: previewer.location)
            .modelContainer(previewer.container)
            .environmentObject(Router())
            .environmentObject(SettingsManager())
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
