//
//  ContentView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import SwiftUI

struct ContentView: View {

    @State private var imageDetailsFromOpenAI: ImageDetails = ImageDetails(title: "", description: "", make: "", model: "", category: "None")

    @FocusState private var inputIsFocused: Bool
    @StateObject private var inventoryItemToDisplay = InventoryItem()
//    @State private var title: String = ""
//    @State private var quantity: String = "1"
//    @State private var description: String = ""
//    @State private var serial: String = ""
//    @State private var manufacturer: String = ""
//    @State private var model: String = ""
//    @State private var notes: String = ""
//    @State private var location: String = "None"
//    @State private var category: String = "Electronics"
//    @State private var assetId: String = ""
//    @State private var insured: Bool = false

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
                Section("Details") {
                    TextField("Manufacturer", text: $inventoryItemToDisplay.make)
                    TextField("Model", text: $inventoryItemToDisplay.model)
                    TextField("Serial Number", text: $inventoryItemToDisplay.serial)
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
                    Button("Clear All Fields", action: clearFields)
                }
    //
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(action: {
                    Task {
                        await print(callOpenAI())
                    }
                }) {
                    Image(systemName: "sparkles")
                }
            }
        }
    }
    
    func callOpenAI() async -> ImageDetails {
        print("Analyze Image button tapped")
        
        let imageEncoder = ImageEncoder(image: UIImage(imageLiteralResourceName: "adapter"))
        let imageBase64 = imageEncoder.encodeImageToBase64() ?? ""
        let openAi = OpenAIService(imageBase64: imageBase64)
        
        do {
            imageDetailsFromOpenAI = try await openAi.getImageDetails()
            inventoryItemToDisplay.title = imageDetailsFromOpenAI.title
            inventoryItemToDisplay.category = imageDetailsFromOpenAI.category.capitalized
            inventoryItemToDisplay.description = imageDetailsFromOpenAI.description
            inventoryItemToDisplay.make = imageDetailsFromOpenAI.make
            inventoryItemToDisplay.model = imageDetailsFromOpenAI.model


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
    
    func selectImage() {
        print("Image selection button tapped")
    }
    
    func clearFields() {
        print("Clear fields button tapped")
        inventoryItemToDisplay.title = ""
        inventoryItemToDisplay.category = ""
        inventoryItemToDisplay.description = ""
        inventoryItemToDisplay.make = ""
        inventoryItemToDisplay.model = ""
    }
}

#Preview {
    ContentView()
}
