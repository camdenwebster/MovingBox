//
//  EnhancedItemCreationFlowView.swift
//  MovingBox
//
//  Created by Claude Code on 9/19/25.
//

import AVFoundation
import Dependencies
import MovingBoxAIAnalysis
import SQLiteData
import SwiftUI

struct EnhancedItemCreationFlowView: View {
    @Dependency(\.defaultDatabase) var database
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnboarding) private var isOnboarding
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager

    @StateObject private var viewModel: ItemCreationFlowViewModel
    @State private var showingPermissionDenied = false
    @State private var hasBootstrappedInitialVideo = false

    // Animation properties
    private let transitionAnimation = Animation.easeInOut(duration: 0.3)

    let captureMode: CaptureMode
    let locationID: UUID?
    let initialVideoURL: URL?
    let initialVideoAsset: AVAsset?
    let onComplete: (() -> Void)?

    // MARK: - Initialization

    init(
        captureMode: CaptureMode,
        location: SQLiteInventoryLocation?,
        initialVideoURL: URL? = nil,
        initialVideoAsset: AVAsset? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        self.captureMode = captureMode
        self.locationID = location?.id
        self.initialVideoURL = initialVideoURL
        self.initialVideoAsset = initialVideoAsset
        self.onComplete = onComplete

        self._viewModel = StateObject(
            wrappedValue: ItemCreationFlowViewModel(
                captureMode: captureMode,
                locationID: location?.id
            ))
    }

    init(
        captureMode: CaptureMode,
        locationID: UUID?,
        initialVideoURL: URL? = nil,
        initialVideoAsset: AVAsset? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        self.captureMode = captureMode
        self.locationID = locationID
        self.initialVideoURL = initialVideoURL
        self.initialVideoAsset = initialVideoAsset
        self.onComplete = onComplete

        self._viewModel = StateObject(
            wrappedValue: ItemCreationFlowViewModel(
                captureMode: captureMode,
                locationID: locationID
            ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main content based on current step
                mainContentView

                // Progress indicator at bottom (except on camera view)
                if viewModel.currentStep != .camera, viewModel.captureMode != .video {
                    bottomProgressIndicator
                }
            }
            .navigationTitle(viewModel.currentStepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(
                viewModel.currentStep == .camera
                    || (viewModel.currentStep == .multiItemSelection && viewModel.captureMode != .video)
            )
            .interactiveDismissDisabled(viewModel.processingImage)
            .alert("Camera Access Required", isPresented: $showingPermissionDenied) {
                Button("Go to Settings", action: openSettings)
                Button("Cancel", role: .cancel) { dismiss() }
            } message: {
                Text("Please grant camera access in Settings to use this feature.")
            }
            .alert("Analysis Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("Continue Anyway", role: .none) {
                    handleErrorContinue()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.errorMessage = nil
                    dismiss()
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred during image analysis.")
            }
        }
        .onAppear {
            viewModel.updateSettingsManager(settings)

            // Verify Pro status for multi-item/video mode
            if (captureMode == .multiItem || captureMode == .video) && !settings.isPro {
                dismiss()
            }

            if !hasBootstrappedInitialVideo, let initialVideoURL {
                hasBootstrappedInitialVideo = true
                viewModel.handleSavedVideo(initialVideoURL, preparedAsset: initialVideoAsset)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            viewModel.updateScenePhase(phase)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .multiItemAnalysisReadyNotificationTapped)
        ) { _ in
            viewModel.handleAnalysisNotificationTapped()
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var mainContentView: some View {
        switch viewModel.currentStep {
        case .camera:
            if initialVideoURL != nil {
                videoBootstrapView
            } else {
                cameraView
            }

        case .videoProcessing:
            videoProcessingView

        case .analyzing:
            analysisView

        case .multiItemSelection:
            multiItemSelectionView

        case .details:
            detailsView
        }
    }

    private var cameraView: some View {
        MultiPhotoCameraView(
            capturedImages: $viewModel.capturedImages,
            captureMode: captureMode,
            onPermissionCheck: { granted in
                if !granted {
                    showingPermissionDenied = true
                }
            },
            onComplete: { images, selectedMode in
                Task {
                    // Update the viewModel's capture mode based on user selection
                    viewModel.updateCaptureMode(selectedMode)

                    // Track capture mode selection
                    TelemetryManager.shared.trackCaptureModeSelected(
                        mode: selectedMode == .singleItem ? "single_item" : "multi_item",
                        imageCount: images.count,
                        isProUser: settings.isPro
                    )

                    await viewModel.handleCapturedImages(images)
                    await MainActor.run {
                        viewModel.goToNextStep()
                    }
                }
            },
            onVideoSelected: { url in
                Task {
                    viewModel.updateCaptureMode(.video)
                    TelemetryManager.shared.trackCaptureModeSelected(
                        mode: "video",
                        imageCount: 0,
                        isProUser: settings.isPro
                    )
                    await viewModel.handleSelectedVideo(url)
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
        .id("camera-\(viewModel.transitionId)")
    }

    private var videoBootstrapView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Preparing video...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var analysisView: some View {
        ZStack {
            ImageAnalysisView(images: viewModel.capturedImages) {
                // Analysis view completed minimum display time
                // Will check if analysis is ready and transition if so
                checkAndTransitionIfReady()
            }
            .accessibilityIdentifier("imageAnalysisView")
        }
        .task {
            // Perform analysis based on capture mode (use viewModel's mode, not initial mode)
            if viewModel.captureMode == .video {
                return
            } else if viewModel.captureMode == .multiItem {
                await viewModel.performMultiItemAnalysis()
            } else {
                await viewModel.performAnalysis()
            }
        }
        .onChange(of: viewModel.analysisComplete) { _, isComplete in
            // When analysis completes, check if we should transition
            if isComplete {
                // For single-item mode, skip multi-item selection and go straight to details
                if viewModel.captureMode == .singleItem {
                    withAnimation(transitionAnimation) {
                        viewModel.goToStep(.details)
                    }
                } else {
                    checkAndTransitionIfReady()
                }
            }
        }
        .onChange(of: viewModel.errorMessage) { _, error in
            // When error occurs, allow progression
            if error != nil {
                withAnimation(transitionAnimation) {
                    viewModel.goToNextStep()
                }
            }
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        )
        .id("analysis-\(viewModel.transitionId)")
    }

    private var videoProcessingView: some View {
        VideoProcessingView(
            thumbnail: viewModel.capturedImages.first,
            progress: viewModel.videoProcessingProgress,
            onComplete: {
                if viewModel.currentStep == .videoProcessing {
                    viewModel.goToStep(.multiItemSelection)
                }
            }
        )
        .task {
            if !viewModel.processingImage && viewModel.multiItemAnalysisResponse == nil {
                await viewModel.performVideoProcessing()
            }
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        )
        .id("videoProcessing-\(viewModel.transitionId)")
    }

    @ViewBuilder
    private var multiItemSelectionView: some View {
        if viewModel.captureMode == .video {
            VideoItemSelectionListView(
                analysisResponse: viewModel.multiItemAnalysisResponse ?? streamingPlaceholderResponse,
                images: viewModel.capturedImages,
                location: resolvedLocation,
                database: database,
                aiAnalysisService: viewModel.selectionAIAnalysisService,
                isStreamingResults: viewModel.isVideoAnalysisStreaming,
                streamingStatusText: viewModel.videoStreamingStatusText,
                onItemsSelected: { items in
                    viewModel.handleMultiItemSelection(items)
                },
                onCancel: {
                    dismiss()
                },
                onReanalyze: {
                    viewModel.resetAnalysisState()
                    viewModel.goToStep(.multiItemSelection)
                }
            )
            .task {
                if !viewModel.processingImage, viewModel.multiItemAnalysisResponse == nil {
                    await viewModel.performVideoProcessing()
                }
            }
            .transition(
                .asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                )
            )
            .id("multiItemSelection-\(viewModel.transitionId)")
        } else if let analysisResponse = viewModel.multiItemAnalysisResponse {
            MultiItemSelectionView(
                analysisResponse: analysisResponse,
                images: viewModel.capturedImages,
                locationID: locationID,
                onItemsSelected: { items in
                    viewModel.handleMultiItemSelection(items)
                },
                onCancel: {
                    dismiss()
                },
                onReanalyze: {
                    // Go back to analyzing step to re-analyze the images
                    viewModel.resetAnalysisState()
                    viewModel.goToStep(.analyzing)
                }
            )
            .transition(
                .asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                )
            )
            .id("multiItemSelection-\(viewModel.transitionId)")
        } else {
            // Fallback if no analysis response
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 64))
                    .foregroundColor(.orange)

                Text("No Items Found")
                    .font(.headline)

                Text("We couldn't detect any items in your photo. Please try taking another photo.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Button("Try Again") {
                    viewModel.goToStep(.camera)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private var streamingPlaceholderResponse: MultiItemAnalysisResponse {
        MultiItemAnalysisResponse(
            items: [],
            detectedCount: 0,
            analysisType: "video_streaming_placeholder",
            confidence: 0.0
        )
    }

    @ViewBuilder
    private var detailsView: some View {
        if viewModel.createdItems.count > 1 {
            // Multi-item summary - check this FIRST before single item
            MultiItemSummaryView(
                items: viewModel.createdItems,
                onComplete: {
                    onComplete?()
                    dismiss()
                },
                onEditItem: { item in
                    // Navigate to individual item edit - TODO: Implement proper navigation
                    // router.navigate(to: .inventoryDetail(item))
                }
            )
            .accessibilityIdentifier("multiItemSummaryView")
            .transition(
                .asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .opacity
                )
            )
            .id("summary-\(viewModel.transitionId)")
        } else if let item = viewModel.createdItems.first {
            // Single item details
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
            .id("details-\(viewModel.transitionId)")
        } else {
            // Fallback
            Text("Loading item details...")
                .onAppear {
                    // If no items, go back to camera
                    if viewModel.createdItems.isEmpty {
                        viewModel.goToStep(.camera)
                    }
                }
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: 4) {
            ForEach(Array(viewModel.navigationFlow.enumerated()), id: \.element) { index, step in
                Circle()
                    .fill(
                        index <= viewModel.navigationFlow.firstIndex(of: viewModel.currentStep) ?? 0
                            ? Color.blue : Color.secondary.opacity(0.3)
                    )
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var bottomProgressIndicator: some View {
        VStack(spacing: 8) {
            Divider()

            HStack {
                // Step name
                Text(viewModel.currentStepTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Progress dots
                HStack(spacing: 6) {
                    ForEach(Array(viewModel.navigationFlow.enumerated()), id: \.element) { index, step in
                        Circle()
                            .fill(
                                index <= viewModel.navigationFlow.firstIndex(of: viewModel.currentStep) ?? 0
                                    ? Color.blue : Color.secondary.opacity(0.3)
                            )
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                // Step number
                Text("\(viewModel.currentStepIndex + 1) of \(viewModel.navigationFlow.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func checkAndTransitionIfReady() {
        // Only transition if we're ready for the next step
        if viewModel.isReadyForNextStep {
            withAnimation(transitionAnimation) {
                viewModel.goToNextStep()
            }
        }
    }

    private func handleErrorContinue() {
        viewModel.errorMessage = nil

        // Move to next step based on current step and mode
        if viewModel.currentStep == .analyzing || viewModel.currentStep == .videoProcessing {
            if viewModel.captureMode == .multiItem || viewModel.captureMode == .video {
                // Create empty multi-item response to allow progression
                viewModel.multiItemAnalysisResponse = MultiItemAnalysisResponse(
                    items: [],
                    detectedCount: 0,
                    analysisType: "multi_item",
                    confidence: 0.0
                )
            }
            viewModel.goToNextStep()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private var resolvedLocation: SQLiteInventoryLocation? {
        guard let locationID else { return nil }
        return try? database.read { db in
            try SQLiteInventoryLocation.find(locationID).fetchOne(db)
        }
    }
}

// MARK: - Supporting Views

struct MultiItemSummaryView: View {
    let items: [SQLiteInventoryItem]
    let onComplete: () -> Void
    let onEditItem: (SQLiteInventoryItem) -> Void

    @State private var showConfetti = false

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                        .scaleEffect(showConfetti ? 1.0 : 0.5)
                        .opacity(showConfetti ? 1.0 : 0.0)

                    Text("Successfully Added!")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("\(items.count) item\(items.count == 1 ? "" : "s") added to your inventory")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                // Items list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            ItemSummaryCard(item: item) {
                                onEditItem(item)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Items Added")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onComplete()
                    }
                    .backport.glassProminentButtonStyle()
                }
            }
            .onAppear {
                // Trigger confetti animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showConfetti = true
                }
            }

            // Confetti overlay
            if showConfetti {
                SummaryConfettiView()
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Confetti Animation

private struct SummaryConfettiView: View {
    @State private var confettiPieces: [SummaryConfettiPiece] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: 8, height: 8)
                        .position(x: piece.x, y: piece.y)
                }
            }
            .onAppear {
                generateConfetti(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private func generateConfetti(width: CGFloat, height: CGFloat) {
        let colors: [Color] = [.blue, .green, .yellow, .orange, .red, .purple]

        for _ in 0..<50 {
            let piece = SummaryConfettiPiece(
                id: UUID(),
                x: CGFloat.random(in: 0...width),
                y: CGFloat.random(in: -100...height / 3),
                color: colors.randomElement() ?? .blue
            )
            confettiPieces.append(piece)
        }

        // Animate confetti falling
        withAnimation(.linear(duration: 3.0)) {
            for i in 0..<confettiPieces.count {
                confettiPieces[i].y += height + 100
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            confettiPieces.removeAll()
        }
    }
}

private struct SummaryConfettiPiece: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let color: Color
}

// MARK: - Item Summary Card

struct ItemSummaryCard: View {
    let item: SQLiteInventoryItem
    let onTap: () -> Void

    @Dependency(\.defaultDatabase) private var database
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack {
            // Image thumbnail
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title.isEmpty ? "Untitled Item" : item.title)
                    .font(.headline)
                    .lineLimit(1)

                if !item.make.isEmpty || !item.model.isEmpty {
                    Text("\(item.make) \(item.model)".trimmingCharacters(in: .whitespaces))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if item.price > 0 {
                    Text(CurrencyFormatter.format(item.price))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
        .task {
            thumbnail = try? await database.read { db in
                try SQLiteInventoryItemPhoto.primaryImage(for: item.id, in: db)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }

    EnhancedItemCreationFlowView(
        captureMode: .multiItem,
        locationID: nil,
        onComplete: nil
    )
    .environmentObject(Router())
    .environmentObject(SettingsManager())
}
