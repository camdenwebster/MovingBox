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
    @Query private var allItems: [InventoryItem]
    @FocusState private var isPriceFieldFocused: Bool
    @State private var displayPriceString: String = ""
    @State private var imageDetailsFromOpenAI: ImageDetails = ImageDetails(title: "", quantity: "", description: "", make: "", model: "", category: "None", location: "None", price: "", serialNumber: "")
    @FocusState private var inputIsFocused: Bool
    @Bindable var inventoryItemToDisplay: InventoryItem
    @Binding var navigationPath: NavigationPath
    @State private var showingClearAllAlert = false
    @State private var isLoadingOpenAiResults = false
    @State private var isEditing: Bool
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showAIButton = false
    @State private var showUnsavedChangesAlert = false
    @State private var showAIConfirmationAlert = false
    @State private var showingPaywall = false
    @State private var tempUIImage: UIImage?
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadingError: Error?
    @State private var showingMultiPhotoCamera = false
    @State private var capturedImages: [UIImage] = []
    @State private var loadedImages: [UIImage] = []
    @State private var selectedImageIndex: Int = 0
    
    var showSparklesButton = false

    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared

    var onSave: (() -> Void)?

    init(inventoryItemToDisplay: InventoryItem,
         navigationPath: Binding<NavigationPath>,
         showSparklesButton: Bool = false,
         isEditing: Bool = false,
         onSave: (() -> Void)? = nil) {
        self.inventoryItemToDisplay = inventoryItemToDisplay
        self._navigationPath = navigationPath
        self.showSparklesButton = showSparklesButton
        self._isEditing = State(initialValue: isEditing)
        self._displayPriceString = State(initialValue: formatInitialPrice(inventoryItemToDisplay.price))
        self.onSave = onSave
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
            // Primary Photo Section
            if inventoryItemToDisplay.imageURL != nil || !inventoryItemToDisplay.secondaryPhotoURLs.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        if !loadedImages.isEmpty && selectedImageIndex < loadedImages.count {
                            Image(uiImage: loadedImages[selectedImageIndex])
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            
            // Thumbnails Section
            if inventoryItemToDisplay.imageURL != nil || !inventoryItemToDisplay.secondaryPhotoURLs.isEmpty || isEditing {
                Section {
                    HorizontalPhotoScrollView(
                        item: inventoryItemToDisplay,
                        isEditing: isEditing,
                        onAddPhoto: {
                            let currentPhotoCount = (inventoryItemToDisplay.imageURL != nil ? 1 : 0) + inventoryItemToDisplay.secondaryPhotoURLs.count
                            if currentPhotoCount < 5 {
                                showingMultiPhotoCamera = true
                            }
                        },
                        onDeletePhoto: { urlString in
                            Task {
                                await deletePhoto(urlString: urlString)
                            }
                        },
                        showOnlyThumbnails: true,
                        onThumbnailTap: { index in
                            selectedImageIndex = index
                        }
                    )
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            
            // AI Button Section
            if isEditing && !inventoryItemToDisplay.hasUsedAI && inventoryItemToDisplay.imageURL != nil {
                Section {
                    Button {
                        guard !isLoadingOpenAiResults else { return }
                        if settings.shouldShowPaywallForAiScan(currentCount: allItems.filter({ $0.hasUsedAI}).count) {
                            showingPaywall = true
                        } else {
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
            Section("Locations & Labels") {
                if isEditing || inventoryItemToDisplay.location != nil {
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
                }
                if isEditing || inventoryItemToDisplay.label != nil {
                        Picker("Label", selection: $inventoryItemToDisplay.label) {
                            Text("None")
                                .tag(Optional<InventoryLabel>.none)
                            
                            if labels.isEmpty == false {
                                Divider()
                                ForEach(labels) { label in
                                    Text("\(label.emoji) \(label.name)")
                                    .tag(Optional(label))
                                }
                            }
                        }
                    .disabled(!isEditing)
                    .accessibilityIdentifier("labelPicker")
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
        .navigationTitle(inventoryItemToDisplay.title.isEmpty ? "New Item" : inventoryItemToDisplay.title)
        .navigationBarTitleDisplayMode(.inline)
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
                            if settings.shouldShowPaywallForAiScan(currentCount: allItems.filter({ $0.hasUsedAI}).count) {
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
                            onSave?()
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
        .sheet(isPresented: $showingMultiPhotoCamera) {
            let currentPhotoCount = (inventoryItemToDisplay.imageURL != nil ? 1 : 0) + inventoryItemToDisplay.secondaryPhotoURLs.count
            let maxPhotosToAdd = max(1, 5 - currentPhotoCount)
            CustomCameraView(
                capturedImages: $capturedImages,
                mode: .multiPhoto(maxPhotos: maxPhotosToAdd),
                onPermissionCheck: { granted in
                    if !granted {
                        // Handle permission denied
                        print("Camera permission denied")
                    }
                },
                onComplete: { images in
                    Task {
                        await handleNewPhotos(images)
                        showingMultiPhotoCamera = false
                    }
                },
                onCancel: {
                    showingMultiPhotoCamera = false
                }
            )
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
        .task(id: inventoryItemToDisplay.imageURL) {
            await loadAllImages()
        }
        .onChange(of: inventoryItemToDisplay.secondaryPhotoURLs) { _, _ in
            Task {
                await loadAllImages()
            }
        }
    }

    private func callOpenAI() async throws -> ImageDetails {
        isLoadingOpenAiResults = true
        defer { isLoadingOpenAiResults = false }
        
        // Use all loaded images for AI analysis
        guard !loadedImages.isEmpty else {
            throw OpenAIError.invalidData
        }
        
        // Prepare all images for AI analysis
        var imageBase64Array: [String] = []
        for image in loadedImages {
            if let base64 = await OptimizedImageManager.shared.prepareImageForAI(from: image) {
                imageBase64Array.append(base64)
            }
        }
        
        guard !imageBase64Array.isEmpty else {
            throw OpenAIError.invalidData
        }
        
        let openAi = OpenAIService(imageBase64Array: imageBase64Array, settings: settings, modelContext: modelContext)
        
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
        inventoryItemToDisplay.serial = imageDetails.serialNumber
        
        if inventoryItemToDisplay.location == nil {
            inventoryItemToDisplay.location = locations.first { $0.name == imageDetails.location }
        }
        
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        if let price = Decimal(string: priceString) {
            inventoryItemToDisplay.price = price
            displayPriceString = formatInitialPrice(price)
        }
        
        inventoryItemToDisplay.hasUsedAI = true
        
        try? modelContext.save()
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
        router.navigate(to: .editLocationView(location: location, isEditing: true))
    }
    
    private func addLabel() {
        let label = InventoryLabel()
        inventoryItemToDisplay.label = label
        router.navigate(to: .editLabelView(label: label, isEditing: true))
    }
    
    private func handleNewPhotos(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        
        do {
            if inventoryItemToDisplay.imageURL == nil {
                // No primary image yet, save the first image as primary
                let primaryImageURL = try await OptimizedImageManager.shared.saveImage(images.first!, id: inventoryItemToDisplay.assetId.isEmpty ? UUID().uuidString : inventoryItemToDisplay.assetId)
                
                await MainActor.run {
                    inventoryItemToDisplay.imageURL = primaryImageURL
                    if inventoryItemToDisplay.assetId.isEmpty {
                        inventoryItemToDisplay.assetId = primaryImageURL.lastPathComponent
                    }
                }
                
                // Save remaining images as secondary photos
                if images.count > 1 {
                    let secondaryImages = Array(images.dropFirst())
                    let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(secondaryImages, itemId: inventoryItemToDisplay.assetId)
                    
                    await MainActor.run {
                        inventoryItemToDisplay.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
                    }
                }
            } else {
                // Primary image exists, add all new images as secondary photos
                let itemId = inventoryItemToDisplay.assetId.isEmpty ? UUID().uuidString : inventoryItemToDisplay.assetId
                let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(images, itemId: itemId)
                
                await MainActor.run {
                    if inventoryItemToDisplay.assetId.isEmpty {
                        inventoryItemToDisplay.assetId = itemId
                    }
                    inventoryItemToDisplay.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
                }
            }
            
            await MainActor.run {
                try? modelContext.save()
                TelemetryManager.shared.trackInventoryItemAdded(name: inventoryItemToDisplay.title)
            }
            
            // Reload images after adding new photos
            await loadAllImages()
        } catch {
            print("Error saving new photos: \(error)")
        }
    }
    
    private func deletePhoto(urlString: String) async {
        guard URL(string: urlString) != nil else { return }
        
        do {
            // Delete from storage
            try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: urlString)
            
            await MainActor.run {
                if inventoryItemToDisplay.imageURL?.absoluteString == urlString {
                    // Deleting primary image
                    inventoryItemToDisplay.imageURL = nil
                    
                    // If there are secondary photos, promote the first one to primary
                    if !inventoryItemToDisplay.secondaryPhotoURLs.isEmpty {
                        if let firstSecondaryURL = URL(string: inventoryItemToDisplay.secondaryPhotoURLs.first!) {
                            inventoryItemToDisplay.imageURL = firstSecondaryURL
                            inventoryItemToDisplay.secondaryPhotoURLs.removeFirst()
                        }
                    }
                } else {
                    // Deleting secondary image
                    inventoryItemToDisplay.secondaryPhotoURLs.removeAll { $0 == urlString }
                }
                
                try? modelContext.save()
                
                // Reload images after deletion
                Task {
                    await loadAllImages()
                }
            }
        } catch {
            print("Error deleting photo: \(error)")
        }
    }
    
    private func loadAllImages() async {
        guard inventoryItemToDisplay.modelContext != nil else { return }
        
        await MainActor.run {
            isLoading = true
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        var images: [UIImage] = []
        
        // Load primary image
        if let imageURL = inventoryItemToDisplay.imageURL {
            do {
                let image = try await OptimizedImageManager.shared.loadImage(url: imageURL)
                images.append(image)
            } catch {
                print("Failed to load primary image: \(error)")
            }
        }
        
        // Load secondary images
        if !inventoryItemToDisplay.secondaryPhotoURLs.isEmpty {
            do {
                let secondaryImages = try await OptimizedImageManager.shared.loadSecondaryImages(from: inventoryItemToDisplay.secondaryPhotoURLs)
                images.append(contentsOf: secondaryImages)
            } catch {
                print("Failed to load secondary images: \(error)")
            }
        }
        
        await MainActor.run {
            loadedImages = images
            if selectedImageIndex >= images.count {
                selectedImageIndex = max(0, images.count - 1)
            }
        }
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
