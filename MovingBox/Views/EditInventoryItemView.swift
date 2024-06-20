//
//  InventoryDetail.swift
//  MovingBox
//
//  Created by Camden Webster on 5/16/24.
//

import PhotosUI
import SwiftData
import SwiftUI

struct EditInventoryItemView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    
    @Query(sort: [
        SortDescriptor(\InventoryLabel.name)
    ]) var labels: [InventoryLabel]
    
    @State private var imageDetailsFromOpenAI: ImageDetails = ImageDetails(title: "", quantity: "", description: "", make: "", model: "", category: "None", location: "None", price: "")
    @FocusState private var inputIsFocused: Bool
    @Bindable var inventoryItemToDisplay: InventoryItem
    @Binding var navigationPath: NavigationPath
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingClearAllAlert = false
    @State private var isLoadingOpenAiResults: Bool = false

    var imageName: String = "adapter"
    
    var body: some View {
        Form {
            Section {
                if let uiImage = inventoryItemToDisplay.photo {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Select Image", systemImage: "photo")
                }
            }
            Section("Title") {
                TextField("Enter item title", text: $inventoryItemToDisplay.title)
                    .focused($inputIsFocused)
            }
            Section("Quantity") {
                Stepper("\(inventoryItemToDisplay.quantityInt)", value: $inventoryItemToDisplay.quantityInt, in: 1...1000, step: 1)
            }
            Section("Description") {
                TextEditor(text: $inventoryItemToDisplay.desc)
                    .lineLimit(5)
            }
            Section("Manufacturer and Model") {
                TextField("Manufacturer", text: $inventoryItemToDisplay.make)
                TextField("Model", text: $inventoryItemToDisplay.model)
            }
            Section("Serial Number") {
                TextField("Serial Number", text: $inventoryItemToDisplay.serial)
            }
            Section("Purchase Price") {
                TextField("Price", text: $inventoryItemToDisplay.price)
                Toggle(isOn: $inventoryItemToDisplay.insured, label: {
                    Text("Insured")
                })
            }
            Section {
                Picker("Label", selection: $inventoryItemToDisplay.label) {
                    Text("None")
                        .tag(Optional<InventoryLabel>.none)
                    
                    if labels.isEmpty == false {
                        Divider()
                        ForEach(labels) { label in
                            Text(label.name)
                                .tag(Optional(label))
                        }
                    }
                    
                }
                Button("Add a new Label", action: addLabel)
            }
            Section {
                Picker("Location", selection: $inventoryItemToDisplay.location) {
                    Text("None")
                        .tag(Optional<InventoryLocation>.none)
                    
                    if locations.isEmpty == false {
                        Divider()
                        ForEach(locations) { location in
                            Text(location.name)
                                .tag(Optional(location))
                        }
                    }
                }
                Button("Add a new Location", action: addLocation)
            }
            Section("Notes") {
                TextEditor(text: $inventoryItemToDisplay.notes)
                    .lineLimit(5)
            }
            Section {
                Button("Clear All Fields") {
                    showingClearAllAlert = true
                }
            }
            .alert("Are you sure?", isPresented: $showingClearAllAlert) {
                Button("Clear All Fields", role: .destructive) { clearFields() }
                Button("Cancel", role: .cancel) { }
            }
        }
        .navigationTitle(inventoryItemToDisplay.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto, loadPhoto)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoadingOpenAiResults {
                    ProgressView()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    Task {
                        let imageDetails = await callOpenAI()
                        updateUIWithImageDetails(imageDetails)
                    }
                }) {
                    Image(systemName: "sparkles")
                }
                .disabled(isLoadingOpenAiResults ? true : false)
            }
        }
    }
    
    func callOpenAI() async -> ImageDetails {
        isLoadingOpenAiResults = true
        guard let photo = inventoryItemToDisplay.photo else {
            return ImageDetails(title: "", quantity: "", description: "", make: "", model: "", category: "", location: "", price: "")
        }
        let imageEncoder = ImageEncoder(image: photo)
        let imageBase64 = imageEncoder.encodeImageToBase64() ?? ""
        let openAi = OpenAIService(imageBase64: imageBase64)
        
        print("Analyze Image button tapped")

        do {
            imageDetailsFromOpenAI = try await openAi.getImageDetails()
            isLoadingOpenAiResults = false

        } catch OpenAIError.invalidURL {
            print("Invalid URL")
        } catch OpenAIError.invalidResponse {
            print("Invalid Response")
        } catch OpenAIError.invalidData {
            print("Invalid Data")
        } catch {
            print("Unexpected Error")
        }
        return imageDetailsFromOpenAI
    }
    
    func updateUIWithImageDetails(_ imageDetails: ImageDetails) {
        inventoryItemToDisplay.title = imageDetails.title
        inventoryItemToDisplay.quantityString = imageDetails.quantity
        inventoryItemToDisplay.label = labels.first { $0.name == imageDetails.category }
        inventoryItemToDisplay.desc = imageDetails.description
        inventoryItemToDisplay.make = imageDetails.make
        inventoryItemToDisplay.model = imageDetails.model
        inventoryItemToDisplay.location = locations.first { $0.name == imageDetails.location }
        inventoryItemToDisplay.price = imageDetails.price
    }
    
    func selectImage() {
        print("Image selection button tapped")
    }
    
    func clearFields() {
        print("Clear fields button tapped")
        inventoryItemToDisplay.title = ""
        inventoryItemToDisplay.label = nil
        inventoryItemToDisplay.desc = ""
        inventoryItemToDisplay.make = ""
        inventoryItemToDisplay.model = ""
        inventoryItemToDisplay.location = nil
        inventoryItemToDisplay.price = ""
        inventoryItemToDisplay.notes = ""
    }
    
    func addLocation() {
        let location = InventoryLocation(id: UUID().uuidString, name: "", desc: "")
        modelContext.insert(location)
        inventoryItemToDisplay.location = location
        router.navigate(to: .editLocationView(location: location))
    }
    
    func addLabel() {
        let label = InventoryLabel(id: UUID().uuidString, name: "", desc: "")
        modelContext.insert(label)
        inventoryItemToDisplay.label = label
        router.navigate(to: .editLabelView(label: label))
    }
    
    func loadPhoto() {
        Task { @MainActor in
            inventoryItemToDisplay.data = try await selectedPhoto?.loadTransferable(type: Data.self)
        }
    }
}


#Preview {
    do {
        let previewer = try Previewer()
        
        return EditInventoryItemView(inventoryItemToDisplay: previewer.inventoryItem, navigationPath: .constant(NavigationPath()))
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}

