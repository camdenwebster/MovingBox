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
    @Environment(\.colorScheme) var colorScheme
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
    @State private var showingSimpleCamera = false
    @State private var capturedImages: [UIImage] = []
    @State private var capturedSingleImage: UIImage?
    @State private var loadedImages: [UIImage] = []
    @State private var selectedImageIndex: Int = 0
    @State private var showingFullScreenPhoto = false
    @State private var showPhotoSourceAlert = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    
    var showSparklesButton = false

    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared

    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?
    

    init(inventoryItemToDisplay: InventoryItem,
         navigationPath: Binding<NavigationPath>,
         showSparklesButton: Bool = false,
         isEditing: Bool = false,
         onSave: (() -> Void)? = nil,
         onCancel: (() -> Void)? = nil) {
        self.inventoryItemToDisplay = inventoryItemToDisplay
        self._navigationPath = navigationPath
        self.showSparklesButton = showSparklesButton
        self._isEditing = State(initialValue: isEditing)
        self._displayPriceString = State(initialValue: formatInitialPrice(inventoryItemToDisplay.price))
        self.onSave = onSave
        self.onCancel = onCancel
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
            ZStack {
                GeometryReader { proxy in
                    let scrollY = proxy.frame(in: .global).minY
                    
                    FullScreenPhotoCarouselView(
                        images: loadedImages,
                        selectedIndex: $selectedImageIndex,
                        screenWidth: UIScreen.main.bounds.width,
                        isEditing: isEditing,
                        onAddPhoto: {
                            let currentPhotoCount = (inventoryItemToDisplay.imageURL != nil ? 1 : 0) + inventoryItemToDisplay.secondaryPhotoURLs.count
                            if currentPhotoCount < 5 {
                                showPhotoSourceAlert = true
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
                        },
                        onImageTap: { tappedIndex in
                            if !isEditing {
                                selectedImageIndex = tappedIndex
                                showingFullScreenPhoto = true
                            }
                        }
                    )
                    .frame(width: proxy.size.width, height: 350 + (scrollY > 0 ? scrollY : 0))
                    .clipped()
                    .offset(y: scrollY > 0 ? -scrollY : 0)
                }
                .frame(height: 350)
                .clipped()
                
                // Edit mode controls overlay - positioned at container bottom
                if isEditing {
                    VStack {
                        Spacer()
                        HStack(spacing: 16) {
                            // Delete photo button
                            if !loadedImages.isEmpty {
                                Button(action: {
                                    Task {
                                        let urlString: String
                                        if selectedImageIndex == 0 {
                                            // Deleting primary image
                                            if let imageURL = inventoryItemToDisplay.imageURL {
                                                urlString = imageURL.absoluteString
                                            } else {
                                                return
                                            }
                                        } else {
                                            // Deleting secondary image
                                            let secondaryIndex = selectedImageIndex - 1
                                            if secondaryIndex < inventoryItemToDisplay.secondaryPhotoURLs.count {
                                                urlString = inventoryItemToDisplay.secondaryPhotoURLs[secondaryIndex]
                                            } else {
                                                return
                                            }
                                        }
                                        await deletePhoto(urlString: urlString)
                                    }
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
                            let currentPhotoCount = (inventoryItemToDisplay.imageURL != nil ? 1 : 0) + inventoryItemToDisplay.secondaryPhotoURLs.count
                            if currentPhotoCount < 5 {
                                Button(action: {
                                    showPhotoSourceAlert = true
                                }) {
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
        } else {
            // Show placeholder when no photos exist (both editing and viewing)
            PhotoPlaceholderView(
                isEditing: isEditing,
                onAddPhoto: {
                    showPhotoSourceAlert = true
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
                
//                if isEditing {
//                    clearFieldsSection
//                }
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
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
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
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
//    @ViewBuilder
//    private var clearFieldsSection: some View {
//        VStack(spacing: 0) {
//            Button("Clear All Fields") {
//                showingClearAllAlert = true
//            }
//            .frame(maxWidth: .infinity)
//            .padding(.horizontal, 16)
//            .padding(.vertical, 12)
//            .background(Color(.secondarySystemGroupedBackground))
//            .foregroundColor(.red)
//            .accessibilityIdentifier("clearAllFields")
//        }
//        .background(Color(.secondarySystemGroupedBackground))
//        .cornerRadius(12)
//    }

    @ViewBuilder
    private var mainContent: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    photoSection
                    
                    formContent
                        .background(Color(.systemGroupedBackground))
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    var body: some View {
        mainContent
            .applyNavigationSettings(
                title: inventoryItemToDisplay.title,
                isEditing: isEditing,
                colorScheme: colorScheme
            )
            .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button("Cancel") {
                        if let onCancel = onCancel {
                            // During onboarding - delete the item and close the sheet
                            deleteItemAndCloseSheet()
                        } else if OnboardingManager.hasCompletedOnboarding() {
                            // Normal editing mode - handle unsaved changes
                            if modelContext.hasChanges {
                                showUnsavedChangesAlert = true
                            } else {
                                isEditing = false
                            }
                        }
                    }
                    .accessibilityIdentifier("cancelButton")
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
//        .alert("Are you sure?", isPresented: $showingClearAllAlert) {
//            Button("Clear All Fields", role: .destructive) { clearFields() }
//            Button("Cancel", role: .cancel) { }
//        }
        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
            Button("Take Photo") {
                showingSimpleCamera = true
            }
            Button("Choose from Library") {
                showPhotoPicker = true
            }
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
        .fullScreenCover(isPresented: $showingFullScreenPhoto) {
            FullScreenPhotoView(
                images: loadedImages,
                initialIndex: selectedImageIndex,
                isPresented: $showingFullScreenPhoto
            )
        }
        .fullScreenCover(isPresented: $showingSimpleCamera) {
            SimpleCameraView(capturedImage: $capturedSingleImage)
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotosPickerItems,
            maxSelectionCount: max(1, 5 - ((inventoryItemToDisplay.imageURL != nil ? 1 : 0) + inventoryItemToDisplay.secondaryPhotoURLs.count)),
            matching: .images
        )
        .onChange(of: capturedSingleImage) { _, newImage in
            if let image = newImage {
                print("📷 onChange(capturedSingleImage): New image captured")
                Task {
                    await handleNewPhotos([image])
                    capturedSingleImage = nil
                }
            } else {
                print("📷 onChange(capturedSingleImage): Image cleared or nil")
            }
        }
        .onChange(of: selectedPhotosPickerItems) { _, newItems in
            print("📱 onChange(selectedPhotosPickerItems): \(newItems.count) items selected")
            Task {
                await processSelectedPhotos(newItems)
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
    
//    private func clearFields() {
//        print("Clear fields button tapped")
//        inventoryItemToDisplay.title = ""
//        inventoryItemToDisplay.label = nil
//        inventoryItemToDisplay.desc = ""
//        inventoryItemToDisplay.make = ""
//        inventoryItemToDisplay.model = ""
//        inventoryItemToDisplay.location = nil
//        inventoryItemToDisplay.price = 0
//        inventoryItemToDisplay.notes = ""
//    }
    
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
        guard !images.isEmpty else { 
            print("❌ handleNewPhotos: No images provided")
            return 
        }
        
        print("📷 handleNewPhotos: Starting with \(images.count) images")
        print("📷 handleNewPhotos: Current state - imageURL: \(inventoryItemToDisplay.imageURL?.absoluteString ?? "nil"), assetId: '\(inventoryItemToDisplay.assetId)', secondaryURLs: \(inventoryItemToDisplay.secondaryPhotoURLs.count)")
        
        do {
            // Ensure we have a consistent itemId for all operations
            let itemId = inventoryItemToDisplay.assetId.isEmpty ? UUID().uuidString : inventoryItemToDisplay.assetId
            print("📷 handleNewPhotos: Using itemId: \(itemId)")
            
            if inventoryItemToDisplay.imageURL == nil {
                print("📷 handleNewPhotos: No primary image yet, saving first image as primary")
                // No primary image yet, save the first image as primary
                let primaryImageURL = try await OptimizedImageManager.shared.saveImage(images.first!, id: itemId)
                print("📷 handleNewPhotos: Saved primary image to: \(primaryImageURL.absoluteString)")
                
                await MainActor.run {
                    inventoryItemToDisplay.imageURL = primaryImageURL
                    inventoryItemToDisplay.assetId = itemId
                    print("📷 handleNewPhotos: Updated item - imageURL: \(primaryImageURL.absoluteString), assetId: \(itemId)")
                }
                
                // Save remaining images as secondary photos
                if images.count > 1 {
                    print("📷 handleNewPhotos: Saving \(images.count - 1) remaining images as secondary")
                    let secondaryImages = Array(images.dropFirst())
                    let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(secondaryImages, itemId: itemId)
                    print("📷 handleNewPhotos: Saved secondary images: \(secondaryURLs)")
                    
                    await MainActor.run {
                        inventoryItemToDisplay.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
                        print("📷 handleNewPhotos: Updated secondaryPhotoURLs count: \(inventoryItemToDisplay.secondaryPhotoURLs.count)")
                    }
                }
            } else {
                print("📷 handleNewPhotos: Primary image exists, adding all \(images.count) images as secondary")
                // Primary image exists, add all new images as secondary photos
                let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(images, itemId: itemId)
                print("📷 handleNewPhotos: Saved secondary images: \(secondaryURLs)")
                
                await MainActor.run {
                    inventoryItemToDisplay.assetId = itemId
                    inventoryItemToDisplay.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
                    print("📷 handleNewPhotos: Updated secondaryPhotoURLs count: \(inventoryItemToDisplay.secondaryPhotoURLs.count)")
                }
            }
            
            await MainActor.run {
                try? modelContext.save()
                print("📷 handleNewPhotos: Saved to model context")
                TelemetryManager.shared.trackInventoryItemAdded(name: inventoryItemToDisplay.title)
            }
            
            print("📷 handleNewPhotos: About to reload images...")
            // Reload images after adding new photos
            await loadAllImages()
            print("📷 handleNewPhotos: Completed")
        } catch {
            print("❌ handleNewPhotos: Error saving new photos: \(error)")
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
        // Use the view's modelContext instead of the item's modelContext
        // The item's modelContext can become nil after saving
        print("🔄 loadAllImages: Using view's modelContext")
        
        print("🔄 loadAllImages: Starting - imageURL: \(inventoryItemToDisplay.imageURL?.absoluteString ?? "nil"), secondaryURLs: \(inventoryItemToDisplay.secondaryPhotoURLs.count)")
        
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
            print("📸 loadAllImages: Loading primary image from \(imageURL.absoluteString)")
            do {
                let image = try await OptimizedImageManager.shared.loadImage(url: imageURL)
                images.append(image)
                print("✅ loadAllImages: Successfully loaded primary image")
            } catch {
                print("❌ loadAllImages: Failed to load primary image: \(error)")
            }
        } else {
            print("📸 loadAllImages: No primary image URL")
        }
        
        // Load secondary images
        if !inventoryItemToDisplay.secondaryPhotoURLs.isEmpty {
            print("📸 loadAllImages: Loading \(inventoryItemToDisplay.secondaryPhotoURLs.count) secondary images")
            do {
                let secondaryImages = try await OptimizedImageManager.shared.loadSecondaryImages(from: inventoryItemToDisplay.secondaryPhotoURLs)
                images.append(contentsOf: secondaryImages)
                print("✅ loadAllImages: Successfully loaded \(secondaryImages.count) secondary images")
            } catch {
                print("❌ loadAllImages: Failed to load secondary images: \(error)")
            }
        } else {
            print("📸 loadAllImages: No secondary images")
        }
        
        await MainActor.run {
            print("🔄 loadAllImages: Setting loadedImages to \(images.count) images")
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
    
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { 
            print("❌ processSelectedPhotos: No items provided")
            return 
        }
        
        print("📱 processSelectedPhotos: Starting with \(items.count) PhotosPicker items")
        
        var images: [UIImage] = []
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
                print("✅ processSelectedPhotos: Successfully loaded image from PhotosPicker")
            } else {
                print("❌ processSelectedPhotos: Failed to load image from PhotosPicker item")
            }
        }
        
        print("📱 processSelectedPhotos: Loaded \(images.count) images from PhotosPicker")
        
        if !images.isEmpty {
            await handleNewPhotos(images)
        } else {
            print("❌ processSelectedPhotos: No images to handle")
        }
        
        // Clear selected items after processing
        await MainActor.run {
            selectedPhotosPickerItems = []
            print("📱 processSelectedPhotos: Cleared selectedPhotosPickerItems")
        }
    }
    
    private func deleteItemAndCloseSheet() {
        // Delete any saved images for this item
        Task {
            do {
                if let imageURL = inventoryItemToDisplay.imageURL {
                    try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: imageURL.absoluteString)
                }
                
                for photoURL in inventoryItemToDisplay.secondaryPhotoURLs {
                    try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: photoURL)
                }
            } catch {
                print("Error deleting images during cancellation: \(error)")
            }
            
            await MainActor.run {
                // Remove the item from the model context
                modelContext.delete(inventoryItemToDisplay)
                try? modelContext.save()
                
                // Call the onCancel callback to close the sheet
                onCancel?()
            }
        }
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
    let onImageTap: (Int) -> Void
    
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
                        .onTapGesture {
                            onImageTap(index)
                        }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Overlay container for indicators - aligned to frame bottom
            VStack {
                Spacer()
                
                // Bottom overlay area
                ZStack {
                    // Dot indicators (only show if multiple photos)
                    if images.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(0..<images.count, id: \.self) { index in
                                Circle()
                                    .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.5))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    
                    // Photo count badge (like Vrbo) - positioned at frame bottom
                    if images.count > 1 {
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
                        }
                        .padding(.trailing, 20)
                    }
                }
                .padding(.bottom, 20)
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

// MARK: - View Extensions

extension View {
    func applyNavigationSettings(title: String, isEditing: Bool, colorScheme: ColorScheme) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isEditing)
            .toolbarBackground(colorScheme == .dark ? .black : .white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
    }
}
