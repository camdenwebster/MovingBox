//
//  EnhancedItemCreationFlowView.swift
//  MovingBox
//
//  Created by Claude Code on 9/19/25.
//

import SwiftUI
import SwiftData
import AVFoundation

struct EnhancedItemCreationFlowView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnboarding) private var isOnboarding
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager

    @StateObject private var viewModel: ItemCreationFlowViewModel
    @State private var showingPermissionDenied = false

    // Animation properties
    private let transitionAnimation = Animation.easeInOut(duration: 0.3)

    let captureMode: CaptureMode
    let location: InventoryLocation?
    let onComplete: (() -> Void)?

    // MARK: - Initialization

    init(
        captureMode: CaptureMode,
        location: InventoryLocation?,
        onComplete: (() -> Void)? = nil
    ) {
        self.captureMode = captureMode
        self.location = location
        self.onComplete = onComplete

        // Initialize StateObject using temporary container
        // Force new instance by using the captureMode in initialization
        let tempContainer = try! ModelContainer(for: InventoryItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        self._viewModel = StateObject(wrappedValue: ItemCreationFlowViewModel(
            captureMode: captureMode,
            location: location,
            modelContext: ModelContext(tempContainer)
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main content based on current step
                mainContentView

                // Progress indicator at bottom (except on camera view)
                if viewModel.currentStep != .camera {
                    bottomProgressIndicator
                }
            }
            .overlay {
                // Processing overlay
                if viewModel.processingImage {
                    processingOverlay
                }
            }
            .navigationTitle(viewModel.currentStepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(viewModel.currentStep == .camera)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.allowsBackNavigation {
                        backButton
                    }
                }
            }
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
                Button("Try Again", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred during image analysis.")
            }
        }
        .onAppear {
            // Update viewModel with actual modelContext and settingsManager
            viewModel.updateModelContext(modelContext)
            viewModel.updateSettingsManager(settings)

            // Verify Pro status for multi-item mode
            if captureMode == .multiItem && !settings.isPro {
                dismiss()
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var mainContentView: some View {
        switch viewModel.currentStep {
        case .camera:
            cameraView
            
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
            onComplete: { images in
                Task {
                    await viewModel.handleCapturedImages(images)
                    await MainActor.run {
                        viewModel.goToNextStep()
                    }
                }
            },
            onCancel: {
                dismiss()
            }
        )
        .transition(.asymmetric(
            insertion: .identity,
            removal: .move(edge: .leading)
        ))
        .id("camera-\(viewModel.transitionId)")
    }
    
    private var analysisView: some View {
        ZStack {
            ImageAnalysisView(images: viewModel.capturedImages) {
                // Analysis view completed minimum display time
                // Will check if analysis is ready and transition if so
                checkAndTransitionIfReady()
            }
        }
        .task {
            // Perform analysis based on capture mode
            if captureMode == .multiItem {
                await viewModel.performMultiItemAnalysis()
            } else {
                await viewModel.performAnalysis()
            }
        }
        .onChange(of: viewModel.analysisComplete) { _, isComplete in
            // When analysis completes, check if we should transition
            if isComplete {
                checkAndTransitionIfReady()
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
        .transition(.asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        ))
        .id("analysis-\(viewModel.transitionId)")
    }
    
    @ViewBuilder
    private var multiItemSelectionView: some View {
        if let analysisResponse = viewModel.multiItemAnalysisResponse {
            MultiItemSelectionView(
                analysisResponse: analysisResponse,
                images: viewModel.capturedImages,
                location: location,
                modelContext: modelContext,
                onItemsSelected: { items in
                    viewModel.handleMultiItemSelection(items)
                },
                onCancel: {
                    dismiss()
                }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))
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
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .opacity
            ))
            .id("summary-\(viewModel.transitionId)")
        } else if let item = viewModel.createdItems.first {
            // Single item details
            InventoryDetailView(
                inventoryItemToDisplay: item,
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
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .opacity
            ))
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
    
    private var backButton: some View {
        Button("Back") {
            if viewModel.canGoToPreviousStep {
                viewModel.goToPreviousStep()
            } else {
                dismiss()
            }
        }
        .disabled(viewModel.processingImage)
    }
    
    private var progressIndicator: some View {
        HStack(spacing: 4) {
            ForEach(Array(viewModel.navigationFlow.enumerated()), id: \.element) { index, step in
                Circle()
                    .fill(index <= viewModel.navigationFlow.firstIndex(of: viewModel.currentStep) ?? 0 ? Color.blue : Color.secondary.opacity(0.3))
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
                            .fill(index <= viewModel.navigationFlow.firstIndex(of: viewModel.currentStep) ?? 0 ? Color.blue : Color.secondary.opacity(0.3))
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
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text(captureMode == .multiItem ? "Analyzing multiple items..." : "Analyzing image...")
                    .font(.headline)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
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
        if viewModel.currentStep == .analyzing {
            if captureMode == .multiItem {
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
}

// MARK: - Supporting Views

struct MultiItemSummaryView: View {
    let items: [InventoryItem]
    let onComplete: () -> Void
    let onEditItem: (InventoryItem) -> Void

    @State private var showConfetti = false

    var body: some View {
        NavigationStack {
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
                y: CGFloat.random(in: -100...height/3),
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
    let item: InventoryItem
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            // Image thumbnail
            AsyncImage(url: item.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
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
    }
}

// MARK: - Preview

#Preview {
    EnhancedItemCreationFlowView(
        captureMode: .multiItem,
        location: nil,
        onComplete: nil
    )
    .modelContainer(try! ModelContainer(for: InventoryItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    .environmentObject(Router())
    .environmentObject(SettingsManager())
}