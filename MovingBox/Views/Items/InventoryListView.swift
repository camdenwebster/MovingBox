//
//  InventoryListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import RevenueCatUI
import SwiftData
import SwiftUI

enum Options: Hashable {
    case destination(String)
}

struct InventoryListView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared
    
    @State private var path = NavigationPath()
    @State private var sortOrder = [SortDescriptor(\InventoryItem.title)]
    @State private var searchText = ""
    @State private var showingPaywall = false
    @State private var showingCamera = false
    @State private var showingImageAnalysis = false
    @State private var analyzingImage: UIImage?
    @State private var isContextValid = true
    
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
                        print("📱 InventoryListView - Add Item button tapped")
                        print("📱 InventoryListView - Settings.isPro: \(settings.isPro)")
                        print("📱 InventoryListView - Items count: \(allItems.count)")
                        print("📱 InventoryListView - Creating new item")
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
                    }) {
                        Label("Add Manually", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("createManually")
                    
                    Button(action: {
                        if settings.shouldShowPaywallForAiScan(currentCount: allItems.filter({ $0.hasUsedAI}).count) {
                            showingPaywall = true
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
                revenueCatManager.presentPaywall(
                    isPresented: $showingPaywall,
                    onCompletion: {
                        settings.isPro = true
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
                    },
                    onDismiss: nil
                )
            }
            .fullScreenCover(isPresented: $showingImageAnalysis) {
                if let image = analyzingImage {
                    ImageAnalysisView(image: image) {
                        showingImageAnalysis = false
                        analyzingImage = nil
                    }
                }
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
            .environmentObject(RevenueCatManager.shared)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
