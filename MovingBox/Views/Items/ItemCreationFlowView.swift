import AVFoundation
import Dependencies
import MovingBoxAIAnalysis
import SQLiteData
import StoreKit
import SwiftUI

enum ItemCreationStep: CaseIterable {
    case camera
    case videoProcessing
    case analyzing
    case multiItemSelection
    case details

    var displayName: String {
        switch self {
        case .camera: return "Camera"
        case .videoProcessing: return "Video Processing"
        case .analyzing: return "Analyzing"
        case .multiItemSelection: return "Select Items"
        case .details: return "Details"
        }
    }

    static func getNavigationFlow(for captureMode: CaptureMode) -> [ItemCreationStep] {
        switch captureMode {
        case .singleItem:
            return [.camera, .analyzing, .details]
        case .multiItem:
            return [.camera, .analyzing, .multiItemSelection, .details]
        case .video:
            return [.camera, .videoProcessing, .multiItemSelection, .details]
        }
    }
}

struct ItemCreationFlowView: View {
    @Dependency(\.defaultDatabase) var database
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnboarding) private var isOnboarding
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager

    @State private var currentStep: ItemCreationStep = .camera
    @State private var capturedImage: UIImage?
    @State private var capturedImages: [UIImage] = []
    @State private var captureMode: CaptureMode = .singleItem
    @State private var item: SQLiteInventoryItem?
    @State private var showingPermissionDenied = false
    @State private var processingImage = false
    @State private var analysisComplete = false
    @State private var errorMessage: String?
    @State private var transitionId = UUID()

    // Animation properties
    private let transitionAnimation = Animation.easeInOut(duration: 0.3)

    let locationID: UUID?
    let onComplete: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                switch currentStep {
                case .camera:
                    MultiPhotoCameraView(
                        capturedImages: $capturedImages,
                        onPermissionCheck: { granted in
                            if !granted {
                                showingPermissionDenied = true
                            }
                        },
                        onComplete: { images, selectedMode in
                            // Set processing flag to prevent premature dismissal
                            processingImage = true

                            Task {
                                // Update capture mode based on user selection in camera
                                await updateCaptureMode(selectedMode)
                                // Process the images
                                await handleCapturedImages(images)

                                // Transition to next step
                                // For single-item mode: check if item was created
                                // For multi-item mode: always proceed to analyzing
                                if selectedMode == .multiItem || self.item != nil {
                                    await MainActor.run {
                                        withAnimation(transitionAnimation) {
                                            transitionId = UUID()
                                            currentStep = .analyzing
                                        }
                                    }
                                } else {
                                    await MainActor.run {
                                        processingImage = false
                                        dismiss()
                                    }
                                }
                            }
                        },
                        onCancel: {
                            dismiss()
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .identity,
                            removal: .move(edge: .leading)
                        )
                    )
                    .id("camera-\(transitionId)")

                case .analyzing:
                    if !capturedImages.isEmpty, let item = item {
                        ZStack {
                            ImageAnalysisView(images: capturedImages) {
                                // The ImageAnalysisView will signal when minimum display time has elapsed
                                // but we only move to details if analysis is actually complete
                                if analysisComplete {
                                    print("Analysis view completed and analysis is done")
                                    withAnimation(transitionAnimation) {
                                        transitionId = UUID()
                                        currentStep = .details
                                    }
                                } else if errorMessage != nil {
                                    print("Analysis view completed with error")
                                    withAnimation(transitionAnimation) {
                                        transitionId = UUID()
                                        currentStep = .details
                                    }
                                }
                                // Otherwise, we keep waiting for analysis to complete
                            }
                        }
                        .task {
                            // Only start analysis if we haven't completed it yet
                            if !analysisComplete && errorMessage == nil {
                                await performMultiImageAnalysis(item: item, images: capturedImages)
                            }
                        }
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            )
                        )
                        .id("analysis-\(transitionId)")
                    }

                case .videoProcessing:
                    Text("Video processing not supported in this view")
                        .onAppear {
                            currentStep = .details
                        }

                case .multiItemSelection:
                    // This view doesn't support multi-item selection, fall back to details
                    Text("Multi-item selection not supported in this view")
                        .onAppear {
                            currentStep = .details
                        }

                case .details:
                    if let item = item {
                        InventoryDetailView(
                            itemID: item.id,
                            navigationPath: .constant(NavigationPath()),
                            isEditing: true,
                            onSave: {
                                onComplete?()
                                dismiss()
                            },
                            onCancel: {
                                dismiss()
                            }
                        )
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .opacity
                            )
                        )
                        .id("details-\(transitionId)")
                    } else {
                        Text("Loading item details...")
                            .onAppear {
                                // Fallback in case the item isn't ready
                                if item == nil {
                                    dismiss()
                                }
                            }
                    }
                }
            }
            .animation(transitionAnimation, value: currentStep)
            .interactiveDismissDisabled(currentStep != .camera || processingImage)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: analysisComplete) { _, newValue in
            if newValue && currentStep == .analyzing {
                print("Analysis complete changed to true")
                // Transition after a slight delay for smoother UX
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(transitionAnimation) {
                        transitionId = UUID()
                        currentStep = .details
                    }
                }
            }
        }
        .onChange(of: errorMessage) { _, newValue in
            if newValue != nil && currentStep == .analyzing {
                print("Error message set, moving to details")
                // Transition after a slight delay for smoother UX
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(transitionAnimation) {
                        transitionId = UUID()
                        currentStep = .details
                    }
                }
            }
        }
        .alert("Camera Access Required", isPresented: $showingPermissionDenied) {
            Button("Go to Settings", action: openSettings)
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("Please grant camera access in Settings to use this feature.")
        }
        .alert(
            errorMessage ?? "Error",
            isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("Continue Anyway", role: .none) {
                withAnimation(transitionAnimation) {
                    currentStep = .details
                }
            }
        } message: {
            Text(errorMessage ?? "An unknown error occurred during image analysis.")
        }
    }

    private func updateCaptureMode(_ mode: CaptureMode) async {
        await MainActor.run {
            print("🔄 ItemCreationFlowView - Updating capture mode from \(captureMode) to \(mode)")
            captureMode = mode
            print("✅ ItemCreationFlowView - Capture mode updated. Current mode: \(captureMode)")
        }
    }

    private func handleCapturedImages(_ images: [UIImage]) async {
        await MainActor.run {
            capturedImages = images
            capturedImage = images.first
        }

        // Only run single-item creation if in single-item mode
        guard captureMode == .singleItem else { return }

        let newID = UUID()
        let itemId = newID.uuidString
        let resolvedHomeID = await resolveHomeID()

        var newItem = SQLiteInventoryItem(
            id: newID,
            title: "",
            desc: "",
            model: "",
            make: "",
            price: Decimal.zero,
            assetId: itemId,
            notes: "",
            hasUsedAI: true,
            locationID: locationID,
            homeID: resolvedHomeID
        )

        do {
            // Process images to JPEG data before DB write
            var photoDataList: [(Data, Int)] = []
            for (sortOrder, image) in images.enumerated() {
                if let imageData = await OptimizedImageManager.shared.processImage(image) {
                    photoDataList.append((imageData, sortOrder))
                }
            }

            let itemToInsert = newItem
            try await database.write { db in
                try SQLiteInventoryItem.insert { itemToInsert }.execute(db)

                for (imageData, sortOrder) in photoDataList {
                    try SQLiteInventoryItemPhoto.insert {
                        SQLiteInventoryItemPhoto(
                            id: UUID(),
                            inventoryItemID: newItem.id,
                            data: imageData,
                            sortOrder: sortOrder
                        )
                    }.execute(db)
                }
            }
            TelemetryManager.shared.trackInventoryItemAdded(name: newItem.title)
            self.item = newItem
        } catch {
            print("Error processing images: \(error)")
        }
    }

    private func performImageAnalysis(item: SQLiteInventoryItem, image: UIImage) async {
        await MainActor.run {
            analysisComplete = false
            errorMessage = nil
        }

        do {
            guard await OptimizedImageManager.shared.prepareImageForAI(from: image) != nil else {
                throw AIAnalysisError.invalidData
            }

            let aiService = AIAnalysisServiceFactory.create()
            TelemetryManager.shared.trackCameraAnalysisUsed()

            // Build AIAnalysisContext from database
            let context = await AIAnalysisContext.from(database: database, settings: settings)

            let imageDetails = try await aiService.getImageDetails(
                from: [capturedImage].compactMap { $0 },
                settings: settings,
                context: context
            )

            // Fetch labels and locations from SQLite
            let labels =
                (try? await database.read { db in
                    try SQLiteInventoryLabel.all.fetchAll(db)
                }) ?? []
            let locations =
                (try? await database.read { db in
                    try SQLiteInventoryLocation.all.fetchAll(db)
                }) ?? []

            await MainActor.run {
                updateItemFromImageDetails(imageDetails, labels: labels, locations: locations)
                processingImage = false
                analysisComplete = true
            }

            // Save updated item to SQLite
            if let currentItem = self.item {
                let itemToSave = currentItem
                do {
                    try await database.write { db in
                        try SQLiteInventoryItem.find(itemToSave.id).update {
                            $0.title = itemToSave.title
                            $0.desc = itemToSave.desc
                            $0.model = itemToSave.model
                            $0.make = itemToSave.make
                            $0.price = itemToSave.price
                            $0.serial = itemToSave.serial
                            $0.notes = itemToSave.notes
                            $0.dimensionLength = itemToSave.dimensionLength
                            $0.dimensionWidth = itemToSave.dimensionWidth
                            $0.dimensionHeight = itemToSave.dimensionHeight
                            $0.dimensionUnit = itemToSave.dimensionUnit
                            $0.weightValue = itemToSave.weightValue
                            $0.weightUnit = itemToSave.weightUnit
                            $0.condition = itemToSave.condition
                            $0.hasUsedAI = itemToSave.hasUsedAI
                        }.execute(db)
                    }
                } catch {
                    print("Error saving analysis results: \(error)")
                }
            }
        } catch let aiError as AIAnalysisError {
            await MainActor.run {
                errorMessage = aiError.userFriendlyMessage
                processingImage = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                processingImage = false
            }
        }
    }

    private func performMultiImageAnalysis(item: SQLiteInventoryItem, images: [UIImage]) async {
        await MainActor.run {
            analysisComplete = false
            errorMessage = nil
        }

        do {
            let imageBase64Array = await OptimizedImageManager.shared.prepareMultipleImagesForAI(
                from: images)

            guard !imageBase64Array.isEmpty else {
                throw AIAnalysisError.invalidData
            }

            let aiService = AIAnalysisServiceFactory.create()
            TelemetryManager.shared.trackCameraAnalysisUsed()

            // Build AIAnalysisContext from database
            let context = await AIAnalysisContext.from(database: database, settings: settings)

            let imageDetails = try await aiService.getImageDetails(
                from: capturedImages,
                settings: settings,
                context: context
            )

            // Fetch labels and locations from SQLite
            let labels =
                (try? await database.read { db in
                    try SQLiteInventoryLabel.all.fetchAll(db)
                }) ?? []
            let locations =
                (try? await database.read { db in
                    try SQLiteInventoryLocation.all.fetchAll(db)
                }) ?? []

            await MainActor.run {
                updateItemFromImageDetails(imageDetails, labels: labels, locations: locations)

                settings.incrementSuccessfulAIAnalysis()
                if settings.shouldRequestReview() {
                    requestAppReview()
                }

                processingImage = false
                analysisComplete = true
            }

            // Save updated item to SQLite
            if let currentItem = self.item {
                let itemToSave = currentItem
                do {
                    try await database.write { db in
                        try SQLiteInventoryItem.find(itemToSave.id).update {
                            $0.title = itemToSave.title
                            $0.desc = itemToSave.desc
                            $0.model = itemToSave.model
                            $0.make = itemToSave.make
                            $0.price = itemToSave.price
                            $0.serial = itemToSave.serial
                            $0.notes = itemToSave.notes
                            $0.dimensionLength = itemToSave.dimensionLength
                            $0.dimensionWidth = itemToSave.dimensionWidth
                            $0.dimensionHeight = itemToSave.dimensionHeight
                            $0.dimensionUnit = itemToSave.dimensionUnit
                            $0.weightValue = itemToSave.weightValue
                            $0.weightUnit = itemToSave.weightUnit
                            $0.condition = itemToSave.condition
                            $0.hasUsedAI = itemToSave.hasUsedAI
                        }.execute(db)
                    }
                } catch {
                    print("Error saving analysis results: \(error)")
                }
            }
        } catch let aiError as AIAnalysisError {
            await MainActor.run {
                errorMessage = aiError.userFriendlyMessage
                processingImage = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                processingImage = false
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func requestAppReview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            TelemetryManager.shared.trackAppReviewRequested()
            if #available(iOS 18.0, *) {
                if let scene = UIApplication.shared.connectedScenes.first(where: {
                    $0.activationState == .foregroundActive
                }) as? UIWindowScene {
                    AppStore.requestReview(in: scene)
                }
            } else {
                if let scene = UIApplication.shared.connectedScenes.first(where: {
                    $0.activationState == .foregroundActive
                }) as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                }
            }
        }
    }

    private func resolveHomeID() async -> UUID? {
        if let locationID {
            if let location = try? await database.read({ db in
                try SQLiteInventoryLocation.find(locationID).fetchOne(db)
            }), let locationHomeID = location.homeID {
                return locationHomeID
            }
        }

        if let activeHomeIdString = settings.activeHomeId,
            let activeHomeId = UUID(uuidString: activeHomeIdString)
        {
            if (try? await database.read({ db in
                try SQLiteHome.find(activeHomeId).fetchOne(db)
            })) != nil {
                return activeHomeId
            }
        }

        return try? await database.read { db in
            try SQLiteHome.where { $0.isPrimary == true }.fetchOne(db)?.id
        }
    }

    private func updateItemFromImageDetails(
        _ imageDetails: ImageDetails,
        labels: [SQLiteInventoryLabel],
        locations: [SQLiteInventoryLocation]
    ) {
        guard var currentItem = item else { return }

        if !imageDetails.title.isEmpty { currentItem.title = imageDetails.title }
        if !imageDetails.make.isEmpty { currentItem.make = imageDetails.make }
        if !imageDetails.model.isEmpty { currentItem.model = imageDetails.model }
        if !imageDetails.description.isEmpty { currentItem.desc = imageDetails.description }
        if !imageDetails.serialNumber.isEmpty { currentItem.serial = imageDetails.serialNumber }
        if let condition = imageDetails.condition, !condition.isEmpty { currentItem.condition = condition }

        let priceString = imageDetails.price
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        if let price = Decimal(string: priceString), price > 0 {
            currentItem.price = price
        }

        // Use individual dimension properties if available, fall back to parsing dimensions string
        if let length = imageDetails.dimensionLength, !length.isEmpty {
            currentItem.dimensionLength = length
        }
        if let width = imageDetails.dimensionWidth, !width.isEmpty {
            currentItem.dimensionWidth = width
        }
        if let height = imageDetails.dimensionHeight, !height.isEmpty {
            currentItem.dimensionHeight = height
        }
        if let unit = imageDetails.dimensionUnit, !unit.isEmpty {
            currentItem.dimensionUnit = unit
        }

        if let weightVal = imageDetails.weightValue, !weightVal.isEmpty {
            currentItem.weightValue = weightVal
        }
        if let weightUnitVal = imageDetails.weightUnit, !weightUnitVal.isEmpty {
            currentItem.weightUnit = weightUnitVal
        }

        currentItem.hasUsedAI = true
        item = currentItem
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }

    ItemCreationFlowView(locationID: nil, onComplete: nil)
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
