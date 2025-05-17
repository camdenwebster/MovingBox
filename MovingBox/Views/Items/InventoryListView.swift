//
//  InventoryListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import RevenueCatUI
import SwiftData
import SwiftUI
import UIKit

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
    @State private var analyzedItemsCount = 0
    
    private struct AnalyzableImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    
    @State private var showingAnalysis: AnalyzableImage?
    
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
                
                Button {
                    router.navigate(to: .addItemView(location: location))
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
            }
            .searchable(text: $searchText, prompt: "Search items")
            .sheet(isPresented: $showingPaywall) {
                revenueCatManager.presentPaywall(
                    isPresented: $showingPaywall,
                    onCompletion: {
                        settings.isPro = true
                        router.navigate(to: .addItemView(location: location))
                    },
                    onDismiss: nil
                )
            }
            .sheet(item: $showingAnalysis) { wrapper in
                Group {
                    if settings.shouldShowPaywallForAiScan(currentCount: analyzedItemsCount) {
                        MovingBoxPaywallView()
                    } else {
                        ImageAnalysisView(images: [wrapper.image]) {
                            showingAnalysis = nil
                            processImageDetails()
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingImageAnalysis) {
                if let image = analyzingImage {
                    ImageAnalysisView(images: [image]) {
                        showingImageAnalysis = false
                        analyzingImage = nil
                    }
                }
            }
    }
    
    private func handlePhotoCaptured(_ image: UIImage) {
        showingAnalysis = AnalyzableImage(image: image)
    }
    
    func processImageDetails() {
        
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
