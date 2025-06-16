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
    
    // MARK: - View Components
    
    @ViewBuilder
    private var photoSection: some View {
        // Photo banner section
        if !loadedImages.isEmpty {
            GeometryReader { proxy in
                let scrollY = proxy.frame(in: .global).minY
                
                ZStack {
                    FullScreenPhotoCarouselView(
                        images: loadedImages,
                        selectedIndex: $selectedImageIndex,
                        screenWidth: UIScreen.main.bounds.width,
                        isEditing: isEditing,
                        onAddPhoto: {
                            let currentPhotoCount = (inventoryItemToDisplay.imageURL != nil ? 1 : 0) + inventoryItemToDisplay.secondaryPhotoURLs.count
                            if currentPhotoCount < 5 {
                                showingMultiPhotoCamera = true
                            }
                        },
                        onDeletePhoto: { index in
                            Task {
                                let urlString: String
                                if index == 0 {
                                    // Deleting primary image
                                    if let imageURL = inventoryItemToDisplay.imageURL {
                                        urlString = imageURL.absoluteString
                                    } else {
                                        return
                                    }
                                } else {
                                    // Deleting secondary image
                                    let secondaryIndex = index - 1
                                    if secondaryIndex < inventoryItemToDisplay.secondaryPhotoURLs.count {
                                        urlString = inventoryItemToDisplay.secondaryPhotoURLs[secondaryIndex]
                                    } else {
                                        return
                                    }
                                }
                                await deletePhoto(urlString: urlString)
                            }
                        }
                    )
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: 350 + (scrollY > 0 ? scrollY : 0))
                    .clipped()
                    .offset(y: scrollY > 0 ? -scrollY : 0)
                    
                    
                    // Black gradient overlay at the top for navigation visibility
                    VStack {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(1),
                                Color.black.opacity(0.5),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 200)
                        
                        Spacer()
                    }
                }
            }
            .frame(height: 350)
            .clipped()
        } else {
            // Show placeholder when no photos exist (both editing and viewing)
            PhotoPlaceholderView(
                isEditing: isEditing,
                onAddPhoto: {
                    showingMultiPhotoCamera = true
                }
            )
            .frame(height: 250)
        }
    }
    
    @ViewBuilder
    private var formContent: some View {
        VStack(spacing: 0) {
            // AI Button Section
            if isEditing && !inventoryItemToDisplay.hasUsedAI && inventoryItemToDisplay.imageURL != nil {
                VStack(spacing: 0) {
                    aiButtonView
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }
            }
            
            // Form sections
            VStack(spacing: 24) {
                detailsSection
                
                if isEditing || inventoryItemToDisplay.quantityInt > 1 {
                    quantitySection
                }
                
                if isEditing || !inventoryItemToDisplay.desc.isEmpty {
                    descriptionSection
                }
                
                priceSection
                locationsAndLabelsSection
                
                if isEditing || !inventoryItemToDisplay.notes.isEmpty {
                    notesSection
                }
                
                if isEditing {
                    clearFieldsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
    
    @ViewBuilder
    private var aiButtonView: some View {
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
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                if isEditing || !inventoryItemToDisplay.title.isEmpty {
                    FormTextFieldRow(label: "Title", text: $inventoryItemToDisplay.title, isEditing: $isEditing, placeholder: "Desktop Computer")
                        .focused($focusedField, equals: .title)
                        .accessibilityIdentifier("titleField")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    if (isEditing || !inventoryItemToDisplay.serial.isEmpty) || 
                       (isEditing || !inventoryItemToDisplay.make.isEmpty) || 
                       (isEditing || !inventoryItemToDisplay.model.isEmpty) {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                if isEditing || !inventoryItemToDisplay.serial.isEmpty {
                    FormTextFieldRow(label: "Serial Number", text: $inventoryItemToDisplay.serial, isEditing: $isEditing, placeholder: "SN-12345")
                        .focused($focusedField, equals: .serial)
                        .accessibilityIdentifier("serialField")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    if (isEditing || !inventoryItemToDisplay.make.isEmpty) || 
                       (isEditing || !inventoryItemToDisplay.model.isEmpty) {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                if isEditing || !inventoryItemToDisplay.make.isEmpty {
                    FormTextFieldRow(label: "Make", text: $inventoryItemToDisplay.make, isEditing: $isEditing, placeholder: "Apple")
                        .focused($focusedField, equals: .make)
                        .accessibilityIdentifier("makeField")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    if isEditing || !inventoryItemToDisplay.model.isEmpty {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                if isEditing || !inventoryItemToDisplay.model.isEmpty {
                    FormTextFieldRow(label: "Model", text: $inventoryItemToDisplay.model, isEditing: $isEditing, placeholder: "Mac Mini")
                        .focused($focusedField, equals: .model)
                        .accessibilityIdentifier("modelField")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantity")
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                Stepper("\(inventoryItemToDisplay.quantityInt)", value: $inventoryItemToDisplay.quantityInt, in: 1...1000, step: 1)
                    .disabled(!isEditing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                TextEditor(text: $inventoryItemToDisplay.desc)
                    .focused($focusedField, equals: .description)
                    .frame(height: 60)
                    .disabled(!isEditing)
                    .accessibilityIdentifier("descriptionField")
                    .foregroundColor(isEditing ? .primary : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Purchase Price")
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PriceFieldRow(
                    priceString: $displayPriceString,
                    priceDecimal: $inventoryItemToDisplay.price,
                    isEditing: $isEditing
                )
                .disabled(!isEditing)
                .accessibilityIdentifier("priceField")
                .foregroundColor(isEditing ? .primary : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .padding(.leading, 16)
                
                Toggle(isOn: $inventoryItemToDisplay.insured, label: {
                    Text("Insured")
                })
                .disabled(!isEditing)
                .accessibilityIdentifier("insuredToggle")
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var locationsAndLabelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Locations & Labels")
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    if isEditing || inventoryItemToDisplay.label != nil {
                        Divider()
                            .padding(.leading, 16)
                    }
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                TextEditor(text: $inventoryItemToDisplay.notes)
                    .foregroundColor(isEditing ? .primary : .secondary)
                    .focused($focusedField, equals: .notes)
                    .frame(height: 100)
                    .disabled(!isEditing)
                    .accessibilityIdentifier("notesField")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var clearFieldsSection: some View {
        VStack(spacing: 0) {
            Button("Clear All Fields") {
                showingClearAllAlert = true
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .foregroundColor(.red)
            .accessibilityIdentifier("clearAllFields")
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                photoSection
                
                formContent
                    .background(Color(.systemGroupedBackground))
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .navigationTitle("")
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
            Button("Save & Stay", role: .none) {
                try? modelContext.save()
                isEditing = false
            }
            
            Button("Discard Changes", role: .destructive) {
                modelContext.rollback()
                isEditing = false
            }
            
            Button("Cancel", role: .cancel) {
                showUnsavedChangesAlert = false
            }
        } message: {
            Text("Do you want to save your changes before exiting edit mode?")
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

// MARK: - Full Screen Photo Carousel View

struct FullScreenPhotoCarouselView: View {
    let images: [UIImage]
    @Binding var selectedIndex: Int
    let screenWidth: CGFloat
    let isEditing: Bool
    let onAddPhoto: () -> Void
    let onDeletePhoto: (Int) -> Void
    
    var body: some View {
        ZStack {
            // Photo carousel with swipe navigation
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: screenWidth)
                        .clipped()
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Dot indicators (only show if multiple photos)
            if images.count > 1 {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Circle()
                                .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            
            // Photo count badge (like Vrbo)
            if images.count > 1 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.caption)
                            Text("\(selectedIndex + 1) / \(images.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            
            // Edit mode controls overlay
            if isEditing {
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        // Delete photo button
                        if !images.isEmpty {
                            Button(action: {
                                onDeletePhoto(selectedIndex)
                            }) {
                                Image(systemName: "trash")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(.red.opacity(0.8))
                                    .clipShape(Circle())
                            }
                        }
                        
                        Spacer()
                        
                        // Add photo button
                        if images.count < 5 {
                            Button(action: onAddPhoto) {
                                Image(systemName: "plus")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(.blue.opacity(0.8))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Photo Placeholder View

struct PhotoPlaceholderView: View {
    let isEditing: Bool
    let onAddPhoto: () -> Void
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.1)
            
            VStack(spacing: 20) {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("No photos yet")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                if isEditing {
                    Button(action: onAddPhoto) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Add Photo")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var previewItem: InventoryItem
        
        init() {
            let item = InventoryItem(
                title: "MacBook Pro",
                quantityString: "1",
                quantityInt: 1,
                desc: "16-inch 2023 Model",
                serial: "SN12345ABC",
                model: "MacBook Pro M2",
                make: "Apple",
                location: nil,
                label: nil,
                price: Decimal(2499.99),
                insured: false,
                assetId: "macbook-preview",
                notes: "Purchased for work and personal projects. Excellent condition with original box and charger.",
                showInvalidQuantityAlert: false,
                hasUsedAI: true
            )
            self._previewItem = State(initialValue: item)
        }
        
        var body: some View {
            InventoryDetailView(
                inventoryItemToDisplay: previewItem,
                navigationPath: .constant(NavigationPath()),
                isEditing: false
            )
            .environmentObject(Router())
            .environmentObject(SettingsManager())
            .environmentObject(OnboardingManager())
            .task {
                // Use the same approach as TestData.swift
                guard let image = UIImage(named: "macbook") else {
                    print("❌ Could not load image: macbook")
                    return
                }
                
                do {
                    let imageURL = try await OptimizedImageManager.shared.saveImage(image, id: "macbook-preview")
                    previewItem.imageURL = imageURL
                    print("✅ Successfully loaded preview image: macbook")
                } catch {
                    print("❌ Failed to setup preview image: \(error)")
                }
            }
        }
    }
    
    return PreviewWrapper()
}
