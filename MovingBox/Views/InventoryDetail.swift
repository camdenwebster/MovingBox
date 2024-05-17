//
//  InventoryDetail.swift
//  MovingBox
//
//  Created by Camden Webster on 5/16/24.
//

import Foundation
import SwiftUI

struct InventoryDetail: View {
    @EnvironmentObject var inventoryData: InventoryData
//    @ObservedObject var inventoryItemToDisplay: InventoryItem
    @State private var imageDetailsFromOpenAI: ImageDetails = ImageDetails(title: "", quantity: "", description: "", make: "", model: "", category: "None", location: "None", price: "")
    @FocusState private var inputIsFocused: Bool
    @ObservedObject var inventoryItemToDisplay: InventoryItem    /* = InventoryItem()*/
    @State private var showingClearAllAlert = false
    @State private var isLoadingOpenAiResults: Bool = false

    var imageName: String = "adapter"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Enter item title", text: $inventoryItemToDisplay.title)
                        .focused($inputIsFocused)
                }
                Section("Quantity") {
//                    HStack {
//                        TextField("Quantity", text: $inventoryItemToDisplay.quantityString)
//                            .keyboardType(.numberPad)
//                            .onSubmit {
//                                inventoryItemToDisplay.validateQuantityInput()
//                            }
//                            .onChange(of: inventoryItemToDisplay.quantityString) {
//                                inventoryItemToDisplay.validateQuantityInput()
//                        }
                    Stepper("\(inventoryItemToDisplay.quantityInt)", value: $inventoryItemToDisplay.quantityInt, in: 1...1000, step: 1)
//                    }
    
                }
                Section("Description") {
                    TextEditor(text: $inventoryItemToDisplay.description)
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
                    Picker("Category:", selection: $inventoryItemToDisplay.category) {
                        ForEach(inventoryItemToDisplay.categories, id: \.self) {
                            Text($0)
                        }
                    }
                    Picker("Location:", selection: $inventoryItemToDisplay.location) {
                        ForEach(inventoryItemToDisplay.locations, id: \.self) {
                            Text($0)
                        }
                    }
                }
                Section("Notes") {
                    TextEditor(text: $inventoryItemToDisplay.notes)
                        .lineLimit(5)
                }
                Section {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    Button("Select Image", action: selectImage)
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
//            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoadingOpenAiResults {
                        ProgressView()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task {
                            await print(callOpenAI())
                        }
                    }) {
                        Image(systemName: "sparkles")
                    }
                    .disabled(isLoadingOpenAiResults ? true : false)
                }
            }
        }
    }
    
    func callOpenAI() async -> ImageDetails {
        isLoadingOpenAiResults = true
        print("Analyze Image button tapped")
        
        let imageEncoder = ImageEncoder(image: UIImage(imageLiteralResourceName: "adapter"))
        let imageBase64 = imageEncoder.encodeImageToBase64() ?? ""
        let openAi = OpenAIService(imageBase64: imageBase64)
        
        do {
            imageDetailsFromOpenAI = try await openAi.getImageDetails()
            inventoryItemToDisplay.title = imageDetailsFromOpenAI.title
            inventoryItemToDisplay.quantityString = imageDetailsFromOpenAI.quantity
            inventoryItemToDisplay.category = imageDetailsFromOpenAI.category.capitalized
            inventoryItemToDisplay.description = imageDetailsFromOpenAI.description
            inventoryItemToDisplay.make = imageDetailsFromOpenAI.make
            inventoryItemToDisplay.model = imageDetailsFromOpenAI.model
            inventoryItemToDisplay.location = imageDetailsFromOpenAI.location
            inventoryItemToDisplay.price = imageDetailsFromOpenAI.price

        } catch OpenAIError.invalidURL {
            print("Invalid URL")
        } catch OpenAIError.invalidResponse {
            print("Invalid Response")
        } catch OpenAIError.invalidData {
            print("Invalid Data")
        } catch {
            print("Unexpected Error")
        }
        isLoadingOpenAiResults = false
        return imageDetailsFromOpenAI
    }
    
    func selectImage() {
        print("Image selection button tapped")
    }
    
    func clearFields() {
        print("Clear fields button tapped")
        inventoryItemToDisplay.title = ""
        inventoryItemToDisplay.category = "None"
        inventoryItemToDisplay.description = ""
        inventoryItemToDisplay.make = ""
        inventoryItemToDisplay.model = ""
        inventoryItemToDisplay.location = "None"
        inventoryItemToDisplay.price = ""
    }
}

#Preview {
    InventoryDetail(inventoryItemToDisplay: InventoryItem())
        .environmentObject(InventoryData())
}
