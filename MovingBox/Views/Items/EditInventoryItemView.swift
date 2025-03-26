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
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingCamera = false
    
    var showSparklesButton = false


    var body: some View {
        Form {
            // Photo banner section
            Section {
                VStack(spacing: 0) {
                    if let uiImage = inventoryItemToDisplay.photo {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                    } else {
                        VStack {
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 150, maxHeight: 150)
                                .foregroundStyle(.secondary)
                            Text("Add a photo to get started")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.height / 3)
                        .foregroundStyle(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets())
            }
            .listSectionSpacing(16)
            
            // Add "Analyze with AI" button here if analysis has not happened yet and there is a photo
            Section {
                if inventoryItemToDisplay.hasUsedAI == false && (inventoryItemToDisplay.photo != nil) {
                    HStack(spacing: 16) {
                        Button(action: {
                            Task {
                                do {
                                    let imageDetails = try await callOpenAI()
                                    updateUIWithImageDetails(imageDetails)
                                } catch OpenAIError.invalidURL {
                                    errorMessage = "Invalid URL configuration"
                                    showingErrorAlert = true
                                } catch OpenAIError.invalidResponse {
                                    errorMessage = "Error communicating with AI service"
                                    showingErrorAlert = true
                                } catch OpenAIError.invalidData {
                                    errorMessage = "Unable to process AI response"
                                    showingErrorAlert = true
                                } catch {
                                    errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                                    showingErrorAlert = true
                                }
                            }
                        }) {
                            Label("Analyze with AI", systemImage: "sparkles")
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.bordered)
                    }
                    .listRowBackground(Color.clear)
                    .background(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .listSectionSpacing(16)
            
            Section {
                HStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title)
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        showingCamera = true
                    } label: {
                        HStack {
                            Image(systemName: "camera")
                                .font(.title)
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                }
                .listRowBackground(Color.clear)
                .background(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("Details") {
                FormTextFieldRow(label: "Title", text: $inventoryItemToDisplay.title, placeholder: "Lamp")
                FormTextFieldRow(label: "Serial Number", text: $inventoryItemToDisplay.serial, placeholder: "SN-12345")
                FormTextFieldRow(label: "Make", text: $inventoryItemToDisplay.make, placeholder: "Apple")
                FormTextFieldRow(label: "Model", text: $inventoryItemToDisplay.model, placeholder: "Mac Mini")
            }
            Section("Quantity") {
                Stepper("\(inventoryItemToDisplay.quantityInt)", value: $inventoryItemToDisplay.quantityInt, in: 1...1000, step: 1)
            }
            Section("Description") {
                TextEditor(text: $inventoryItemToDisplay.desc)
                    .lineLimit(5)
            }
            Section("Purchase Price") {
                PriceFieldRow(priceString: $priceString, priceDecimal: $inventoryItemToDisplay.price)
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
                if inventoryItemToDisplay.hasUsedAI {
                    if showSparklesButton  {
                        Button(action: {
                            Task {
                                do {
                                    let imageDetails = try await callOpenAI()
                                    updateUIWithImageDetails(imageDetails)
                                } catch let error as OpenAIError {
                                    errorMessage = error.userFriendlyMessage
                                    showingErrorAlert = true
                                } catch {
                                    errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                                    showingErrorAlert = true
                                }
                            }
                        }) {
                            Image(systemName: "sparkles")
                        }
                        .disabled(isLoadingOpenAiResults)
                    }
                } else {
                    EmptyView()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isLoadingOpenAiResults {
                    ProgressView()
                } else {
                    Button("Save") {
                        if inventoryItemToDisplay.modelContext == nil {
                            modelContext.insert(inventoryItemToDisplay)
                        }
                        try? modelContext.save()
                        navigationPath.removeLast()
                    }
                    .fontWeight(.bold)
                    .disabled(inventoryItemToDisplay.title.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image, needsAnalysis, completion in
                let imageEncoder = ImageEncoder(image: image)
                if let optimizedImage = imageEncoder.optimizeImage(),
                   let imageData = optimizedImage.jpegData(compressionQuality: 0.3) {
                    inventoryItemToDisplay.data = imageData
                    try? modelContext.save()
                    
                    if needsAnalysis {
                        Task {
                            print("Starting AI image analysis after CameraView in EditInventoryView")
                            do {
                                let imageDetails = try await callOpenAI()
                                print("Finishing AI image analysis after CameraView in EditInventoryView")
                                await MainActor.run {
                                    updateUIWithImageDetails(imageDetails)
                                    print("Finished updating image with details in EditInventoryView, calling completion handler")
                                    completion()
                                }
                            } catch let error as OpenAIError {
                                await MainActor.run {
                                    errorMessage = error.userFriendlyMessage
                                    showingErrorAlert = true
                                    completion()
                                }
                            } catch {
                                await MainActor.run {
                                    errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                                    showingErrorAlert = true
                                    completion()
                                }
                            }
                        }
                    } else {
                        completion()
                    }
                }
            }
        }
        .alert("AI Analysis Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    func callOpenAI() async throws -> ImageDetails {
        isLoadingOpenAiResults = true
        defer { isLoadingOpenAiResults = false }
        
        guard let photo = inventoryItemToDisplay.photo else {
            print("❌ No photo available for analysis")
            throw OpenAIError.invalidData
        }
        
        let imageEncoder = ImageEncoder(image: photo)
        guard let imageBase64 = imageEncoder.encodeImageToBase64() else {
            print("❌ Failed to encode image to base64")
            throw OpenAIError.invalidData
        }
        
        let openAi = OpenAIService(imageBase64: imageBase64, settings: settings, modelContext: modelContext)
        
        TelemetryManager.shared.trackCameraAnalysisUsed()
        print("🔍 Starting image analysis")
        
        return try await openAi.getImageDetails()
    }
    
    func updateUIWithImageDetails(_ imageDetails: ImageDetails) {
        if inventoryItemToDisplay.modelContext == nil {
            modelContext.insert(inventoryItemToDisplay)
        }
        
        // Update properties
        inventoryItemToDisplay.title = imageDetails.title
        inventoryItemToDisplay.quantityString = imageDetails.quantity
        inventoryItemToDisplay.label = labels.first { $0.name == imageDetails.category }
        inventoryItemToDisplay.desc = imageDetails.description
        inventoryItemToDisplay.make = imageDetails.make
        inventoryItemToDisplay.model = imageDetails.model
        inventoryItemToDisplay.location = locations.first { $0.name == imageDetails.location }
        inventoryItemToDisplay.hasUsedAI = true  // Add this line to mark AI usage
        
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
        let location = InventoryLocation()
        modelContext.insert(location)
        TelemetryManager.shared.trackLocationCreated(name: location.name)
        inventoryItemToDisplay.location = location
        router.navigate(to: .editLocationView(location: location))
    }
    
    func addLabel() {
        let label = InventoryLabel()
        modelContext.insert(label)
        TelemetryManager.shared.trackLabelCreated(name: label.name)
        inventoryItemToDisplay.label = label
        router.navigate(to: .editLabelView(label: label))
    }
    
    private func loadPhoto() {
        Task {
            await PhotoManager.loadAndSavePhoto(from: selectedPhoto, to: inventoryItemToDisplay)
            try? modelContext.save()
            TelemetryManager.shared.trackInventoryItemAdded(name: inventoryItemToDisplay.title)
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
