//
//  MultiItemSelectionView.swift
//  MovingBox
//
//  Created by Claude Code on 9/19/25.
//

import SwiftData
import SwiftUI
import SwiftUIBackports

struct MultiItemSelectionView: View {

    // MARK: - Properties

    @State private var viewModel: MultiItemSelectionViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager

    let images: [UIImage]
    let onItemsSelected: ([InventoryItem]) -> Void
    let onCancel: () -> Void
    let onReanalyze: (() -> Void)?

    // MARK: - State Properties

    @State private var selectedLocation: InventoryLocation?
    @State private var selectedHome: Home?
    @State private var showingLocationPicker = false
    @State private var isPreparingPreviews = true

    // MARK: - Scroll Tracking

    @State private var scrolledID: Int?

    // MARK: - Animation Properties

    private let cardTransition = Animation.easeInOut(duration: 0.3)
    private let imageTransition = Animation.easeInOut(duration: 0.25)
    private let selectionHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let cardHeight: CGFloat = 200

    // MARK: - Initialization

    init(
        analysisResponse: MultiItemAnalysisResponse,
        images: [UIImage],
        location: InventoryLocation?,
        modelContext: ModelContext,
        aiAnalysisService: AIAnalysisServiceProtocol? = nil,
        onItemsSelected: @escaping ([InventoryItem]) -> Void,
        onCancel: @escaping () -> Void,
        onReanalyze: (() -> Void)? = nil
    ) {
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: images,
            location: location,
            modelContext: modelContext,
            aiAnalysisService: aiAnalysisService
        )
        self._viewModel = State(initialValue: viewModel)
        self.images = images
        self.onItemsSelected = onItemsSelected
        self.onCancel = onCancel
        self.onReanalyze = onReanalyze
        // Use passed location as default
        self._selectedLocation = State(initialValue: location)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.hasNoItems {
                    noItemsView
                } else {
                    mainContentView
                }

            }
            .navigationTitle(
                "We found \(viewModel.detectedItems.count) item\(viewModel.detectedItems.count == 1 ? "" : "s")"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let onReanalyze = onReanalyze {
                        Button(action: onReanalyze) {
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        }
                        .accessibilityIdentifier("multiItemReanalyzeButton")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        onCancel()
                    }
                    .accessibilityIdentifier("multiItemCancelButton")
                }
            }
            .alert("Error Creating Items", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                viewModel.settingsManager = settingsManager
            }
        }
    }

    // MARK: - View Components
    private var mainContentView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            cardCarouselView
                .padding(.bottom, 20)

            selectionSummaryView
                .padding(.horizontal, 16)

            continueButton
                .backport.glassProminentButtonStyle()
                .disabled(viewModel.selectedItemsCount == 0 || viewModel.isProcessingSelection)
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
        .background(alignment: .top) {
            imageView
        }
        .task {
            await preparePreviews()
        }
        .onChange(of: images.count) {
            Task {
                await viewModel.updateImages(images)
                await preparePreviews()
            }
        }
        .onDisappear {
            viewModel.cancelEnrichment()
        }
        .onChange(of: scrolledID) {
            if let scrolledID {
                withAnimation(imageTransition) {
                    viewModel.currentCardIndex = scrolledID
                }
            }
        }
    }

    private var noItemsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Items Detected")
                    .font(.headline)

                Text(
                    "We weren't able to identify any items in this photo. You can try taking another photo or add an item manually."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Button("Try Again") {
                onCancel()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 32)
    }

    private var imageView: some View {
        ZStack(alignment: .bottom) {
            // Square aspect ratio container ensures consistent sizing
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    ZStack {
                        if isPreparingPreviews {
                            ZStack {
                                Color.gray.opacity(0.2)
                                ProgressView("Preparing preview…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let currentItem = viewModel.currentItem,
                            let primaryImage = viewModel.primaryImage(for: currentItem)
                        {
                            Image(uiImage: primaryImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .id(currentItem.id)
                                .transition(.opacity)
                        } else if viewModel.images.count == 1, let image = viewModel.images.first {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .transition(.opacity)
                        } else {
                            ZStack {
                                Color.gray.opacity(0.2)
                                ProgressView("Preparing preview…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .clipped()
                .animation(imageTransition, value: viewModel.currentCardIndex)

            // Gradient overlay for smooth transition
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.clear,
                    Color(.systemBackground).opacity(0.3),
                    Color(.systemBackground).opacity(0.6),
                    Color(.systemBackground).opacity(0.9),
                    Color(.systemBackground),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
        }
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
    }

    private var cardCarouselView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .bottom, spacing: 20) {
                ForEach(0..<viewModel.detectedItems.count, id: \.self) { index in
                    let item = viewModel.detectedItems[index]
                    DetectedItemCard(
                        item: item,
                        isSelected: viewModel.isItemSelected(item),
                        matchedLabel: viewModel.getMatchingLabel(for: item),
                        croppedImage: viewModel.croppedPrimaryImages[item.id],
                        onToggleSelection: {
                            selectionHaptic.impactOccurred()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.toggleItemSelection(item)
                            }
                        }
                    )
                    .containerRelativeFrame(.horizontal) { length, _ in
                        length * 0.85
                    }
                    .frame(height: cardHeight)
                    .accessibilityIdentifier("multiItemSelectionCard-\(index)")
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1.0 : 0.8)
                            .scaleEffect(phase.isIdentity ? 1.0 : 0.95)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .frame(height: cardHeight)
        .contentMargins(.horizontal, 20)
        .scrollPosition(id: $scrolledID)
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }

    private var navigationControlsView: some View {
        HStack(spacing: 20) {
            // Previous button
            Button(action: viewModel.goToPreviousCard) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundStyle(viewModel.canGoToPreviousCard ? .primary : .secondary)
            }
            .disabled(!viewModel.canGoToPreviousCard)

            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<viewModel.detectedItems.count, id: \.self) { index in
                    Circle()
                        .fill(
                            index == viewModel.currentCardIndex ? Color.primary : Color.secondary.opacity(0.3)
                        )
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == viewModel.currentCardIndex ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.currentCardIndex)
                }
            }

            // Next button
            Button(action: viewModel.goToNextCard) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundStyle(viewModel.canGoToNextCard ? .primary : .secondary)
            }
            .disabled(!viewModel.canGoToNextCard)
        }
        .padding(.vertical, 8)
    }

    private var selectionSummaryView: some View {
        VStack(spacing: 16) {
            // Selection count and controls
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.selectedItemsCount) of \(viewModel.detectedItems.count) selected")
                        .font(.headline)
                        .accessibilityIdentifier("multiItemSelectionCounter")

                    if viewModel.selectedItemsCount > 0 {
                        Text("Ready to add to inventory")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.filteredOutCount > 0 {
                        Text("Filtered \(viewModel.filteredOutCount) low-quality item(s)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.isEnriching {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Enhancing details...")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Select all/deselect all button
                if viewModel.selectedItemsCount == viewModel.detectedItems.count {
                    Button("Deselect All") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.deselectAllItems()
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("multiItemDeselectAllButton")
                } else {
                    Button("Select All") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectAllItems()
                        }
                    }
                    .backport.glassProminentButtonStyle()
                    .accessibilityIdentifier("multiItemSelectAllButton")
                }
            }

            // Location picker
            Divider()

            HStack {
                Label("Location", systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: { showingLocationPicker = true }) {
                    HStack(spacing: 6) {
                        VStack(alignment: .trailing, spacing: 2) {
                            if let home = selectedHome {
                                Text(home.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(selectedLocation?.name ?? "Not specified")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.primary)
                }
                .accessibilityIdentifier("multiItemLocationButton")
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingLocationPicker) {
            LocationSelectionView(
                selectedLocation: $selectedLocation,
                selectedHome: $selectedHome
            )
        }
        .onAppear {
            if selectedHome == nil {
                selectedHome = selectedLocation?.home
            }
        }
    }

    private var continueButton: some View {
        Button(action: handleContinue) {
            HStack {
                Spacer()
                if viewModel.isProcessingSelection {
                    ProgressView()
                } else {
                    Text(
                        "Add \(viewModel.selectedItemsCount) Item\(viewModel.selectedItemsCount == 1 ? "" : "s")"
                    )
                    .font(.headline)
                }
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("multiItemContinueButton")
    }

    // MARK: - Actions

    @MainActor
    private func preparePreviews() async {
        guard !viewModel.detectedItems.isEmpty else {
            isPreparingPreviews = false
            return
        }

        isPreparingPreviews = true
        let previewCount = min(3, viewModel.detectedItems.count)
        await viewModel.computeCroppedImages(limit: previewCount)
        isPreparingPreviews = false

        await viewModel.computeCroppedImages()
        viewModel.startEnrichment(settings: settingsManager)
    }

    private func handleContinue() {
        guard viewModel.selectedItemsCount > 0 else { return }

        Task {
            do {
                // Update the location in view model before creating items
                viewModel.updateSelectedLocation(selectedLocation)
                let createdItems = try await viewModel.createSelectedInventoryItems()
                onItemsSelected(createdItems)
            } catch {
                // Error is handled by the view model and shown via alert
                print("Error creating items: \(error)")
            }
        }
    }
}

// MARK: - DetectedItemCard

struct DetectedItemCard: View {
    let item: DetectedInventoryItem
    let isSelected: Bool
    let matchedLabel: InventoryLabel?
    let croppedImage: UIImage?
    let onToggleSelection: () -> Void

    var body: some View {
        Button(action: onToggleSelection) {
            VStack(alignment: .leading, spacing: 8) {

                // Title and confidence badge
                HStack {
                    Text(item.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    confidenceBadge
                }

                // Label (if matched) and make/model
                if matchedLabel != nil
                    || ((!item.make.isEmpty || item.make != "Unknown")
                        && (!item.model.isEmpty || item.model != "Unknown"))
                {
                    VStack(alignment: .leading, spacing: 8) {
                        if let label = matchedLabel {
                            HStack(spacing: 4) {
                                Label(label.name, systemImage: "tag")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !item.make.isEmpty && !item.model.isEmpty {
                            Label("\(item.make) \(item.model)", systemImage: "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Description
                if !item.description.isEmpty {
                    Label(item.description, systemImage: "list.clipboard")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                // Price
                if !item.estimatedPrice.isEmpty {
                    HStack {
                        Label("Estimated Value", systemImage: "dollarsign.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(item.estimatedPrice)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }

                Spacer(minLength: 0)

                // Selection status text
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.callout)
                        .foregroundStyle(isSelected ? .blue : .secondary)

                    Text(isSelected ? "Selected for adding" : "Tap to select")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray5), lineWidth: isSelected ? 2 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    init(
        item: DetectedInventoryItem,
        isSelected: Bool,
        matchedLabel: InventoryLabel?,
        croppedImage: UIImage? = nil,
        onToggleSelection: @escaping () -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.matchedLabel = matchedLabel
        self.croppedImage = croppedImage
        self.onToggleSelection = onToggleSelection
    }

    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain")
                .font(.caption)

            Text(item.formattedConfidence)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(confidenceColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidenceColor.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
    }

    private var confidenceColor: Color {
        if item.confidence >= 0.9 {
            return .green
        } else if item.confidence >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: InventoryItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)

    let mockResponse = MultiItemAnalysisResponse(
        items: [
            DetectedInventoryItem(
                id: "1",
                title: "MacBook Pro",
                description: "13-inch laptop with M2 chip, perfect for development work",
                category: "Electronics",
                make: "Apple",
                model: "MacBook Pro 13\"",
                estimatedPrice: "$1,299.00",
                confidence: 0.95
            ),
            DetectedInventoryItem(
                id: "2",
                title: "Wireless Mouse",
                description: "Ergonomic wireless mouse with USB receiver",
                category: "Electronics",
                make: "Logitech",
                model: "MX Master 3",
                estimatedPrice: "$99.99",
                confidence: 0.87
            ),
            DetectedInventoryItem(
                id: "3",
                title: "Coffee Mug",
                description: "Ceramic coffee mug with company logo",
                category: "Kitchen",
                make: "",
                model: "",
                estimatedPrice: "$15.00",
                confidence: 0.65
            ),
        ],
        detectedCount: 3,
        analysisType: "multi_item",
        confidence: 0.82
    )

    return MultiItemSelectionView(
        analysisResponse: mockResponse,
        images: [UIImage()],
        location: nil,
        modelContext: context,
        onItemsSelected: { items in
            print("Selected \(items.count) items")
        },
        onCancel: {
            print("Cancelled")
        },
        onReanalyze: {
            print("Re-analyze requested")
        }
    )
    .modelContainer(container)
}
