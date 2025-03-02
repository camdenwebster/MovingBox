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
    @FocusState private var isPriceFieldFocused: Bool
    @State private var priceString = ""
    @State private var imageDetailsFromOpenAI: ImageDetails = ImageDetails(title: "", quantity: "", description: "", make: "", model: "", category: "None", location: "None", price: "")
    @FocusState private var inputIsFocused: Bool
    @Bindable var inventoryItemToDisplay: InventoryItem
    @Binding var navigationPath: NavigationPath
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingClearAllAlert = false
    @State private var isLoadingOpenAiResults: Bool = false
    @StateObject private var settings = SettingsManager()
    @State private var showingApiKeyAlert = false
    @State private var showingCamera = false
    
    var showSparklesButton = false

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter.currencySymbol
    }
    
    private func formattedPriceString(_ input: String) -> String {
        // Filter out non-numeric characters
        let numericString = input.filter { $0.isNumber }
        
        if numericString.isEmpty {
            return ""
        }
        
        // Convert to a Decimal amount (divide by 100 to place decimal point)
        let amountValue = Decimal(string: numericString) ?? 0
        let amount = amountValue / 100
        
        // Format with 2 decimal places
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? ""
    }

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
                // Price field
                HStack {
                    Text("Price")
                    Spacer()
                    HStack(spacing: 0) {
                        Text(currencySymbol)
                            .foregroundStyle(.secondary)
                        TextField("", text: $priceString)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .focused($isPriceFieldFocused)
                            .frame(minWidth: 60, maxWidth: 75, alignment: .trailing)
                            .onChange(of: priceString) { oldValue, newValue in
                                // Filter and allow only numbers
                                let filteredValue = newValue.filter { $0.isNumber }
                                
                                // If the user changed the string and it doesn't match our filtered value
                                if newValue != filteredValue {
                                    priceString = filteredValue
                                }
                                
                                // Format for display with decimal point
                                let formattedValue = formattedPriceString(filteredValue)
                                
                                // Only update the UI if we have a valid format and it's different
                                if !formattedValue.isEmpty && formattedValue != priceString {
                                    priceString = formattedValue
                                }
                                
                                // Update the actual Decimal value for storage
                                if !filteredValue.isEmpty {
                                    let numericString = filteredValue
                                    if let decimalValue = Decimal(string: numericString) {
                                        inventoryItemToDisplay.price = decimalValue / 100
                                    }
                                } else {
                                    inventoryItemToDisplay.price = 0
                                }
                            }
                            .overlay(
                                Group {
                                    if priceString.isEmpty && !isPriceFieldFocused {
                                        Text("0.00")
                                            .foregroundColor(.gray)
                                            .allowsHitTesting(false)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                            )
                    }
                    .frame(maxWidth: 120, alignment: .trailing)
                }
                .onAppear {
                    // Convert to integer by multiplying by 100 and rounding properly
                    let scaledValue = inventoryItemToDisplay.price * Decimal(100)
                    let intValue = Int(NSDecimalNumber(decimal: scaledValue).rounding(accordingToBehavior: nil).intValue)
                    priceString = formattedPriceString(String(intValue))
                }
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
        .navigationTitle(inventoryItemToDisplay.title == "" ? "New Item" : inventoryItemToDisplay.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto, loadPhoto)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoadingOpenAiResults {
                    ProgressView()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                // TODO: Add toolbar menu with option to use high detail image analysis if settings.isHighDetail is true
                if showSparklesButton {
                    Button(action: {
                        if settings.apiKey.isEmpty {
                            showingApiKeyAlert = true
                        } else {
                            Task {
                                let imageDetails = await callOpenAI()
                                updateUIWithImageDetails(imageDetails)
                            }
                        }
                    }) {
                        Image(systemName: "sparkles")
                    }
                    .disabled(isLoadingOpenAiResults ? true : false)
                } else {
                    EmptyView()
                }
            }
        }
        .alert("OpenAI API Key Required", isPresented: $showingApiKeyAlert) {
            Button("Go to Settings") {
                router.navigate(to: .aISettingsView)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please configure your OpenAI API key in the settings to use this feature.")
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image, needsAnalysis, completion in
                let imageEncoder = ImageEncoder(image: image)
                if let optimizedImage = imageEncoder.optimizeImage(),
                   let imageData = optimizedImage.jpegData(compressionQuality: 0.5) {
                    inventoryItemToDisplay.data = imageData
                    modelContext.insert(inventoryItemToDisplay)
                    try? modelContext.save()
                    
                    if needsAnalysis && !settings.apiKey.isEmpty {
                        Task {
                            print("Starting AI image analysis after CameraView in EditInventoryView")
                            let imageDetails = await callOpenAI()
                            print("Finishing AI image analysis after CameraView in EditInventoryView")
                            await MainActor.run {
                                updateUIWithImageDetails(imageDetails)
                                print("Finished updating image with details in EditInventoryView, calling completion handler")
                                completion()
                            }
                        }
                    } else {
                        completion()
                    }
                }
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
        let openAi = OpenAIService(imageBase64: imageBase64, settings: settings, modelContext: modelContext)
        
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
        // Begin a write transaction
        modelContext.insert(inventoryItemToDisplay)
        
        // Update properties
        inventoryItemToDisplay.title = imageDetails.title
        inventoryItemToDisplay.quantityString = imageDetails.quantity
        inventoryItemToDisplay.label = labels.first { $0.name == imageDetails.category }
        inventoryItemToDisplay.desc = imageDetails.description
        inventoryItemToDisplay.make = imageDetails.make
        inventoryItemToDisplay.model = imageDetails.model
        inventoryItemToDisplay.location = locations.first { $0.name == imageDetails.location }
        
        // Convert price string to Decimal
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        inventoryItemToDisplay.price = Decimal(string: priceString) ?? 0
        
        // Explicitly save changes
        try? modelContext.save()
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
        inventoryItemToDisplay.price = 0
        inventoryItemToDisplay.notes = ""
    }
    
    func addLocation() {
        let location = InventoryLocation(name: "", desc: "")
        modelContext.insert(location)
        inventoryItemToDisplay.location = location
        router.navigate(to: .editLocationView(location: location))
    }
    
    func addLabel() {
        let label = InventoryLabel()
        modelContext.insert(label)
        inventoryItemToDisplay.label = label
        router.navigate(to: .editLabelView(label: label))
    }
    
    func loadPhoto() {
        Task { @MainActor in
            if let data = try await selectedPhoto?.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let imageEncoder = ImageEncoder(image: image)
                if let optimizedImage = imageEncoder.optimizeImage(),
                   let optimizedData = optimizedImage.jpegData(compressionQuality: 0.5) {
                    inventoryItemToDisplay.data = optimizedData
                    modelContext.insert(inventoryItemToDisplay)
                    try? modelContext.save()
                }
            }
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
