//
//  InventoryDetail.swift
//  MovingBox
//
//  Created by Camden Webster on 5/16/24.
//

import PhotosUI
import SwiftData
import SwiftUI

struct InventoryDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
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
    @State private var showPhotoSourceAlert = false
    @State private var showPhotoPicker = false
    @State private var showingClearAllAlert = false
    @State private var isLoadingOpenAiResults = false
    @State private var isEditing: Bool
    @StateObject private var settings = SettingsManager()
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingCamera = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showAIButton = false
    @State private var showUnsavedChangesAlert = false
    @State private var showAIConfirmationAlert = false
    
    var showSparklesButton = false

    init(inventoryItemToDisplay: InventoryItem, navigationPath: Binding<NavigationPath>, showSparklesButton: Bool = false, isEditing: Bool = false) {
        self.inventoryItemToDisplay = inventoryItemToDisplay
        self._navigationPath = navigationPath
        self.showSparklesButton = showSparklesButton
        self._isEditing = State(initialValue: isEditing)
    }

    @FocusState private var focusedField: Field?
    
    private enum Field {
        case title
        case serial
        case make
        case model
        case description
        case notes
    }

    var body: some View {
        Form {
            Section {
                // Photo Section
                ZStack(alignment: .bottomTrailing) {
                    if let uiImage = inventoryItemToDisplay.photo {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width - 32)
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .clipped()
                        
                        if isEditing {
                            Button {
                                showPhotoSourceAlert = true
                            } label: {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Circle().fill(.black.opacity(0.6)))
                                    .padding(8)
                            }
                            .buttonStyle(.automatic)
                            .accessibilityIdentifier("changePhoto")
                        }
                    } else {
                        Button {
                            showPhotoSourceAlert = true
                        } label: {
                            VStack {
                                Image(systemName: "photo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 150, maxHeight: 150)
                                Text(isEditing ? "Tap to add a photo" : "No photo available")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .foregroundStyle(.secondary)
                            .background(Color(.systemBackground))
                        }
                        .buttonStyle(.automatic)
                        .disabled(!isEditing)
                        .accessibilityIdentifier("tapToAddPhoto")
                    }
                }
                .ignoresSafeArea(edges: .top)
                .listRowInsets(EdgeInsets())
            }

            // AI Button Section
            if isEditing && !inventoryItemToDisplay.hasUsedAI && (inventoryItemToDisplay.photo != nil) {
                Section {
                    Button {
                        guard !isLoadingOpenAiResults else { return }
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
                    } label: {
                        HStack {
                            if isLoadingOpenAiResults {
                                ProgressView()
                            } else {
                                Image(systemName: "sparkles")
                                Text("Analyze with AI")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundColor(.white)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.automatic)
                    .disabled(isLoadingOpenAiResults)
                    .accessibilityIdentifier("analyzeWithAi")
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .listRowBackground(Color.clear)
                .listSectionSpacing(16)
            }

            // Details Section
            Section("Details") {
                if isEditing || !inventoryItemToDisplay.title.isEmpty {
                    FormTextFieldRow(label: "Title", text: $inventoryItemToDisplay.title, placeholder: "Lamp")
                        .focused($focusedField, equals: .title)
                        .disabled(!isEditing)
                        .accessibilityIdentifier("titleField")
                }
                if isEditing || !inventoryItemToDisplay.serial.isEmpty {
                    FormTextFieldRow(label: "Serial Number", text: $inventoryItemToDisplay.serial, placeholder: "SN-12345")
                        .focused($focusedField, equals: .serial)
                        .disabled(!isEditing)
                        .accessibilityIdentifier("serialField")
                }
                if isEditing || !inventoryItemToDisplay.make.isEmpty {
                    FormTextFieldRow(label: "Make", text: $inventoryItemToDisplay.make, placeholder: "Apple")
                        .focused($focusedField, equals: .make)
                        .disabled(!isEditing)
                        .accessibilityIdentifier("makeField")
                }
                if isEditing || !inventoryItemToDisplay.model.isEmpty {
                    FormTextFieldRow(label: "Model", text: $inventoryItemToDisplay.model, placeholder: "Mac Mini")
                        .focused($focusedField, equals: .model)
                        .disabled(!isEditing)
                        .accessibilityIdentifier("modelField")
                }
            }
            if isEditing || inventoryItemToDisplay.quantityInt > 1 {
                Section("Quantity") {
                    Stepper("\(inventoryItemToDisplay.quantityInt)", value: $inventoryItemToDisplay.quantityInt, in: 1...1000, step: 1)
                        .disabled(!isEditing)
                }
            }
            if isEditing || !inventoryItemToDisplay.desc.isEmpty {
                Section("Description") {
                    TextEditor(text: $inventoryItemToDisplay.desc)
                        .focused($focusedField, equals: .description)
                        .frame(height: 60)
                        .disabled(!isEditing)
                        .accessibilityIdentifier("descriptionField")
                }
            }
            Section("Purchase Price") {
                PriceFieldRow(priceString: $priceString, priceDecimal: $inventoryItemToDisplay.price)
                    .disabled(!isEditing)
                    .accessibilityIdentifier("priceField")
                Toggle(isOn: $inventoryItemToDisplay.insured, label: {
                    Text("Insured")
                })
                .disabled(!isEditing)
                .accessibilityIdentifier("insuredToggle")
            }
            if isEditing || inventoryItemToDisplay.label != nil {
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
                .disabled(!isEditing)
                .accessibilityIdentifier("labelPicker")
                
                if isEditing {
                    Button("Add a new Label", action: addLabel)
                    .accessibilityIdentifier("addNewLabel")
                }
                }
            }
            if isEditing || inventoryItemToDisplay.location != nil {
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
                .disabled(!isEditing)
                .accessibilityIdentifier("locationPicker")
                
                if isEditing {
                    Button("Add a new Location", action: addLocation)
                    .accessibilityIdentifier("addNewLocation")
                }
                }
            }
            if isEditing || !inventoryItemToDisplay.notes.isEmpty {
                Section("Notes") {
                    TextEditor(text: $inventoryItemToDisplay.notes)
                .focused($focusedField, equals: .notes)
                .frame(height: 100)
                .disabled(!isEditing)
                .accessibilityIdentifier("notesField")
                }
            }
            if isEditing {
                Section {
                    Button("Clear All Fields") {
                        showingClearAllAlert = true
                    }
                .accessibilityIdentifier("clearAllFields")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarTitle(inventoryItemToDisplay.title == "" ? "New Item" : inventoryItemToDisplay.title)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button("Back") {
                        if modelContext.hasChanges {
                            showUnsavedChangesAlert = true
                        } else {
                            isEditing = false
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("backButton")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if inventoryItemToDisplay.hasUsedAI {
                    if showSparklesButton && isEditing {
                        Button(action: {
                            showAIConfirmationAlert = true
                        }) {
                            Image(systemName: "sparkles")
                        }
                        .disabled(isLoadingOpenAiResults)
                        .accessibilityIdentifier("sparkles")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isLoadingOpenAiResults && !showAIButton {
                    ProgressView()
                } else {
                    if isEditing {
                        Button("Save") {
                            if inventoryItemToDisplay.modelContext == nil {
                                modelContext.insert(inventoryItemToDisplay)
                            }
                            try? modelContext.save()
                            isEditing = false
                        }
                    .fontWeight(.bold)
                    .disabled(inventoryItemToDisplay.title.isEmpty || isLoadingOpenAiResults)
                    .accessibilityIdentifier("save")
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                        .accessibilityIdentifier("edit")
                    }
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { oldValue, newValue in
            Task {
                if let photo = newValue {
                    await loadPhoto(from: photo)
                    // Clear the selection after processing
                    selectedPhoto = nil
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image, needsAIAnalysis, completion in
                if let originalData = image.jpegData(compressionQuality: 1.0) {  // Save at full quality
                    Task { @MainActor in
                        inventoryItemToDisplay.data = originalData
                        inventoryItemToDisplay.hasUsedAI = false
                        try? modelContext.save()
                        completion()
                    }
                } else {
                    completion()
                }
            }
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
            Button("Take Photo") {
                showingCamera = true
            }
            .accessibilityIdentifier("takePhoto")
            
            Button("Choose from Library") {
                showPhotoPicker = true
            }
            .accessibilityIdentifier("chooseFromLibrary")
            
            if inventoryItemToDisplay.photo != nil {
                Button("Remove Photo", role: .destructive) {
                    inventoryItemToDisplay.data = nil
                }
                .accessibilityIdentifier("removePhoto")
            }
        }
        .alert("AI Analysis Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Are you sure?", isPresented: $showingClearAllAlert) {
            Button("Clear All Fields", role: .destructive) { clearFields() }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Save & Go Back", role: .none) {
                try? modelContext.save()
                isEditing = false
                dismiss()
            }
            
            Button("Discard Changes", role: .destructive) {
                modelContext.rollback()
                isEditing = false
                dismiss()
            }
            
            Button("Cancel", role: .cancel) {
                showUnsavedChangesAlert = false
            }
        } message: {
            Text("Do you want to save your changes before going back?")
        }
        .alert("AI Image Analysis", isPresented: $showAIConfirmationAlert) {
            Button("Analyze Image", role: .none) {
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
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will analyze the image using AI and update the following item details:\n\n• Title\n• Quantity\n• Description\n• Make\n• Model\n• Label\n• Location\n• Price\n\nExisting values will be overwritten. Do you want to proceed?")
        }
    }
    
    private struct TouchDownButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .contentShape(Rectangle())
        }
    }
    
    private func loadPhoto(from item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            await MainActor.run {
                inventoryItemToDisplay.data = data  // Save original data directly
                inventoryItemToDisplay.hasUsedAI = false
                try? modelContext.save()
            }
        }
    }
    
    func callOpenAI() async throws -> ImageDetails {
        isLoadingOpenAiResults = true
        defer { isLoadingOpenAiResults = false }
        
        guard let photo = inventoryItemToDisplay.photo else {
            print("❌ No photo available for analysis")
            throw OpenAIError.invalidData
        }
        
        guard let imageBase64 = PhotoManager.loadCompressedPhotoForAI(from: photo) else {
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
}

#Preview {
    do {
        let previewer = try Previewer()
        
        return InventoryDetailView(inventoryItemToDisplay: previewer.inventoryItem, navigationPath: .constant(NavigationPath()), isEditing: true)
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
