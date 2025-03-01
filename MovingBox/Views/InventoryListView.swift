//
//  InventoryListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import SwiftData
import SwiftUI
import AVFoundation

enum Options: Hashable {
    case destination(String)
}

struct InventoryListView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @State private var path = NavigationPath()
    @State private var sortOrder = [SortDescriptor(\InventoryItem.title)]
    @State private var searchText = ""
    let location: InventoryLocation
    @State private var showingApiKeyAlert = false
    @State private var showingCamera = false
    @State private var showingPermissionDenied = false
    @StateObject private var settings = SettingsManager()
    
    @Query(sort: [
        SortDescriptor(\InventoryLabel.name)
    ]) private var labels: [InventoryLabel]
    
    var body: some View {
        InventoryListSubView(location: location, searchString: searchText, sortOrder: sortOrder)
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: InventoryItem.self) { inventoryItem in EditInventoryItemView(inventoryItemToDisplay: inventoryItem, navigationPath: $path)
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
                Button("Add Item", systemImage: "plus") {
                    checkCameraPermissionsAndPresent()
                }
            }
            .searchable(text: $searchText)
            .sheet(isPresented: $showingCamera) {
                CameraView { image, needsAnalysis, completion in
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        let newInventoryItem = createNewItemWithPhoto(imageData: imageData)
                        
                        print("Starting AI image analysis after CameraView in InventoryListView")
                        if needsAnalysis {
                            Task {
                                let imageDetails = await callOpenAI(for: newInventoryItem)
                                await MainActor.run {
                                    print("Completed AI image analysis after CameraView")
                                    updateUIWithImageDetails(imageDetails, for: newInventoryItem)
                                    print("Finished updating image with details in InventoryListView, calling completion handler")
                                    completion()  
                                    print("Navigating to a new destination")
                                    router.navigate(to: .editInventoryItemView(item: newInventoryItem))
                                }
                            }
                        } else {
                            completion()  
                            router.navigate(to: .editInventoryItemView(item: newInventoryItem))
                        }
                    }
                }
            }
            .alert("Camera Access Required", isPresented: $showingPermissionDenied) {
                Button("Go to Settings", action: openSettings)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please grant camera access in Settings to use this feature.")
            }
            .alert("OpenAI API Key Required", isPresented: $showingApiKeyAlert) {
                Button("Go to Settings") {
                    router.navigate(to: .aISettingsView)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please configure your OpenAI API key in the settings to use this feature.")
            }
    }
    
    private func checkCameraPermissionsAndPresent() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        showingPermissionDenied = true
                    }
                }
            }
        default:
            showingPermissionDenied = true
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func createNewItemWithPhoto(imageData: Data) -> InventoryItem {
        let newInventoryItem = InventoryItem(
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
        
        // Set the photo data
        newInventoryItem.data = imageData
        modelContext.insert(newInventoryItem)
        try? modelContext.save()
        
        return newInventoryItem
    }
    
    private func callOpenAI(for item: InventoryItem) async -> ImageDetails {
        guard let photo = item.photo else {
            return ImageDetails(title: "", quantity: "", description: "", make: "", model: "", category: "", location: "", price: "")
        }
        
        let imageEncoder = ImageEncoder(image: photo)
        let imageBase64 = imageEncoder.encodeImageToBase64() ?? ""
        let openAi = OpenAIService(imageBase64: imageBase64, settings: settings)
        
        do {
            return try await openAi.getImageDetails()
        } catch {
            print("Error getting image details: \(error)")
            return ImageDetails(title: "", quantity: "", description: "", make: "", model: "", category: "", location: "", price: "")
        }
    }
    
    private func updateUIWithImageDetails(_ imageDetails: ImageDetails, for item: InventoryItem) {
        item.title = imageDetails.title
        item.quantityString = imageDetails.quantity
        item.label = labels.first { $0.name == imageDetails.category }
        item.desc = imageDetails.description
        item.make = imageDetails.make
        item.model = imageDetails.model
        
        // Convert price string to Decimal
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        if let priceDecimal = Decimal(string: priceString) {
            item.price = priceDecimal
        }
    }
    
    func editItems() {
        print("Edit button pressed")
    }
}

//#Preview {
//    do {
//        let previewer = try Previewer()
//        
//        InventoryListView(location: previewer.location)
//            .modelContainer(previewer.container)
//            .environmentObject(Router())
//    } catch {
//        Text("Preview Error: \(error.localizedDescription)")
//    }
//}
