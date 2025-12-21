//
//  InventoryDetail.swift
//  MovingBox
//
//  Created by Camden Webster on 5/16/24.
//

import RevenueCatUI
import PhotosUI
import PDFKit
import QuickLook
import SentrySwiftUI
import SwiftData
import SwiftUI
import VisionKit

@MainActor
struct InventoryDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @Query private var allItems: [InventoryItem]
    @FocusState private var isPriceFieldFocused: Bool

    // Photo section frame height constants
    private static let photoSectionHeight: CGFloat = 300
    private static let photoSectionHeightWithPhotos: CGFloat = 350
    
    @State private var displayPriceString: String = ""
    @State private var imageDetailsFromOpenAI: ImageDetails = ImageDetails.empty()
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
    @State private var hasUserMadeChanges = false
    @State private var originalValues: InventoryItemSnapshot?
    @State private var originalDisplayPriceString: String = ""
    
    // Computed property to create a hash of key field values for change detection
    private var currentFieldsHash: String {
        let fields = [
            inventoryItemToDisplay.title,
            inventoryItemToDisplay.desc,
            inventoryItemToDisplay.serial,
            inventoryItemToDisplay.make,
            inventoryItemToDisplay.model,
            inventoryItemToDisplay.notes,
            inventoryItemToDisplay.purchaseLocation,
            inventoryItemToDisplay.condition,
            inventoryItemToDisplay.color,
            inventoryItemToDisplay.storageRequirements,
            inventoryItemToDisplay.roomDestination,
            inventoryItemToDisplay.dimensionLength,
            inventoryItemToDisplay.dimensionWidth,
            inventoryItemToDisplay.dimensionHeight,
            inventoryItemToDisplay.dimensionUnit,
            inventoryItemToDisplay.weightValue,
            inventoryItemToDisplay.weightUnit,
            String(inventoryItemToDisplay.quantityInt),
            String(inventoryItemToDisplay.isFragile),
            String(inventoryItemToDisplay.hasWarranty),
            String(inventoryItemToDisplay.movingPriority),
            String(describing: inventoryItemToDisplay.replacementCost),
            String(describing: inventoryItemToDisplay.depreciationRate),
            String(describing: inventoryItemToDisplay.purchaseDate),
            String(describing: inventoryItemToDisplay.warrantyExpirationDate)
        ]
        return fields.joined(separator: "|")
    }
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
    @State private var showDocumentScanner = false
    @State private var showingLocationSelection = false
    @State private var showingLabelSelection = false
    @State private var showDocumentPicker = false
    @State private var showingFileViewer = false
    @State private var fileViewerURL: URL?
    @State private var fileViewerName: String?
    @State private var showingDeleteAttachmentAlert = false
    @State private var attachmentToDelete: String?
    @State private var showingDeleteItemAlert = false

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
    
    // MARK: - Progressive Disclosure Helpers
    
    private var hasAnyPurchaseTrackingData: Bool {
        inventoryItemToDisplay.purchaseDate != nil ||
        !inventoryItemToDisplay.purchaseLocation.isEmpty ||
        !inventoryItemToDisplay.condition.isEmpty
    }
    
    private var hasAnyFinancialData: Bool {
        inventoryItemToDisplay.replacementCost != nil ||
        inventoryItemToDisplay.depreciationRate != nil
    }
    
    private var hasAnyPhysicalPropertiesData: Bool {
        !inventoryItemToDisplay.dimensionLength.isEmpty ||
        !inventoryItemToDisplay.dimensionWidth.isEmpty ||
        !inventoryItemToDisplay.dimensionHeight.isEmpty ||
        !inventoryItemToDisplay.weightValue.isEmpty ||
        !inventoryItemToDisplay.color.isEmpty ||
        !inventoryItemToDisplay.storageRequirements.isEmpty
    }
    
    private var hasAnyMovingOptimizationData: Bool {
        inventoryItemToDisplay.isFragile ||
        inventoryItemToDisplay.movingPriority != 3 ||
        !inventoryItemToDisplay.roomDestination.isEmpty
    }
    
    private var hasAnyAttachments: Bool {
        inventoryItemToDisplay.hasAttachments()
    }
    
    // MARK: - Toolbar Components
    
    @ViewBuilder
    private var leadingToolbarButton: some View {
        if isEditing {
            Button("Cancel") {
                if onCancel != nil {
                    // We're in a sheet context (likely onboarding or add item flow)
                    if hasUserMadeChanges {
                        showUnsavedChangesAlert = true
                    } else {
                        deleteItemAndCloseSheet()
                    }
                } else {
                    // We're in regular navigation context
                    if hasUserMadeChanges {
                        showUnsavedChangesAlert = true
                    } else {
                        isEditing = false
                    }
                }
            }
            .accessibilityIdentifier("cancelButton")
        }
    }

    
    @ViewBuilder
    private var trailingToolbarButton: some View {
        if isEditing {
            Button("Save") {
                if inventoryItemToDisplay.modelContext == nil {
                    modelContext.insert(inventoryItemToDisplay)
                }
                try? modelContext.save()
                hasUserMadeChanges = false // Reset after successful save
                originalValues = nil // Clear original values after successful save
                isEditing = false

                // Regenerate thumbnails if missing
                Task {
                    await regenerateMissingThumbnails()
                }

                onSave?()
            }
            .backport.glassProminentButtonStyle()
            .fontWeight(.bold)
            .disabled(inventoryItemToDisplay.title.isEmpty || isLoadingOpenAiResults)
            .accessibilityIdentifier("save")
        } else {
            Button("Edit") {
                // Capture original state before entering edit mode
                originalValues = InventoryItemSnapshot(from: inventoryItemToDisplay)
                originalDisplayPriceString = displayPriceString
                hasUserMadeChanges = false
                isEditing = true
            }
            .accessibilityIdentifier("edit")
            .tint(.green)
        }
    }


    // MARK: - View Components
    
    @ViewBuilder
    private var photoSection: some View {
        // Photo banner section with progressive loading states
        if isLoading {
            // Loading state - show progress indicator
            GeometryReader { proxy in
                let scrollY = proxy.frame(in: .global).minY

                ZStack {
                    Color(.systemGray6)
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                            .scaleEffect(1.2)
                        Text("Loading photos...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: proxy.size.width, height: Self.photoSectionHeight + (scrollY > 0 ? scrollY : 0))
                .offset(y: scrollY > 0 ? -scrollY : 0)
            }
            .frame(height: Self.photoSectionHeight)
        } else if let loadingError = loadingError {
            // Error state - show error placeholder
            GeometryReader { proxy in
                let scrollY = proxy.frame(in: .global).minY

                ZStack {
                    Color(.systemGray6)
                    VStack(spacing: 16) {
                        Image(systemName: "photo.trianglebadge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("Failed to load photos")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(loadingError.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if isEditing {
                            Button(action: {
                                showPhotoSourceAlert = true
                            }) {
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
                .frame(width: proxy.size.width, height: Self.photoSectionHeight + (scrollY > 0 ? scrollY : 0))
                .offset(y: scrollY > 0 ? -scrollY : 0)
            }
            .frame(height: Self.photoSectionHeight)
        } else if !loadedImages.isEmpty {
            // Success state - show photo carousel
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
                            if currentPhotoCount < (settings.isPro ? 5 : 1) {
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
                    .frame(width: proxy.size.width, height: Self.photoSectionHeightWithPhotos + (scrollY > 0 ? scrollY : 0))
                    .offset(y: scrollY > 0 ? -scrollY : 0)
                    .modifier(BackgroundExtensionModifier())
                }
                .frame(height: Self.photoSectionHeightWithPhotos)
                
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
                            if currentPhotoCount < (settings.isPro ? 5 : 1) {
                                Button(action: {
                                    showPhotoSourceAlert = true
                                }) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(.blue.opacity(0.8))
                                        .clipShape(Circle())
                                }
                                .accessibilityIdentifier("add-photo-button")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 60)
                    }
                }
            }
        } else {
            // No photos state - show placeholder when no photos exist
            GeometryReader { proxy in
                let scrollY = proxy.frame(in: .global).minY

                photoPlaceHolder
                    .frame(width: proxy.size.width, height: Self.photoSectionHeight + (scrollY > 0 ? scrollY : 0))
                    .offset(y: scrollY > 0 ? -scrollY : 0)
            }
            .frame(height: Self.photoSectionHeight)
        }
    }
    
    @ViewBuilder
    private var formContent: some View {
        VStack(spacing: 0) {
            // AI Button and Receipt Button Section
            if isEditing && inventoryItemToDisplay.imageURL != nil {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        aiButtonView
                    }
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
                
                purchaseTrackingSection
                financialSection
                physicalPropertiesSection
                movingOptimizationSection
                attachmentsSection
                
                if isEditing || !inventoryItemToDisplay.notes.isEmpty {
                    notesSection
                }

                if isEditing {
                    deleteButton
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
                performAIAnalysis()
            }
        } label: {
            HStack {
                if isLoadingOpenAiResults {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "wand.and.sparkles")
                    Text("Analyze with AI")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(.white)
            .cornerRadius(UIConstants.cornerRadius)
        }
        .backport.glassProminentButtonStyle()
        .disabled(isLoadingOpenAiResults)
        .accessibilityIdentifier("analyzeWithAi")
    }
    
    @ViewBuilder
    private var attachmentButtonView: some View {
        HStack {
            Button {
                showDocumentPicker = true
            } label: {
                Text("Add Attachment")
            }
            .accessibilityIdentifier("addAttachment")
            Spacer()
        }
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .sectionHeaderStyle()
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
            .cornerRadius(UIConstants.cornerRadius)
        }
    }
    
    @ViewBuilder
    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantity")
                .sectionHeaderStyle()
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                Stepper("\(inventoryItemToDisplay.quantityInt)", value: $inventoryItemToDisplay.quantityInt, in: 1...1000, step: 1)
                    .disabled(!isEditing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(UIConstants.cornerRadius)
        }
    }
    
    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .sectionHeaderStyle()
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                TextEditor(text: $inventoryItemToDisplay.desc)
                    .focused($focusedField, equals: .description)
                    .frame(height: 90)
                    .disabled(!isEditing)
                    .accessibilityIdentifier("descriptionField")
                    .foregroundColor(isEditing ? .primary : .secondary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(UIConstants.cornerRadius)
        }
    }
    
    @ViewBuilder
    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Purchase Price")
                .sectionHeaderStyle()
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
                
                Toggle(isOn: $inventoryItemToDisplay.hasWarranty, label: {
                    Text("Warranty")
                })
                .disabled(!isEditing)
                .accessibilityIdentifier("warrantyToggle")
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                if inventoryItemToDisplay.hasWarranty {
                    Divider()
                        .padding(.leading, 16)
                    
                    DatePicker("Warranty Expires", 
                               selection: Binding(
                                   get: { inventoryItemToDisplay.warrantyExpirationDate ?? Date() },
                                   set: { inventoryItemToDisplay.warrantyExpirationDate = $0 }
                               ),
                               displayedComponents: .date)
                        .disabled(!isEditing)
                        .accessibilityIdentifier("warrantyDatePicker")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(UIConstants.cornerRadius)
        }
    }
    
    @ViewBuilder
    private var locationsAndLabelsSection: some View {
        if isEditing || inventoryItemToDisplay.location != nil || inventoryItemToDisplay.label != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Locations & Labels")
                    .sectionHeaderStyle()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    if isEditing || inventoryItemToDisplay.location != nil {
                        Button(action: {
                            if isEditing {
                                showingLocationSelection = true
                            }
                        }) {
                            HStack {
                                Text("Location")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(inventoryItemToDisplay.location?.name ?? "None")
                                    .foregroundColor(.secondary)
                                if isEditing {
                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
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
                        Button(action: {
                            if isEditing {
                                showingLabelSelection = true
                            }
                        }) {
                            HStack {
                                Text("Label")
                                    .foregroundColor(.primary)
                                Spacer()
                                if let label = inventoryItemToDisplay.label {
                                    Text("\(label.emoji) \(label.name)")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("None")
                                        .foregroundColor(.secondary)
                                }
                                if isEditing {
                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
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
                .cornerRadius(UIConstants.cornerRadius)
            }
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .sectionHeaderStyle()
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
            .cornerRadius(UIConstants.cornerRadius)
        }
    }

    @ViewBuilder
    private var deleteButton: some View {
        Button(action: {
            showingDeleteItemAlert = true
        }) {
            HStack {
                Image(systemName: "trash")
                Text("Delete Item")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundColor(.white)
            .background(Color.red)
            .cornerRadius(UIConstants.cornerRadius)
        }
        .accessibilityIdentifier("deleteItemButton")
    }

    // MARK: - New Attribute Sections
    
    @ViewBuilder
    private var purchaseTrackingSection: some View {
        if isEditing || hasAnyPurchaseTrackingData {
            VStack(alignment: .leading, spacing: 8) {
                Text("Purchase & Ownership")
                    .sectionHeaderStyle()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    if isEditing || inventoryItemToDisplay.purchaseDate != nil {
                        DatePicker("Purchase Date", 
                                   selection: Binding(
                                       get: { inventoryItemToDisplay.purchaseDate ?? Date() },
                                       set: { inventoryItemToDisplay.purchaseDate = $0 }
                                   ),
                                   displayedComponents: .date)
                            .disabled(!isEditing)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        
                        if (isEditing || !inventoryItemToDisplay.purchaseLocation.isEmpty) {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                    
                    if isEditing || !inventoryItemToDisplay.purchaseLocation.isEmpty {
                        FormTextFieldRow(label: "Purchase Location", text: $inventoryItemToDisplay.purchaseLocation, isEditing: $isEditing, placeholder: "Apple Store")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        
                        if isEditing || !inventoryItemToDisplay.condition.isEmpty {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                    
                    if isEditing || !inventoryItemToDisplay.condition.isEmpty {
                        ConditionPickerRow(condition: $inventoryItemToDisplay.condition, isEditing: $isEditing)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(UIConstants.cornerRadius)
            }
        }
    }
    
    @ViewBuilder
    private var financialSection: some View {
        if isEditing || hasAnyFinancialData {
            VStack(alignment: .leading, spacing: 8) {
                Text("Financial Information")
                    .sectionHeaderStyle()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    if isEditing || inventoryItemToDisplay.replacementCost != nil {
                        CurrencyFieldRow(label: "Replacement Cost", value: $inventoryItemToDisplay.replacementCost, isEditing: $isEditing)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        if isEditing || inventoryItemToDisplay.depreciationRate != nil {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                    
                    if isEditing || inventoryItemToDisplay.depreciationRate != nil {
                        PercentageFieldRow(label: "Depreciation Rate", value: $inventoryItemToDisplay.depreciationRate, isEditing: $isEditing)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(UIConstants.cornerRadius)
            }
        }
    }
    
    @ViewBuilder
    private var physicalPropertiesSection: some View {
        if isEditing || hasAnyPhysicalPropertiesData {
            VStack(alignment: .leading, spacing: 8) {
                Text("Physical Properties")
                    .sectionHeaderStyle()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    if isEditing || !inventoryItemToDisplay.dimensionLength.isEmpty || !inventoryItemToDisplay.dimensionWidth.isEmpty || !inventoryItemToDisplay.dimensionHeight.isEmpty {
                        DimensionsFieldRow(
                            length: $inventoryItemToDisplay.dimensionLength,
                            width: $inventoryItemToDisplay.dimensionWidth,
                            height: $inventoryItemToDisplay.dimensionHeight,
                            unit: $inventoryItemToDisplay.dimensionUnit,
                            isEditing: $isEditing
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        if (isEditing || !inventoryItemToDisplay.weightValue.isEmpty) ||
                           (isEditing || !inventoryItemToDisplay.condition.isEmpty) ||
                           (isEditing || !inventoryItemToDisplay.color.isEmpty) ||
                           (isEditing || !inventoryItemToDisplay.storageRequirements.isEmpty) {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                    
                    if isEditing || !inventoryItemToDisplay.weightValue.isEmpty {
                        WeightFieldRow(
                            value: $inventoryItemToDisplay.weightValue,
                            unit: $inventoryItemToDisplay.weightUnit,
                            isEditing: $isEditing
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        if (isEditing || !inventoryItemToDisplay.color.isEmpty) ||
                           (isEditing || !inventoryItemToDisplay.storageRequirements.isEmpty) {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                    
                    if isEditing || !inventoryItemToDisplay.color.isEmpty {
                        FormTextFieldRow(label: "Color", text: $inventoryItemToDisplay.color, isEditing: $isEditing, placeholder: "Space Gray")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        
                        if isEditing || !inventoryItemToDisplay.storageRequirements.isEmpty {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                    
                    if isEditing || !inventoryItemToDisplay.storageRequirements.isEmpty {
                        FormTextFieldRow(label: "Storage Requirements", text: $inventoryItemToDisplay.storageRequirements, isEditing: $isEditing, placeholder: "Keep upright, dry environment")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(UIConstants.cornerRadius)
            }
        }
    }
    
    @ViewBuilder
    private var movingOptimizationSection: some View {
        if isEditing || hasAnyMovingOptimizationData {
            VStack(alignment: .leading, spacing: 8) {
                Text("Moving & Storage")
                    .sectionHeaderStyle()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    Toggle(isOn: $inventoryItemToDisplay.isFragile, label: {
                        Text("Fragile Item")
                    })
                    .disabled(!isEditing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    if (isEditing || inventoryItemToDisplay.movingPriority != 3) ||
                       (isEditing || !inventoryItemToDisplay.roomDestination.isEmpty) {
                        Divider()
                            .padding(.leading, 16)
                    }
                    
                    if isEditing || inventoryItemToDisplay.movingPriority != 3 {
                        HStack {
                            Text("Moving Priority")
                                .foregroundColor(.primary)
                            Spacer()
                            Picker("Priority", selection: $inventoryItemToDisplay.movingPriority) {
                                Text("Low (1)").tag(1)
                                Text("Medium (2)").tag(2)
                                Text("Normal (3)").tag(3)
                                Text("High (4)").tag(4)
                                Text("Critical (5)").tag(5)
                            }
                            .pickerStyle(.menu)
                            .disabled(!isEditing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        if isEditing || !inventoryItemToDisplay.roomDestination.isEmpty {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                    
                    if isEditing || !inventoryItemToDisplay.roomDestination.isEmpty {
                        FormTextFieldRow(label: "Room Destination", text: $inventoryItemToDisplay.roomDestination, isEditing: $isEditing, placeholder: "Living Room")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(UIConstants.cornerRadius)
            }
        }
    }
    
    @ViewBuilder
    private var attachmentsSection: some View {
        if isEditing || hasAnyAttachments {
            VStack(alignment: .leading, spacing: 8) {
                Text("Attachments")
                    .sectionHeaderStyle()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    // Attachments
                    ForEach(Array(inventoryItemToDisplay.attachments.enumerated()), id: \.offset) { index, attachment in
                        AttachmentRowView(
                            url: attachment.url,
                            fileName: attachment.originalName,
                            isEditing: isEditing,
                            onDelete: {
                                confirmDeleteAttachment(url: attachment.url)
                            },
                            onTap: isEditing ? nil : {
                                openFileViewer(url: attachment.url, fileName: attachment.originalName)
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        if index < inventoryItemToDisplay.attachments.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                    attachmentButtonView
                       .padding()
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(UIConstants.cornerRadius)
            }
        }
    }
    
    @ViewBuilder
    private var photoPlaceHolder: some View {
        ZStack {
            Color.gray.opacity(0.1)

            VStack(spacing: 20) {
                Spacer()

                if isEditing {
                    Button {
                        showPhotoSourceAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "camera")
                            Text("Add Photo")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    .backport.glassProminentButtonStyle()
                    .accessibilityIdentifier("detailview-add-first-photo-button")
                    .confirmationDialog("Add Photo", isPresented: $showPhotoSourceAlert) {
                        Button("Take Photo") { showingSimpleCamera = true }
                            .accessibilityIdentifier("takePhoto")
                        Button("Scan Document") { showDocumentScanner = true }
                            .accessibilityIdentifier("scanDocument")
                        Button("Choose from Photos") { showPhotoPicker = true }
                            .accessibilityIdentifier("chooseFromLibrary")
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("No photos yet")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                Spacer()
                    .frame(height: 60)
            }
        }

    }

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
            .ignoresSafeArea(edges: .top)
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
            .onChange(of: displayPriceString) { _, _ in
                if isEditing {
                    hasUserMadeChanges = true
                }
            }
            .onChange(of: currentFieldsHash) { _, _ in
                if isEditing {
                    hasUserMadeChanges = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leadingToolbarButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    trailingToolbarButton
                }
            }
            .sheet(isPresented: $showingPaywall) {
                revenueCatManager.presentPaywall(
                    isPresented: $showingPaywall,
                    onCompletion: { settings.isPro = true },
                    onDismiss: nil
                )
            }
            .sheet(isPresented: $showingLocationSelection) {
                LocationSelectionView(selectedLocation: $inventoryItemToDisplay.location)
            }
            .sheet(isPresented: $showingLabelSelection) {
                LabelSelectionView(selectedLabel: $inventoryItemToDisplay.label)
            }
            .fileImporter(isPresented: $showDocumentPicker, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: false) { result in
                Task {
                    await handleAttachmentFileImport(result)
                }
            }
            .fullScreenCover(isPresented: $showingSimpleCamera) {
                SimpleCameraView(capturedImage: $capturedSingleImage)
                    .ignoresSafeArea()
                    .onChange(of: capturedSingleImage) { _, newImage in
                        if let image = newImage {
                            Task {
                                await handleNewPhotos([image])
                                capturedSingleImage = nil
                            }
                        }
                        showingSimpleCamera = false
                    }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotosPickerItems, maxSelectionCount: calculateRemainingPhotoCount(), matching: .images)
            .onChange(of: selectedPhotosPickerItems) { _, newItems in
                if !newItems.isEmpty {
                    Task {
                        await processSelectedPhotos(newItems)
                    }
                }
            }
            .sheet(isPresented: $showDocumentScanner) {
                DocumentCameraView { scannedImages in
                    Task {
                        await handleNewPhotos(scannedImages)
                    }
                    showDocumentScanner = false
                } onCancel: {
                    showDocumentScanner = false
                }
            }
            .sheet(isPresented: $showingFileViewer) {
                if let fileURL = fileViewerURL {
                    FileViewer(url: fileURL, fileName: fileViewerName)
                }
            }
            .fullScreenCover(isPresented: $showingFullScreenPhoto) {
                FullScreenPhotoView(
                    images: loadedImages,
                    initialIndex: selectedImageIndex,
                    isPresented: $showingFullScreenPhoto
                )
            }
            .confirmationDialog("Add Photo", isPresented: $showPhotoSourceAlert) {
                Button("Take Photo") { showingSimpleCamera = true }
                    .accessibilityIdentifier("takePhoto")
                Button("Scan Document") { showDocumentScanner = true }
                    .accessibilityIdentifier("scanDocument")
                Button("Choose from Photos") { showPhotoPicker = true }
                    .accessibilityIdentifier("chooseFromLibrary")
            }
            .alert("AI Analysis Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Attachment", isPresented: $showingDeleteAttachmentAlert) {
                Button("Delete", role: .destructive) {
                    executeDeleteAttachment()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this attachment? This action cannot be undone.")
            }
            .alert("Discard Changes", isPresented: $showUnsavedChangesAlert) {
                Button("Discard", role: .destructive) {
                    // Restore original values
                    if let original = originalValues {
                        original.restore(to: inventoryItemToDisplay)
                        displayPriceString = originalDisplayPriceString
                    }
                    hasUserMadeChanges = false

                    if onCancel != nil {
                        // We're in a sheet context - discard changes and close sheet
                        deleteItemAndCloseSheet()
                    } else {
                        // We're in regular navigation - exit edit mode
                        isEditing = false
                    }
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Delete Item", isPresented: $showingDeleteItemAlert) {
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteItem()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this item? This action cannot be undone.")
            }
            .task(id: inventoryItemToDisplay.imageURL) {
                await loadAllImages()
            }
            .sentryTrace("InventoryDetailView")
    }

    private func performAIAnalysis() {
        Task {
            await MainActor.run {
                isLoadingOpenAiResults = true
            }
            
            do {
                let imageDetails = try await callOpenAI()
                await MainActor.run {
                    // Ensure the item is in the model context
                    if inventoryItemToDisplay.modelContext == nil {
                        modelContext.insert(inventoryItemToDisplay)
                    }
                    
                    // Get all labels and locations for the unified update
                    let labels = (try? modelContext.fetch(FetchDescriptor<InventoryLabel>())) ?? []
                    let locations = (try? modelContext.fetch(FetchDescriptor<InventoryLocation>())) ?? []
                    
                    inventoryItemToDisplay.updateFromImageDetails(imageDetails, labels: labels, locations: locations)
                    
                    // Update display price string to reflect any price changes
                    displayPriceString = formatInitialPrice(inventoryItemToDisplay.price)
                    
                    // Save the context
                    try? modelContext.save()
                    
                    isLoadingOpenAiResults = false
                }
            } catch OpenAIError.invalidURL {
                await MainActor.run {
                    errorMessage = "Invalid URL configuration"
                    showingErrorAlert = true
                    isLoadingOpenAiResults = false
                }
            } catch OpenAIError.invalidResponse {
                await MainActor.run {
                    errorMessage = "Error communicating with AI service"
                    showingErrorAlert = true
                    isLoadingOpenAiResults = false
                }
            } catch OpenAIError.invalidData {
                await MainActor.run {
                    errorMessage = "Unable to process AI response"
                    showingErrorAlert = true
                    isLoadingOpenAiResults = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    showingErrorAlert = true
                    isLoadingOpenAiResults = false
                }
            }
        }
    }
    
    private func callOpenAI() async throws -> ImageDetails {
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
        
        let openAi = OpenAIServiceFactory.create()
        
        TelemetryManager.shared.trackCameraAnalysisUsed()
        
        return try await openAi.getImageDetails(
            from: loadedImages,
            settings: settings,
            modelContext: modelContext
        )
    }
    
    
    private func openFileViewer(url: String, fileName: String? = nil) {
        guard let fileURL = URL(string: url) else { return }
        fileViewerURL = fileURL
        fileViewerName = fileName
        showingFileViewer = true
    }
    
    private func confirmDeleteAttachment(url: String) {
        attachmentToDelete = url
        showingDeleteAttachmentAlert = true
    }
    
    private func executeDeleteAttachment() {
        guard let urlToDelete = attachmentToDelete else { return }
        Task {
            await deleteAttachment(urlToDelete)
        }
        attachmentToDelete = nil
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
        modelContext.insert(label)
        inventoryItemToDisplay.label = label
        router.navigate(to: .editLabelView(label: label, isEditing: true))
    }
    
    private func handleNewPhotos(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        
        do {
            // Ensure we have a consistent itemId for all operations
            let itemId = inventoryItemToDisplay.assetId.isEmpty ? UUID().uuidString : inventoryItemToDisplay.assetId
            
            if inventoryItemToDisplay.imageURL == nil {
                // No primary image yet, save the first image as primary
                guard let firstImage = images.first else {
                    throw NSError(domain: "InventoryDetailView", code: 1, userInfo: [NSLocalizedDescriptionKey: "No images provided"])
                }
                let primaryImageURL = try await OptimizedImageManager.shared.saveImage(firstImage, id: itemId)
                
                await MainActor.run {
                    inventoryItemToDisplay.imageURL = primaryImageURL
                    inventoryItemToDisplay.assetId = itemId
                }
                
                // Save remaining images as secondary photos
                if images.count > 1 {
                    let secondaryImages = Array(images.dropFirst())
                    let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(secondaryImages, itemId: itemId)
                    
                    await MainActor.run {
                        inventoryItemToDisplay.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
                    }
                }
            } else {
                // Primary image exists, add all new images as secondary photos
                let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(images, itemId: itemId)
                
                await MainActor.run {
                    inventoryItemToDisplay.assetId = itemId
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
                        if let firstSecondaryURLString = inventoryItemToDisplay.secondaryPhotoURLs.first,
                           let firstSecondaryURL = URL(string: firstSecondaryURLString) {
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
        await MainActor.run {
            isLoading = true
            loadingError = nil
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        var images: [UIImage] = []
        var encounteredError: Error?
        
        do {
            // Use PhotoManageable protocol which handles URL migration automatically
            images = try await inventoryItemToDisplay.allPhotos
        } catch {
            print("Failed to load images using PhotoManageable protocol: \(error)")
            encounteredError = error
            
            // Fallback to direct loading if PhotoManageable fails
            // Load primary image
            if let imageURL = inventoryItemToDisplay.imageURL {
                do {
                    let image = try await OptimizedImageManager.shared.loadImage(url: imageURL)
                    images.append(image)
                    encounteredError = nil // Clear error if we successfully load at least one image
                } catch {
                    print("Failed to load primary image: \(error)")
                }
            }
            
            // Load secondary images
            if !inventoryItemToDisplay.secondaryPhotoURLs.isEmpty {
                do {
                    let secondaryImages = try await OptimizedImageManager.shared.loadSecondaryImages(from: inventoryItemToDisplay.secondaryPhotoURLs)
                    images.append(contentsOf: secondaryImages)
                    encounteredError = nil // Clear error if we successfully load at least one image
                } catch {
                    print("Failed to load secondary images: \(error)")
                }
            }
        }
        
        await MainActor.run {
            loadedImages = images
            loadingError = images.isEmpty ? encounteredError : nil
            if selectedImageIndex >= images.count {
                selectedImageIndex = max(0, images.count - 1)
            }
        }
    }
    
    private func calculateRemainingPhotoCount() -> Int {
        let currentPhotoCount = (inventoryItemToDisplay.imageURL != nil ? 1 : 0) + inventoryItemToDisplay.secondaryPhotoURLs.count
        let maxPhotos = settings.isPro ? 5 : 1
        return max(0, maxPhotos - currentPhotoCount)
    }
    
    private func formatInitialPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "0.00"
    }
    
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        
        var images: [UIImage] = []
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        
        if !images.isEmpty {
            await handleNewPhotos(images)
        }
        
        // Clear selected items after processing
        await MainActor.run {
            selectedPhotosPickerItems = []
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

    private func deleteItem() async {
        do {
            // Delete all associated images
            if let imageURL = inventoryItemToDisplay.imageURL {
                try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: imageURL.absoluteString)
            }

            for photoURL in inventoryItemToDisplay.secondaryPhotoURLs {
                try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: photoURL)
            }

            // Delete all attachments
            for attachment in inventoryItemToDisplay.attachments {
                try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: attachment.url)
            }
        } catch {
            print("Error deleting images during item deletion: \(error)")
        }

        await MainActor.run {
            // Remove the item from the model context
            modelContext.delete(inventoryItemToDisplay)
            try? modelContext.save()

            // Navigate back
            dismiss()
        }
    }

    private func regenerateMissingThumbnails() async {
        // Check and regenerate primary image thumbnail
        if let imageURL = inventoryItemToDisplay.imageURL {
            do {
                try await OptimizedImageManager.shared.regenerateThumbnail(for: imageURL)
            } catch {
                print("📸 Failed to regenerate thumbnail for primary image: \(error)")
            }
        }

        // Check and regenerate secondary image thumbnails
        for urlString in inventoryItemToDisplay.secondaryPhotoURLs {
            guard let url = URL(string: urlString) else { continue }
            do {
                try await OptimizedImageManager.shared.regenerateThumbnail(for: url)
            } catch {
                print("📸 Failed to regenerate thumbnail for secondary image: \(error)")
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
                                    .accessibilityIdentifier("photoCountText")
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

// MARK: - Document Camera View

struct DocumentCameraView: UIViewControllerRepresentable {
    let onComplete: ([UIImage]) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraView
        
        init(_ parent: DocumentCameraView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var scannedImages: [UIImage] = []
            // Limit to 1 image per session for simplicity
            let maxImages = min(1, scan.pageCount)
            for pageIndex in 0..<maxImages {
                let image = scan.imageOfPage(at: pageIndex)
                scannedImages.append(image)
            }
            parent.onComplete(scannedImages)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document camera failed with error: \(error)")
            parent.onCancel()
        }
    }
}

// MARK: - Attachment Row View

struct AttachmentRowView: View {
    let url: String
    let fileName: String
    let isEditing: Bool
    let onDelete: () -> Void
    let onTap: (() -> Void)?
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray4))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "doc")
                                .foregroundColor(.secondary)
                        }
                }
            }
            
            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let url = URL(string: url) {
                    Text(url.pathExtension.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Delete button (edit mode only)
            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing, let onTap = onTap {
                onTap()
            }
        }
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        guard let fileURL = URL(string: url) else { return }
        
        do {
            // Try to load as image first
            let image = try await OptimizedImageManager.shared.loadImage(url: fileURL)
            await MainActor.run {
                thumbnail = image
            }
        } catch {
            // Generate PDF thumbnail if it's a PDF file
            if fileURL.pathExtension.lowercased() == "pdf" {
                if let pdfThumbnail = await generatePDFThumbnail(from: fileURL) {
                    await MainActor.run {
                        thumbnail = pdfThumbnail
                    }
                }
            }
            // For other document types, use the default document icon
        }
    }
    
    private func generatePDFThumbnail(from url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                guard let document = PDFDocument(url: url),
                      let page = document.page(at: 0) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let pageRect = page.bounds(for: .mediaBox)
                let thumbnailSize = CGSize(width: 44, height: 44)
                
                // Calculate scale to fit within thumbnail size while maintaining aspect ratio
                let widthScale = thumbnailSize.width / pageRect.width
                let heightScale = thumbnailSize.height / pageRect.height
                let scale = min(widthScale, heightScale)
                
                let scaledSize = CGSize(
                    width: pageRect.width * scale,
                    height: pageRect.height * scale
                )
                
                let renderer = UIGraphicsImageRenderer(size: scaledSize)
                let image = renderer.image { context in
                    // Fill with white background
                    UIColor.white.set()
                    context.fill(CGRect(origin: .zero, size: scaledSize))
                    
                    // Scale and draw the PDF page
                    context.cgContext.scaleBy(x: scale, y: scale)
                    page.draw(with: .mediaBox, to: context.cgContext)
                }
                
                continuation.resume(returning: image)
            }
        }
    }
}


#Preview {
    struct PreviewWrapper: View {
        @State private var previewItem: InventoryItem
        
        init() {
            let location = InventoryLocation(name: "Office", desc: "My office")
            let item = InventoryItem(
                title: "MacBook Pro",
                quantityString: "1",
                quantityInt: 1,
                desc: "16-inch 2023 Model",
                serial: "SN12345ABC",
                model: "MacBook Pro M2",
                make: "Apple",
                location: location,
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

// MARK: - Attachment Handling Methods

extension InventoryDetailView {
    private func deleteAttachment(_ urlString: String) async {
        guard URL(string: urlString) != nil else { return }
        
        do {
            // Delete from storage
            try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: urlString)
            
            await MainActor.run {
                inventoryItemToDisplay.removeAttachment(url: urlString)
                try? modelContext.save()
            }
        } catch {
            print("Error deleting attachment: \(error)")
        }
    }
    
    private func handleAttachmentFileImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                // Start accessing the security-scoped resource
                let startedAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if startedAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                // Copy the file to our app's storage
                let attachmentId = UUID().uuidString
                let data = try Data(contentsOf: url)
                let originalName = url.lastPathComponent
                
                // For images, use OptimizedImageManager; for other files, copy to Documents directory
                let destinationURL: URL
                if let image = UIImage(data: data) {
                    destinationURL = try await OptimizedImageManager.shared.saveImage(image, id: attachmentId)
                } else {
                    // Copy to Documents directory for non-image files
                    guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        throw NSError(domain: "InventoryDetailView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot access documents directory"])
                    }
                    destinationURL = documentsURL.appendingPathComponent(attachmentId + "." + url.pathExtension)
                    try data.write(to: destinationURL)
                }
                
                await MainActor.run {
                    inventoryItemToDisplay.addAttachment(url: destinationURL.absoluteString, originalName: originalName)
                    do {
                        try modelContext.save()
                        print("✅ Successfully saved attachment: \(originalName)")
                    } catch {
                        print("❌ Failed to save attachment: \(error)")
                    }
                }
            } catch {
                print("Failed to save attachment file: \(error)")
            }
            
        case .failure(let error):
            print("File import failed: \(error)")
        }
    }
}

// MARK: - Inventory Item Snapshot

@MainActor
struct InventoryItemSnapshot {
    let title: String
    let quantityString: String
    let quantityInt: Int
    let desc: String
    let serial: String
    let model: String
    let make: String
    let price: Decimal
    let insured: Bool
    let notes: String
    let hasWarranty: Bool
    let warrantyExpirationDate: Date?
    let purchaseDate: Date?
    let purchaseLocation: String
    let condition: String
    let depreciationRate: Double?
    let replacementCost: Decimal?
    let dimensionLength: String
    let dimensionWidth: String
    let dimensionHeight: String
    let dimensionUnit: String
    let weightValue: String
    let weightUnit: String
    let color: String
    let storageRequirements: String
    let isFragile: Bool
    let movingPriority: Int
    let roomDestination: String
    
    init(from item: InventoryItem) {
        self.title = item.title
        self.quantityString = item.quantityString
        self.quantityInt = item.quantityInt
        self.desc = item.desc
        self.serial = item.serial
        self.model = item.model
        self.make = item.make
        self.price = item.price
        self.insured = item.insured
        self.notes = item.notes
        self.hasWarranty = item.hasWarranty
        self.warrantyExpirationDate = item.warrantyExpirationDate
        self.purchaseDate = item.purchaseDate
        self.purchaseLocation = item.purchaseLocation
        self.condition = item.condition
        self.depreciationRate = item.depreciationRate
        self.replacementCost = item.replacementCost
        self.dimensionLength = item.dimensionLength
        self.dimensionWidth = item.dimensionWidth
        self.dimensionHeight = item.dimensionHeight
        self.dimensionUnit = item.dimensionUnit
        self.weightValue = item.weightValue
        self.weightUnit = item.weightUnit
        self.color = item.color
        self.storageRequirements = item.storageRequirements
        self.isFragile = item.isFragile
        self.movingPriority = item.movingPriority
        self.roomDestination = item.roomDestination
    }
    
    func restore(to item: InventoryItem) {
        item.title = title
        item.quantityString = quantityString
        item.quantityInt = quantityInt
        item.desc = desc
        item.serial = serial
        item.model = model
        item.make = make
        item.price = price
        item.insured = insured
        item.notes = notes
        item.hasWarranty = hasWarranty
        item.warrantyExpirationDate = warrantyExpirationDate
        item.purchaseDate = purchaseDate
        item.purchaseLocation = purchaseLocation
        item.condition = condition
        item.depreciationRate = depreciationRate
        item.replacementCost = replacementCost
        item.dimensionLength = dimensionLength
        item.dimensionWidth = dimensionWidth
        item.dimensionHeight = dimensionHeight
        item.dimensionUnit = dimensionUnit
        item.weightValue = weightValue
        item.weightUnit = weightUnit
        item.color = color
        item.storageRequirements = storageRequirements
        item.isFragile = isFragile
        item.movingPriority = movingPriority
        item.roomDestination = roomDestination
    }
}

// MARK: - View Extensions

extension View {
    func applyNavigationSettings(title: String, isEditing: Bool, colorScheme: ColorScheme) -> some View {
        self
            .navigationTitle(getNavigationTitle(title: title))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isEditing)
    }
    
    private func getNavigationTitle(title: String) -> String {
        if #available(iOS 26.0, *) {
            return title
        } else {
            return ""
        }
    }
}

// MARK: - Conditional Toolbar Background Modifier

struct ConditionalToolbarBackgroundModifier: ViewModifier {
    let colorScheme: ColorScheme
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // For iOS 26 and above, hide the toolbar background
            content
                .toolbarBackground(.hidden, for: .navigationBar)
        } else {
            // For iOS 18 and below, maintain existing functionality
            content
                .toolbarBackground(colorScheme == .dark ? .black : .white, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - File Viewer

struct FileViewer: View {
    let url: URL
    let fileName: String?
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationView {
            QuickLookPreview(url: url)
                .ignoresSafeArea()
                .navigationTitle(fileName ?? url.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [createSharableItem()])
        }
    }
    
    private func createSharableItem() -> URL {
        // If we have an original filename, create a temporary copy with that name
        guard let originalFileName = fileName,
              originalFileName != url.lastPathComponent else {
            // No original filename or it's the same, just return the original URL
            return url
        }
        
        // Create a temporary directory for sharing
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("MovingBoxShare", isDirectory: true)
        
        do {
            // Ensure temp directory exists
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Create temp file with original filename
            let tempFile = tempDir.appendingPathComponent(originalFileName)
            
            // Remove any existing temp file
            try? FileManager.default.removeItem(at: tempFile)
            
            // Copy the file to temp location with original filename
            try FileManager.default.copyItem(at: url, to: tempFile)
            
            return tempFile
        } catch {
            print("Failed to create temporary file for sharing: \(error)")
            // Fallback to original URL if temp copy fails
            return url
        }
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: QLPreviewControllerDataSource {
        let url: URL
        
        init(url: URL) {
            self.url = url
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as QLPreviewItem
        }
    }
}

