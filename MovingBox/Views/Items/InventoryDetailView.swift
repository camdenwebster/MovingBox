//
//  InventoryDetail.swift
//  MovingBox
//
//  Created by Camden Webster on 5/16/24.
//

import RevenueCatUI
import PhotosUI
import SwiftData
import SwiftUI

@MainActor
struct InventoryDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    
    @Query(sort: [
        SortDescriptor(\InventoryLabel.name)
    ]) var labels: [InventoryLabel]
    @FocusState private var isPriceFieldFocused: Bool
    @State private var displayPriceString: String = ""
    @State private var imageDetailsFromOpenAI: ImageDetails = ImageDetails(title: "", quantity: "", description: "", make: "", model: "", category: "None", location: "None", price: "")
    @FocusState private var inputIsFocused: Bool
    @Bindable var inventoryItemToDisplay: InventoryItem
    @Binding var navigationPath: NavigationPath
    @State private var showPhotoSourceAlert = false
    @State private var showPhotoPicker = false
    @State private var showingClearAllAlert = false
    @State private var isLoadingOpenAiResults = false
    @State private var isEditing: Bool
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingCamera = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showAIButton = false
    @State private var showUnsavedChangesAlert = false
    @State private var showAIConfirmationAlert = false
    @State private var showingPaywall = false
    @State private var tempUIImage: UIImage?
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadingError: Error?
    
    var showSparklesButton = false

    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared

    init(inventoryItemToDisplay: InventoryItem, navigationPath: Binding<NavigationPath>, showSparklesButton: Bool = false, isEditing: Bool = false) {
        self.inventoryItemToDisplay = inventoryItemToDisplay
        self._navigationPath = navigationPath
        self.showSparklesButton = showSparklesButton
        self._isEditing = State(initialValue: isEditing)
        self._displayPriceString = State(initialValue: formatInitialPrice(inventoryItemToDisplay.price))
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
                if let uiImage = tempUIImage ?? loadedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: UIScreen.main.bounds.width - 32)
                        .frame(height: UIScreen.main.bounds.height / 3)
                        .clipped()
                        .listRowInsets(EdgeInsets())
                        .overlay(alignment: .bottomTrailing) {
                            if isEditing {
                                photoButton
                            }
                        }
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.height / 3)
                } else {
                    if isEditing {
                        AddPhotoButton(action: {
                            showPhotoSourceAlert = true
                        })
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.height / 3)
                        .foregroundStyle(.secondary)
                        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
                            Button("Take Photo") {
                                showingCamera = true
                            }
                            .accessibilityIdentifier("takePhoto")
                            
                            Button("Choose from Library") {
                                showPhotoPicker = true
                            }
                            .accessibilityIdentifier("chooseFromLibrary")
                            
                            if tempUIImage != nil || loadedImage != nil {
                                Button("Remove Photo", role: .destructive) {
                                    inventoryItemToDisplay.imageURL = nil
                                    tempUIImage = nil
                                    loadedImage = nil
                                }
                                .accessibilityIdentifier("removePhoto")
                            }
                        }
                    }
                }
            }

            // AI Button Section
            if isEditing && !inventoryItemToDisplay.hasUsedAI && inventoryItemToDisplay.imageURL != nil {
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
                                Image(systemName: "wand.and.sparkles")
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
                    FormTextFieldRow(label: "Title", text: $inventoryItemToDisplay.title, isEditing: $isEditing, placeholder: "Desktop Computer")
                        .focused($focusedField, equals: .title)
                        .accessibilityIdentifier("titleField")
                }
                if isEditing || !inventoryItemToDisplay.serial.isEmpty {
                    FormTextFieldRow(label: "Serial Number", text: $inventoryItemToDisplay.serial, isEditing: $isEditing, placeholder: "SN-12345")
                        .focused($focusedField, equals: .serial)
                        .accessibilityIdentifier("serialField")
                }
                if isEditing || !inventoryItemToDisplay.make.isEmpty {
                    FormTextFieldRow(label: "Make", text: $inventoryItemToDisplay.make, isEditing: $isEditing, placeholder: "Apple")
                        .focused($focusedField, equals: .make)
                        .accessibilityIdentifier("makeField")
                }
                if isEditing || !inventoryItemToDisplay.model.isEmpty {
                    FormTextFieldRow(label: "Model", text: $inventoryItemToDisplay.model, isEditing: $isEditing, placeholder: "Mac Mini")
                        .focused($focusedField, equals: .model)
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
                        .foregroundColor(isEditing ? .primary : .secondary)
                }
            }
            Section("Purchase Price") {
                PriceFieldRow(
                    priceString: $displayPriceString,
                    priceDecimal: $inventoryItemToDisplay.price,
                    isEditing: $isEditing
                )
                .disabled(!isEditing)
                .accessibilityIdentifier("priceField")
                .foregroundColor(isEditing ? .primary : .secondary)
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
                        .foregroundColor(isEditing ? .primary : .secondary)
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
                if isEditing && OnboardingManager.hasCompletedOnboarding() {
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
                            if settings.shouldShowPaywallForAI() {
                                showingPaywall = true
                            } else {
                                showAIConfirmationAlert = true
                            }
                        }) {
                            Image(systemName: "wand.and.sparkles")
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
                            dismiss()
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
        .sheet(isPresented: $showingCamera) {
            CameraView(
                showingImageAnalysis: .constant(false),
                analyzingImage: .constant(nil)
            ) { image, needsAIAnalysis, completion async -> Void in
                if inventoryItemToDisplay.modelContext == nil {
                    tempUIImage = image
                } else {
                    let id = UUID().uuidString
                    if let imageURL = try? await OptimizedImageManager.shared.saveImage(image, id: id) {
                        inventoryItemToDisplay.imageURL = imageURL
                        loadedImage = image
                    }
                }
                await completion()
            }
        }
        .sheet(isPresented: $showingPaywall) {
            revenueCatManager.presentPaywall(
                isPresented: $showingPaywall,
                onCompletion: {
                    settings.isPro = true
                    // Add any specific post-purchase actions here
                },
                onDismiss: nil
            )
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .task(id: inventoryItemToDisplay.imageURL) {
            guard inventoryItemToDisplay.modelContext != nil else { return }
            isLoading = true
            defer { isLoading = false }
            
            do {
                loadedImage = try await inventoryItemToDisplay.loadPhoto()
            } catch {
                loadingError = error
                print("Failed to load image: \(error)")
            }
        }
        .task {
            if let photo = selectedPhoto {
                await loadPhoto(from: photo)
                selectedPhoto = nil
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
    
    private var photoButton: some View {
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
        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
            Button("Take Photo") {
                showingCamera = true
            }
            .accessibilityIdentifier("takePhoto")
            
            Button("Choose from Library") {
                showPhotoPicker = true
            }
            .accessibilityIdentifier("chooseFromLibrary")
            
            if tempUIImage != nil || loadedImage != nil {
                Button("Remove Photo", role: .destructive) {
                    inventoryItemToDisplay.imageURL = nil
                    tempUIImage = nil
                    loadedImage = nil
                }
                .accessibilityIdentifier("removePhoto")
            }
        }
    }
    
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                let id = UUID().uuidString
                if inventoryItemToDisplay.modelContext == nil {
                    tempUIImage = uiImage
                } else {
                    if let imageURL = try? await OptimizedImageManager.shared.saveImage(uiImage, id: id) {
                        inventoryItemToDisplay.imageURL = imageURL
                        loadedImage = uiImage
                    }
                }
                try? modelContext.save()
            }
        } catch {
            loadingError = error
            print("Failed to load photo: \(error)")
        }
    }
    
    private func callOpenAI() async throws -> ImageDetails {
        isLoadingOpenAiResults = true
        defer { isLoadingOpenAiResults = false }
        
        guard let photo = try await inventoryItemToDisplay.loadPhoto() else {
            throw OpenAIError.invalidData
        }
        
        guard let imageBase64 = OptimizedImageManager.shared.prepareImageForAI(from: photo) else {
            throw OpenAIError.invalidData
        }
        
        let openAi = OpenAIService(imageBase64: imageBase64, settings: settings, modelContext: modelContext)
        
        TelemetryManager.shared.trackCameraAnalysisUsed()
        
        return try await openAi.getImageDetails()
    }
    
    private func updateUIWithImageDetails(_ imageDetails: ImageDetails) {
        if inventoryItemToDisplay.modelContext == nil {
            modelContext.insert(inventoryItemToDisplay)
        }
        
        inventoryItemToDisplay.title = imageDetails.title
        inventoryItemToDisplay.quantityString = imageDetails.quantity
        inventoryItemToDisplay.label = labels.first { $0.name == imageDetails.category }
        inventoryItemToDisplay.desc = imageDetails.description
        inventoryItemToDisplay.make = imageDetails.make
        inventoryItemToDisplay.model = imageDetails.model
        
        if inventoryItemToDisplay.location == nil {
            inventoryItemToDisplay.location = locations.first { $0.name == imageDetails.location }
        }
        
        // Update price handling
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        if let price = Decimal(string: priceString) {
            inventoryItemToDisplay.price = price
            displayPriceString = formatInitialPrice(price)
        }
        
        inventoryItemToDisplay.hasUsedAI = true
        
        try? modelContext.save()
    }
    
    private func selectImage() {
        print("Image selection button tapped")
    }
    
    private func clearFields() {
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
    
    private func addLocation() {
        let location = InventoryLocation()
        modelContext.insert(location)
        TelemetryManager.shared.trackLocationCreated(name: location.name)
        inventoryItemToDisplay.location = location
        router.navigate(to: .editLocationView(location: location))
    }
    
    private func addLabel() {
        let label = InventoryLabel()
        inventoryItemToDisplay.label = label
        router.navigate(to: .editLabelView(label: label))
    }
    
    private func formatInitialPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "0.00"
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return InventoryDetailView(inventoryItemToDisplay: previewer.inventoryItem, navigationPath: .constant(NavigationPath()), isEditing: true)
            .modelContainer(previewer.container)
            .environmentObject(Router())
            .environmentObject(SettingsManager())
            .environmentObject(OnboardingManager())
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
