//
//  InventoryDetail.swift
//  MovingBox
//
//  Created by Camden Webster on 5/16/24.
//

import Dependencies
import PDFKit
import PhotosUI
import QuickLook
import RevenueCatUI
import SQLiteData
import SentrySwiftUI
import SwiftUI
import VisionKit

@MainActor
struct InventoryDetailView: View {
    @Dependency(\.defaultDatabase) var database
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @FocusState private var isPriceFieldFocused: Bool

    // Photo section frame height constants
    private static let photoSectionHeight: CGFloat = 300
    private static let photoSectionHeightWithPhotos: CGFloat = 350

    // Core item state — loaded from SQLite
    let itemID: UUID
    @State private var item: SQLiteInventoryItem
    @State private var aiAnalysisCount: Int = 0

    @State private var displayPriceString: String = ""
    @State private var imageDetailsFromOpenAI: ImageDetails = ImageDetails.empty()
    @FocusState private var inputIsFocused: Bool
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
            item.title,
            item.desc,
            item.serial,
            item.make,
            item.model,
            item.notes,
            item.purchaseLocation,
            item.condition,
            item.color,
            item.storageRequirements,
            item.roomDestination,
            item.dimensionLength,
            item.dimensionWidth,
            item.dimensionHeight,
            item.dimensionUnit,
            item.weightValue,
            item.weightUnit,
            String(item.quantityInt),
            String(item.isFragile),
            String(item.hasWarranty),
            String(item.movingPriority),
            String(describing: item.replacementCost),
            String(describing: item.depreciationRate),
            String(describing: item.purchaseDate),
            String(describing: item.warrantyExpirationDate),
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

    // SQLite-typed selection state for location/home/labels
    @State private var sqliteSelectedLocation: SQLiteInventoryLocation?
    @State private var sqliteSelectedHome: SQLiteHome?
    @State private var sqliteSelectedLabels: [SQLiteInventoryLabel] = []
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

    // MARK: - Primary init (UUID-based)
    init(
        itemID: UUID,
        navigationPath: Binding<NavigationPath>,
        showSparklesButton: Bool = false,
        isEditing: Bool = false,
        onSave: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.itemID = itemID
        self._item = State(initialValue: SQLiteInventoryItem(id: itemID))
        self._navigationPath = navigationPath
        self.showSparklesButton = showSparklesButton
        self._isEditing = State(initialValue: isEditing)
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
        item.purchaseDate != nil || !item.purchaseLocation.isEmpty
            || !item.condition.isEmpty
    }

    private var hasAnyFinancialData: Bool {
        item.replacementCost != nil || item.depreciationRate != nil
    }

    private var hasAnyPhysicalPropertiesData: Bool {
        !item.dimensionLength.isEmpty
            || !item.dimensionWidth.isEmpty
            || !item.dimensionHeight.isEmpty
            || !item.weightValue.isEmpty || !item.color.isEmpty
            || !item.storageRequirements.isEmpty
    }

    private var hasAnyMovingOptimizationData: Bool {
        item.isFragile || item.movingPriority != 3
            || !item.roomDestination.isEmpty
    }

    private var hasAnyAttachments: Bool {
        !item.attachments.isEmpty
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
                Task {
                    await saveItemToSQLite()
                    hasUserMadeChanges = false
                    originalValues = nil
                    isEditing = false
                    await regenerateMissingThumbnails()
                    onSave?()
                }
            }
            .backport.glassProminentButtonStyle()
            .fontWeight(.bold)
            .disabled(item.title.isEmpty || isLoadingOpenAiResults)
            .accessibilityIdentifier("save")
        } else {
            Button("Edit") {
                // Capture original state before entering edit mode
                originalValues = InventoryItemSnapshot(from: item)
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
                .frame(
                    width: proxy.size.width, height: Self.photoSectionHeight + (scrollY > 0 ? scrollY : 0)
                )
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
                .frame(
                    width: proxy.size.width, height: Self.photoSectionHeight + (scrollY > 0 ? scrollY : 0)
                )
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
                            let currentPhotoCount =
                                (item.imageURL != nil ? 1 : 0)
                                + item.secondaryPhotoURLs.count
                            if currentPhotoCount < (settings.isPro ? 5 : 1) {
                                showPhotoSourceAlert = true
                            }
                        },
                        onDeletePhoto: { index in
                            Task {
                                let urlString: String
                                if index == 0 {
                                    // Deleting primary image
                                    if let imageURL = item.imageURL {
                                        urlString = imageURL.absoluteString
                                    } else {
                                        return
                                    }
                                } else {
                                    // Deleting secondary image
                                    let secondaryIndex = index - 1
                                    if secondaryIndex < item.secondaryPhotoURLs.count {
                                        urlString = item.secondaryPhotoURLs[secondaryIndex]
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
                    .frame(
                        width: proxy.size.width,
                        height: Self.photoSectionHeightWithPhotos + (scrollY > 0 ? scrollY : 0)
                    )
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
                                            if let imageURL = item.imageURL {
                                                urlString = imageURL.absoluteString
                                            } else {
                                                return
                                            }
                                        } else {
                                            // Deleting secondary image
                                            let secondaryIndex = selectedImageIndex - 1
                                            if secondaryIndex < item.secondaryPhotoURLs.count {
                                                urlString = item.secondaryPhotoURLs[secondaryIndex]
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
                            let currentPhotoCount =
                                (item.imageURL != nil ? 1 : 0)
                                + item.secondaryPhotoURLs.count
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
                    .frame(
                        width: proxy.size.width, height: Self.photoSectionHeight + (scrollY > 0 ? scrollY : 0)
                    )
                    .offset(y: scrollY > 0 ? -scrollY : 0)
            }
            .frame(height: Self.photoSectionHeight)
        }
    }

    @ViewBuilder
    private var formContent: some View {
        VStack(spacing: 0) {
            // AI Button and Receipt Button Section
            if isEditing && item.imageURL != nil {
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

                if isEditing || item.quantityInt > 1 {
                    quantitySection
                }

                if isEditing || !item.desc.isEmpty {
                    descriptionSection
                }

                priceSection
                locationsAndLabelsSection

                purchaseTrackingSection
                financialSection
                physicalPropertiesSection
                movingOptimizationSection
                attachmentsSection

                if isEditing || !item.notes.isEmpty {
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
            if settings.shouldShowPaywallForAiScan(currentCount: aiAnalysisCount) {
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
                if isEditing || !item.title.isEmpty {
                    FormTextFieldRow(
                        label: "Title", text: $item.title, isEditing: $isEditing,
                        placeholder: "Desktop Computer"
                    )
                    .focused($focusedField, equals: .title)
                    .accessibilityIdentifier("titleField")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if (isEditing || !item.serial.isEmpty)
                        || (isEditing || !item.make.isEmpty)
                        || (isEditing || !item.model.isEmpty)
                    {
                        Divider()
                            .padding(.leading, 16)
                    }
                }

                if isEditing || !item.serial.isEmpty {
                    FormTextFieldRow(
                        label: "Serial Number", text: $item.serial, isEditing: $isEditing,
                        placeholder: "SN-12345"
                    )
                    .focused($focusedField, equals: .serial)
                    .accessibilityIdentifier("serialField")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if (isEditing || !item.make.isEmpty)
                        || (isEditing || !item.model.isEmpty)
                    {
                        Divider()
                            .padding(.leading, 16)
                    }
                }

                if isEditing || !item.make.isEmpty {
                    FormTextFieldRow(
                        label: "Make", text: $item.make, isEditing: $isEditing,
                        placeholder: "Apple"
                    )
                    .focused($focusedField, equals: .make)
                    .accessibilityIdentifier("makeField")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if isEditing || !item.model.isEmpty {
                        Divider()
                            .padding(.leading, 16)
                    }
                }

                if isEditing || !item.model.isEmpty {
                    FormTextFieldRow(
                        label: "Model", text: $item.model, isEditing: $isEditing,
                        placeholder: "Mac Mini"
                    )
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
                Stepper(
                    "\(item.quantityInt)", value: $item.quantityInt,
                    in: 1...1000, step: 1
                )
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
                TextEditor(text: $item.desc)
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
                    priceDecimal: $item.price,
                    isEditing: $isEditing
                )
                .disabled(!isEditing)
                .accessibilityIdentifier("priceField")
                .foregroundColor(isEditing ? .primary : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .padding(.leading, 16)

                Toggle(
                    isOn: $item.hasWarranty,
                    label: {
                        Text("Warranty")
                    }
                )
                .disabled(!isEditing)
                .accessibilityIdentifier("warrantyToggle")
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if item.hasWarranty {
                    Divider()
                        .padding(.leading, 16)

                    DatePicker(
                        "Warranty Expires",
                        selection: Binding(
                            get: { item.warrantyExpirationDate ?? Date() },
                            set: { item.warrantyExpirationDate = $0 }
                        ),
                        displayedComponents: .date
                    )
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
        if isEditing || sqliteSelectedLocation != nil || sqliteSelectedHome != nil
            || !sqliteSelectedLabels.isEmpty
        {
            VStack(alignment: .leading, spacing: 8) {
                Text("Location & Labels")
                    .sectionHeaderStyle()
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    if isEditing || sqliteSelectedLocation != nil
                        || sqliteSelectedHome != nil
                    {
                        Button(action: {
                            if isEditing {
                                showingLocationSelection = true
                            }
                        }) {
                            HStack {
                                Text("Location")
                                    .foregroundColor(.primary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(sqliteSelectedLocation?.name ?? "None")
                                    if let home = sqliteSelectedHome {
                                        Text(home.name)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .disabled(!isEditing)
                        .accessibilityIdentifier("locationPicker")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if isEditing || !sqliteSelectedLabels.isEmpty {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    if isEditing || !sqliteSelectedLabels.isEmpty {
                        Button(action: {
                            if isEditing {
                                showingLabelSelection = true
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(sqliteSelectedLabels.count == 1 ? "Label" : "Labels")
                                        .foregroundColor(.primary)
                                    if !sqliteSelectedLabels.isEmpty {
                                        // Show labels as capsules in a flow layout
                                        FlowLayout(spacing: 6) {
                                            ForEach(sqliteSelectedLabels.prefix(5)) { label in
                                                LabelCapsuleView(label: label)
                                            }
                                        }
                                    }
                                }
                                Spacer()
                                if sqliteSelectedLabels.isEmpty {
                                    Text("None")
                                }
                                if isEditing {
                                    Image(systemName: "plus")
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
                TextEditor(text: $item.notes)
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
                    if isEditing || item.purchaseDate != nil {
                        DatePicker(
                            "Purchase Date",
                            selection: Binding(
                                get: { item.purchaseDate ?? Date() },
                                set: { item.purchaseDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .disabled(!isEditing)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if isEditing || !item.purchaseLocation.isEmpty {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    if isEditing || !item.purchaseLocation.isEmpty {
                        FormTextFieldRow(
                            label: "Purchase Location", text: $item.purchaseLocation,
                            isEditing: $isEditing, placeholder: "Apple Store"
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if isEditing || !item.condition.isEmpty {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    if isEditing || !item.condition.isEmpty {
                        ConditionPickerRow(condition: $item.condition, isEditing: $isEditing)
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
                    if isEditing || item.replacementCost != nil {
                        CurrencyFieldRow(
                            label: "Replacement Cost", value: $item.replacementCost,
                            isEditing: $isEditing
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if isEditing || item.depreciationRate != nil {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    if isEditing || item.depreciationRate != nil {
                        PercentageFieldRow(
                            label: "Depreciation Rate", value: $item.depreciationRate,
                            isEditing: $isEditing
                        )
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
                    if isEditing || !item.dimensionLength.isEmpty
                        || !item.dimensionWidth.isEmpty
                        || !item.dimensionHeight.isEmpty
                    {
                        DimensionsFieldRow(
                            length: $item.dimensionLength,
                            width: $item.dimensionWidth,
                            height: $item.dimensionHeight,
                            unit: $item.dimensionUnit,
                            isEditing: $isEditing
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if (isEditing || !item.weightValue.isEmpty)
                            || (isEditing || !item.condition.isEmpty)
                            || (isEditing || !item.color.isEmpty)
                            || (isEditing || !item.storageRequirements.isEmpty)
                        {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    if isEditing || !item.weightValue.isEmpty {
                        WeightFieldRow(
                            value: $item.weightValue,
                            unit: $item.weightUnit,
                            isEditing: $isEditing
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if (isEditing || !item.color.isEmpty)
                            || (isEditing || !item.storageRequirements.isEmpty)
                        {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    if isEditing || !item.color.isEmpty {
                        FormTextFieldRow(
                            label: "Color", text: $item.color, isEditing: $isEditing,
                            placeholder: "Space Gray"
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if isEditing || !item.storageRequirements.isEmpty {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    if isEditing || !item.storageRequirements.isEmpty {
                        FormTextFieldRow(
                            label: "Storage Requirements", text: $item.storageRequirements,
                            isEditing: $isEditing, placeholder: "Keep upright, dry environment"
                        )
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
                    Toggle(
                        isOn: $item.isFragile,
                        label: {
                            Text("Fragile Item")
                        }
                    )
                    .disabled(!isEditing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if (isEditing || item.movingPriority != 3)
                        || (isEditing || !item.roomDestination.isEmpty)
                    {
                        Divider()
                            .padding(.leading, 16)
                    }

                    if isEditing || item.movingPriority != 3 {
                        HStack {
                            Text("Moving Priority")
                                .foregroundColor(.primary)
                            Spacer()
                            Picker("Priority", selection: $item.movingPriority) {
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

                        if isEditing || !item.roomDestination.isEmpty {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    if isEditing || !item.roomDestination.isEmpty {
                        FormTextFieldRow(
                            label: "Room Destination", text: $item.roomDestination,
                            isEditing: $isEditing, placeholder: "Living Room"
                        )
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
                    ForEach(Array(item.attachments.enumerated()), id: \.offset) {
                        index, attachment in
                        AttachmentRowView(
                            url: attachment.url,
                            fileName: attachment.originalName,
                            isEditing: isEditing,
                            onDelete: {
                                confirmDeleteAttachment(url: attachment.url)
                            },
                            onTap: isEditing
                                ? nil
                                : {
                                    openFileViewer(url: attachment.url, fileName: attachment.originalName)
                                }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < item.attachments.count - 1 {
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
        .task {
            await loadItemFromSQLite()
        }
    }

    var body: some View {
        bodyContent
    }

    private var bodyContent: some View {
        bodySheets
            .confirmationDialog("Add Photo", isPresented: $showPhotoSourceAlert) {
                Button("Take Photo") { showingSimpleCamera = true }
                    .accessibilityIdentifier("takePhoto")
                Button("Scan Document") { showDocumentScanner = true }
                    .accessibilityIdentifier("scanDocument")
                Button("Choose from Photos") { showPhotoPicker = true }
                    .accessibilityIdentifier("chooseFromLibrary")
            }
            .alert("AI Analysis Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Attachment", isPresented: $showingDeleteAttachmentAlert) {
                Button("Delete", role: .destructive) {
                    executeDeleteAttachment()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this attachment? This action cannot be undone.")
            }
            .alert("Discard Changes", isPresented: $showUnsavedChangesAlert) {
                Button("Discard", role: .destructive) {
                    // Restore original values
                    if let original = originalValues {
                        original.restore(to: &item)
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
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Delete Item", isPresented: $showingDeleteItemAlert) {
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteItem()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this item? This action cannot be undone.")
            }
            .task(id: item.imageURL) {
                await loadAllImages()
            }
            .sentryTrace("InventoryDetailView")
    }

    private var bodySheets: some View {
        mainContent
            .applyNavigationSettings(
                title: item.title,
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
                LocationSelectionView(
                    selectedLocation: $sqliteSelectedLocation,
                    selectedHome: $sqliteSelectedHome
                )
            }
            .onChange(of: sqliteSelectedLocation) { _, newLocation in
                handleLocationChange(newLocation)
            }
            .onChange(of: sqliteSelectedHome) { _, newHome in
                handleHomeChange(newHome)
            }
            .sheet(isPresented: $showingLabelSelection) {
                LabelSelectionView(selectedLabels: $sqliteSelectedLabels)
            }
            .fileImporter(
                isPresented: $showDocumentPicker, allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
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
            .photosPicker(
                isPresented: $showPhotoPicker, selection: $selectedPhotosPickerItems,
                maxSelectionCount: calculateRemainingPhotoCount(), matching: .images
            )
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
    }

    private func performAIAnalysis() {
        Task {
            isLoadingOpenAiResults = true

            do {
                let imageDetails = try await callOpenAI()

                // Load labels and locations from SQLite for matching
                let labels =
                    (try? await database.read { db in
                        try SQLiteInventoryLabel.all.fetchAll(db)
                    }) ?? []
                let locations =
                    (try? await database.read { db in
                        try SQLiteInventoryLocation.all.fetchAll(db)
                    }) ?? []

                // Update item state from AI results
                updateItemFromImageDetails(imageDetails, labels: labels, locations: locations)

                // Update display price string to reflect any price changes
                displayPriceString = formatInitialPrice(item.price)

                // Save to SQLite
                await saveItemToSQLite()

                isLoadingOpenAiResults = false
            } catch OpenAIError.invalidURL {
                errorMessage = "Invalid URL configuration"
                showingErrorAlert = true
                isLoadingOpenAiResults = false
            } catch OpenAIError.invalidResponse {
                errorMessage = "Error communicating with AI service"
                showingErrorAlert = true
                isLoadingOpenAiResults = false
            } catch OpenAIError.invalidData {
                errorMessage = "Unable to process AI response"
                showingErrorAlert = true
                isLoadingOpenAiResults = false
            } catch {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                showingErrorAlert = true
                isLoadingOpenAiResults = false
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
            database: database
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
    //        item.title = ""
    //        item.label = nil
    //        item.desc = ""
    //        item.make = ""
    //        item.model = ""
    //        item.location = nil
    //        item.price = 0
    //        item.notes = ""
    //    }

    private func addLocation() {
        let locationID = UUID()
        Task {
            try? await database.write { db in
                try SQLiteInventoryLocation.insert {
                    SQLiteInventoryLocation(id: locationID, name: "")
                }.execute(db)
            }
            TelemetryManager.shared.trackLocationCreated(name: "")
            item.locationID = locationID
            router.navigate(to: .editLocationView(locationID: locationID, isEditing: true))
        }
    }

    private func addLabel() {
        let labelID = UUID()
        Task {
            try? await database.write { db in
                try SQLiteInventoryLabel.insert {
                    SQLiteInventoryLabel(id: labelID, name: "")
                }.execute(db)
            }
            sqliteSelectedLabels = [SQLiteInventoryLabel(id: labelID, name: "")]
            router.navigate(to: .editLabelView(labelID: labelID, isEditing: true))
        }
    }

    // MARK: - Location/Home/Label Change Handlers

    private func handleLocationChange(_ newLocation: SQLiteInventoryLocation?) {
        item.locationID = newLocation?.id
        // Update home from location's homeID
        if let homeID = newLocation?.homeID {
            Task {
                if let home = try? await database.read({ db in
                    try SQLiteHome.find(homeID).fetchOne(db)
                }) {
                    sqliteSelectedHome = home
                    item.homeID = home.id
                }
            }
        }
    }

    private func handleHomeChange(_ newHome: SQLiteHome?) {
        item.homeID = newHome?.id
    }

    private func handleNewPhotos(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }

        do {
            // Ensure we have a consistent itemId for all operations
            let itemId =
                item.assetId.isEmpty ? UUID().uuidString : item.assetId

            if item.imageURL == nil {
                // No primary image yet, save the first image as primary
                guard let firstImage = images.first else {
                    throw NSError(
                        domain: "InventoryDetailView", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "No images provided"])
                }
                let primaryImageURL = try await OptimizedImageManager.shared.saveImage(
                    firstImage, id: itemId)

                await MainActor.run {
                    item.imageURL = primaryImageURL
                    item.assetId = itemId
                }

                // Save remaining images as secondary photos
                if images.count > 1 {
                    let secondaryImages = Array(images.dropFirst())
                    let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(
                        secondaryImages, itemId: itemId)

                    await MainActor.run {
                        item.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
                    }
                }
            } else {
                // Primary image exists, add all new images as secondary photos
                let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(
                    images, itemId: itemId)

                await MainActor.run {
                    item.assetId = itemId
                    item.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
                }
            }

            await saveItemToSQLite()
            TelemetryManager.shared.trackInventoryItemAdded(name: item.title)

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
                if item.imageURL?.absoluteString == urlString {
                    // Deleting primary image
                    item.imageURL = nil

                    // If there are secondary photos, promote the first one to primary
                    if !item.secondaryPhotoURLs.isEmpty {
                        if let firstSecondaryURLString = item.secondaryPhotoURLs.first,
                            let firstSecondaryURL = URL(string: firstSecondaryURLString)
                        {
                            item.imageURL = firstSecondaryURL
                            item.secondaryPhotoURLs.removeFirst()
                        }
                    }
                } else {
                    // Deleting secondary image
                    item.secondaryPhotoURLs.removeAll { $0 == urlString }
                }

                // Save and reload images after deletion
                Task {
                    await saveItemToSQLite()
                    await loadAllImages()
                }
            }
        } catch {
            print("Error deleting photo: \(error)")
        }
    }

    private func loadAllImages() async {
        isLoading = true
        loadingError = nil
        defer { isLoading = false }

        var images: [UIImage] = []
        var encounteredError: Error?

        // Load primary image
        if let imageURL = item.imageURL {
            do {
                let image = try await OptimizedImageManager.shared.loadImage(url: imageURL)
                images.append(image)
            } catch {
                print("Failed to load primary image: \(error)")
                encounteredError = error
            }
        }

        // Load secondary images
        if !item.secondaryPhotoURLs.isEmpty {
            do {
                let secondaryImages = try await OptimizedImageManager.shared.loadSecondaryImages(
                    from: item.secondaryPhotoURLs)
                images.append(contentsOf: secondaryImages)
                encounteredError = nil
            } catch {
                print("Failed to load secondary images: \(error)")
                if images.isEmpty { encounteredError = error }
            }
        }

        loadedImages = images
        loadingError = images.isEmpty ? encounteredError : nil
        if selectedImageIndex >= images.count {
            selectedImageIndex = max(0, images.count - 1)
        }
    }

    private func calculateRemainingPhotoCount() -> Int {
        let currentPhotoCount =
            (item.imageURL != nil ? 1 : 0)
            + item.secondaryPhotoURLs.count
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
                let image = UIImage(data: data)
            {
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
        Task {
            do {
                if let imageURL = item.imageURL {
                    try await OptimizedImageManager.shared.deleteSecondaryImage(
                        urlString: imageURL.absoluteString)
                }
                for photoURL in item.secondaryPhotoURLs {
                    try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: photoURL)
                }
            } catch {
                print("Error deleting images during cancellation: \(error)")
            }

            // Delete from SQLite
            let id = item.id
            try? await database.write { db in
                try SQLiteInventoryItemLabel.where { $0.inventoryItemID == id }.delete().execute(db)
                try SQLiteInventoryItem.find(id).delete().execute(db)
            }

            onCancel?()
        }
    }

    private func deleteItem() async {
        do {
            // Delete all associated images
            if let imageURL = item.imageURL {
                try await OptimizedImageManager.shared.deleteSecondaryImage(
                    urlString: imageURL.absoluteString)
            }
            for photoURL in item.secondaryPhotoURLs {
                try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: photoURL)
            }
            // Delete all attachments
            for attachment in item.attachments {
                try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: attachment.url)
            }
        } catch {
            print("Error deleting images during item deletion: \(error)")
        }

        // Delete from SQLite
        let id = item.id
        try? await database.write { db in
            try SQLiteInventoryItemLabel.where { $0.inventoryItemID == id }.delete().execute(db)
            try SQLiteInventoryItem.find(id).delete().execute(db)
        }

        dismiss()
    }

    // MARK: - SQLite Data Operations

    private func loadItemFromSQLite() async {
        let id = itemID

        // Load the item
        if let loadedItem = try? await database.read({ db in
            try SQLiteInventoryItem.find(id).fetchOne(db)
        }) {
            item = loadedItem
            displayPriceString = formatInitialPrice(loadedItem.price)
        }

        // Load related location
        if let locationID = item.locationID {
            sqliteSelectedLocation = try? await database.read { db in
                try SQLiteInventoryLocation.find(locationID).fetchOne(db)
            }
        }

        // Load related home
        if let homeID = item.homeID {
            sqliteSelectedHome = try? await database.read { db in
                try SQLiteHome.find(homeID).fetchOne(db)
            }
        }

        // Load labels via join table
        let joinRows =
            (try? await database.read { db in
                try SQLiteInventoryItemLabel
                    .where { $0.inventoryItemID == id }
                    .fetchAll(db)
            }) ?? []

        if !joinRows.isEmpty {
            let labelIDs = joinRows.map(\.inventoryLabelID)
            sqliteSelectedLabels =
                (try? await database.read { db in
                    try labelIDs.compactMap { labelID in
                        try SQLiteInventoryLabel.find(labelID).fetchOne(db)
                    }
                }) ?? []
        }

        // Load AI analysis count for paywall logic
        aiAnalysisCount =
            (try? await database.read { db in
                try SQLiteInventoryItem
                    .where { $0.hasUsedAI == true }
                    .fetchAll(db).count
            }) ?? 0

        // Load images
        await loadAllImages()
    }

    private func saveItemToSQLite() async {
        let currentItem = item
        let currentLabels = sqliteSelectedLabels
        let id = currentItem.id

        do {
            try await database.write { db in
                // Check if item already exists
                let exists = try SQLiteInventoryItem.find(id).fetchOne(db) != nil

                if exists {
                    try SQLiteInventoryItem.find(id).update {
                        $0.title = currentItem.title
                        $0.quantityString = currentItem.quantityString
                        $0.quantityInt = currentItem.quantityInt
                        $0.desc = currentItem.desc
                        $0.serial = currentItem.serial
                        $0.model = currentItem.model
                        $0.make = currentItem.make
                        $0.price = currentItem.price
                        $0.insured = currentItem.insured
                        $0.assetId = currentItem.assetId
                        $0.notes = currentItem.notes
                        $0.replacementCost = currentItem.replacementCost
                        $0.depreciationRate = currentItem.depreciationRate
                        $0.imageURL = currentItem.imageURL
                        $0.secondaryPhotoURLs = currentItem.secondaryPhotoURLs
                        $0.hasUsedAI = currentItem.hasUsedAI
                        $0.purchaseDate = currentItem.purchaseDate
                        $0.warrantyExpirationDate = currentItem.warrantyExpirationDate
                        $0.purchaseLocation = currentItem.purchaseLocation
                        $0.condition = currentItem.condition
                        $0.hasWarranty = currentItem.hasWarranty
                        $0.attachments = currentItem.attachments
                        $0.dimensionLength = currentItem.dimensionLength
                        $0.dimensionWidth = currentItem.dimensionWidth
                        $0.dimensionHeight = currentItem.dimensionHeight
                        $0.dimensionUnit = currentItem.dimensionUnit
                        $0.weightValue = currentItem.weightValue
                        $0.weightUnit = currentItem.weightUnit
                        $0.color = currentItem.color
                        $0.storageRequirements = currentItem.storageRequirements
                        $0.isFragile = currentItem.isFragile
                        $0.movingPriority = currentItem.movingPriority
                        $0.roomDestination = currentItem.roomDestination
                        $0.locationID = currentItem.locationID
                        $0.homeID = currentItem.homeID
                    }.execute(db)
                } else {
                    try SQLiteInventoryItem.insert {
                        currentItem
                    }.execute(db)
                }

                // Update label join table: delete all, re-insert current
                try SQLiteInventoryItemLabel
                    .where { $0.inventoryItemID == id }
                    .delete()
                    .execute(db)

                for label in currentLabels {
                    try SQLiteInventoryItemLabel.insert {
                        SQLiteInventoryItemLabel(
                            id: UUID(),
                            inventoryItemID: id,
                            inventoryLabelID: label.id
                        )
                    }.execute(db)
                }
            }
        } catch {
            print("Failed to save item to SQLite: \(error)")
        }
    }

    private func updateItemFromImageDetails(
        _ imageDetails: ImageDetails,
        labels: [SQLiteInventoryLabel],
        locations: [SQLiteInventoryLocation]
    ) {
        // Core properties (always update)
        item.title = imageDetails.title
        item.quantityString = imageDetails.quantity
        if let quantity = Int(imageDetails.quantity) {
            item.quantityInt = quantity
        }
        item.desc = imageDetails.description
        item.make = imageDetails.make
        item.model = imageDetails.model
        item.serial = imageDetails.serialNumber

        // Price handling
        let priceString = imageDetails.price
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespaces)
        if let price = Decimal(string: priceString) {
            item.price = price
        }

        // Location handling - NEVER overwrite existing location
        if item.locationID == nil {
            if let matchedLocation = locations.first(where: { $0.name == imageDetails.location }) {
                item.locationID = matchedLocation.id
                sqliteSelectedLocation = matchedLocation
            }
        }

        // Label handling - match categories to labels (case-insensitive)
        let categoriesToMatch =
            imageDetails.categories.isEmpty
            ? [imageDetails.category]
            : imageDetails.categories
        let matchedLabels = categoriesToMatch.compactMap { categoryName in
            labels.first { $0.name.lowercased() == categoryName.lowercased() }
        }
        sqliteSelectedLabels = Array(matchedLabels.prefix(5))

        // Extended properties - only update if provided by AI
        if let condition = imageDetails.condition, !condition.isEmpty {
            item.condition = condition
        }
        if let color = imageDetails.color, !color.isEmpty {
            item.color = color
        }
        if let purchaseLocation = imageDetails.purchaseLocation, !purchaseLocation.isEmpty {
            item.purchaseLocation = purchaseLocation
        }
        if let replacementCostString = imageDetails.replacementCost, !replacementCostString.isEmpty {
            let cleanedString =
                replacementCostString
                .replacingOccurrences(of: "$", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let replacementCost = Decimal(string: cleanedString) {
                item.replacementCost = replacementCost
            }
        }
        if let depreciationRateString = imageDetails.depreciationRate, !depreciationRateString.isEmpty {
            let cleanedString =
                depreciationRateString
                .replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let depreciationRate = Double(cleanedString) {
                item.depreciationRate = depreciationRate / 100.0
            }
        }
        if let storageRequirements = imageDetails.storageRequirements, !storageRequirements.isEmpty {
            item.storageRequirements = storageRequirements
        }
        if let isFragileString = imageDetails.isFragile, !isFragileString.isEmpty {
            item.isFragile = isFragileString.lowercased() == "true"
        }

        // Dimensions handling
        if let dimensions = imageDetails.dimensions, !dimensions.isEmpty {
            parseDimensionsForItem(dimensions)
        } else {
            if let dimensionLength = imageDetails.dimensionLength, !dimensionLength.isEmpty {
                item.dimensionLength = dimensionLength
            }
            if let dimensionWidth = imageDetails.dimensionWidth, !dimensionWidth.isEmpty {
                item.dimensionWidth = dimensionWidth
            }
            if let dimensionHeight = imageDetails.dimensionHeight, !dimensionHeight.isEmpty {
                item.dimensionHeight = dimensionHeight
            }
            if let dimensionUnit = imageDetails.dimensionUnit, !dimensionUnit.isEmpty {
                item.dimensionUnit = dimensionUnit
            }
        }

        // Weight handling
        if let weightValue = imageDetails.weightValue, !weightValue.isEmpty {
            item.weightValue = weightValue
            if let weightUnit = imageDetails.weightUnit, !weightUnit.isEmpty {
                item.weightUnit = weightUnit
            } else {
                item.weightUnit = "lbs"
            }
        }

        item.hasUsedAI = true
    }

    private func parseDimensionsForItem(_ dimensionsString: String) {
        let cleanedString = dimensionsString.replacingOccurrences(of: "\"", with: " inches")
        let components = cleanedString.components(separatedBy: " x ").compactMap {
            $0.trimmingCharacters(in: .whitespaces)
        }

        if components.count >= 3 {
            item.dimensionLength = components[0]
                .replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            item.dimensionWidth = components[1]
                .replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            item.dimensionHeight = components[2]
                .replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)

            if dimensionsString.contains("\"") || dimensionsString.lowercased().contains("inch") {
                item.dimensionUnit = "inches"
            } else if dimensionsString.lowercased().contains("cm") {
                item.dimensionUnit = "cm"
            } else if dimensionsString.lowercased().contains("feet")
                || dimensionsString.lowercased().contains("ft")
            {
                item.dimensionUnit = "feet"
            } else if dimensionsString.lowercased().contains("m")
                && !dimensionsString.lowercased().contains("cm")
            {
                item.dimensionUnit = "m"
            } else {
                item.dimensionUnit = "inches"
            }
        }
    }

    private func regenerateMissingThumbnails() async {
        // Check and regenerate primary image thumbnail
        if let imageURL = item.imageURL {
            do {
                try await OptimizedImageManager.shared.regenerateThumbnail(for: imageURL)
            } catch {
                print("📸 Failed to regenerate thumbnail for primary image: \(error)")
            }
        }

        // Check and regenerate secondary image thumbnails
        for urlString in item.secondaryPhotoURLs {
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

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan
        ) {
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

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController, didFailWithError error: Error
        ) {
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
                    let page = document.page(at: 0)
                else {
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
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    let previewID = UUID()
    NavigationStack {
        InventoryDetailView(
            itemID: previewID,
            navigationPath: .constant(NavigationPath()),
            isEditing: true
        )
    }
    .environmentObject(Router())
    .environmentObject(SettingsManager())
    .environmentObject(OnboardingManager())
}

// MARK: - Attachment Handling Methods

extension InventoryDetailView {
    private func deleteAttachment(_ urlString: String) async {
        guard URL(string: urlString) != nil else { return }

        do {
            try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: urlString)
            item.attachments.removeAll { $0.url == urlString }
            await saveItemToSQLite()
        } catch {
            print("Error deleting attachment: \(error)")
        }
    }

    private func handleAttachmentFileImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let startedAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if startedAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let attachmentId = UUID().uuidString
                let data = try Data(contentsOf: url)
                let originalName = url.lastPathComponent

                let destinationURL: URL
                if let image = UIImage(data: data) {
                    destinationURL = try await OptimizedImageManager.shared.saveImage(image, id: attachmentId)
                } else {
                    guard
                        let documentsURL = FileManager.default.urls(
                            for: .documentDirectory, in: .userDomainMask
                        ).first
                    else {
                        throw NSError(
                            domain: "InventoryDetailView", code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Cannot access documents directory"])
                    }
                    destinationURL = documentsURL.appendingPathComponent(
                        attachmentId + "." + url.pathExtension)
                    try data.write(to: destinationURL)
                }

                let attachment = AttachmentInfo(url: destinationURL.absoluteString, originalName: originalName)
                item.attachments.append(attachment)
                await saveItemToSQLite()
                print("✅ Successfully saved attachment: \(originalName)")
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

    init(from item: SQLiteInventoryItem) {
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

    func restore(to item: inout SQLiteInventoryItem) {
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
    func applyNavigationSettings(title: String, isEditing: Bool, colorScheme: ColorScheme)
        -> some View
    {
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
            originalFileName != url.lastPathComponent
        else {
            // No original filename or it's the same, just return the original URL
            return url
        }

        // Create a temporary directory for sharing
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MovingBoxShare", isDirectory: true)

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

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int)
            -> QLPreviewItem
        {
            return url as QLPreviewItem
        }
    }
}
