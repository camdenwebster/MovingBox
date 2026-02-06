import SwiftData
import SwiftUI
import SwiftUIBackports

struct VideoItemSelectionListView: View {

    // MARK: - Properties

    @State private var viewModel: MultiItemSelectionViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager

    let images: [UIImage]
    let analysisResponse: MultiItemAnalysisResponse
    let isStreamingResults: Bool
    let streamingStatusText: String?
    let onItemsSelected: ([InventoryItem]) -> Void
    let onCancel: () -> Void
    let onReanalyze: (() -> Void)?

    // MARK: - State

    @State private var selectedLocation: InventoryLocation?
    @State private var selectedHome: Home?
    @State private var showingLocationPicker = false
    @State private var isPreparingRows = true
    @State private var itemDisplayOrder: [String] = []
    @State private var knownDetectedItemIDs: Set<String> = []
    @State private var rowPreparationTask: Task<Void, Never>?
    @State private var didStreamResults = false
    @State private var showAnalysisCompletionMessage = false
    private let bottomPanelReservedHeight: CGFloat = 230
    private let bottomPanelCornerRadius: CGFloat = 24

    private let selectionHaptic = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Init

    init(
        analysisResponse: MultiItemAnalysisResponse,
        images: [UIImage],
        location: InventoryLocation?,
        modelContext: ModelContext,
        aiAnalysisService: AIAnalysisServiceProtocol? = nil,
        isStreamingResults: Bool = false,
        streamingStatusText: String? = nil,
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
        self.analysisResponse = analysisResponse
        self.isStreamingResults = isStreamingResults
        self.streamingStatusText = streamingStatusText
        self.onItemsSelected = onItemsSelected
        self.onCancel = onCancel
        self.onReanalyze = onReanalyze
        self._selectedLocation = State(initialValue: location)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

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
                    if let onReanalyze {
                        Button(action: onReanalyze) {
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        }
                        .accessibilityIdentifier("videoItemReanalyzeButton")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        onCancel()
                    }
                    .accessibilityIdentifier("videoItemCancelButton")
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
                viewModel.updateAnalysisResponse(analysisResponse)
                refreshItemOrdering()
                didStreamResults = didStreamResults || isStreamingResults
                showAnalysisCompletionMessage = false
                scheduleRowPreparation(forceFullPreparation: !isStreamingResults)
            }
        }
    }

    private var mainContentView: some View {
        VStack(spacing: 0) {
            if isStreamingResults {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(streamingStatusText ?? "Analyzing more frames...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            if isPreparingRows {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Preparing item previews...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if isStreamingResults {
                                VideoDetectedItemListCard(
                                    item: placeholderItem,
                                    isSelected: false,
                                    matchedLabel: nil,
                                    thumbnail: nil,
                                    duplicateGroupHint: nil,
                                    isSkeleton: true,
                                    useSimplifiedRendering: true,
                                    onToggleSelection: {}
                                )
                                .id("streaming-skeleton-top")
                                .disabled(true)
                                .transition(insertionTransition)
                            } else if showAnalysisCompletionMessage {
                                VideoAnalysisCompletedBanner()
                                    .id("streaming-complete-banner")
                                    .transition(insertionTransition)
                            }

                            ForEach(orderedDetectedItemGroups) { group in
                                if group.isPotentialDuplicateGroup {
                                    duplicateGroupHeader(itemCount: group.items.count)
                                }

                                ForEach(orderedItems(in: group)) { item in
                                    VideoDetectedItemListCard(
                                        item: item,
                                        isSelected: viewModel.isItemSelected(item),
                                        matchedLabel: viewModel.getMatchingLabel(for: item),
                                        thumbnail: viewModel.rowThumbnail(for: item),
                                        duplicateGroupHint: viewModel.duplicateHint(for: item),
                                        isSkeleton: false,
                                        useSimplifiedRendering: viewModel.detectedItems.count > 18,
                                        onToggleSelection: {
                                            selectionHaptic.impactOccurred()
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                viewModel.toggleItemSelection(item)
                                            }
                                        }
                                    )
                                    .transition(insertionTransition)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, bottomPanelReservedHeight)
                        .animation(listMutationAnimation, value: itemDisplayOrder)
                        .animation(isPerformanceModeEnabled ? nil : .easeInOut(duration: 0.2), value: isStreamingResults)
                    }

                    bottomActionPanel
                        .padding(.bottom, -geometry.safeAreaInsets.bottom)
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: images.count) {
            Task { @MainActor in
                await viewModel.updateImages(images)
                scheduleRowPreparation(forceFullPreparation: !isStreamingResults)
            }
        }
        .onChange(of: analysisResponseSignature) {
            viewModel.updateAnalysisResponse(analysisResponse)
            refreshItemOrdering()
            scheduleRowPreparation(forceFullPreparation: !isStreamingResults)
        }
        .onChange(of: isStreamingResults) {
            didStreamResults = didStreamResults || isStreamingResults
            if !isStreamingResults {
                showAnalysisCompletionMessage = didStreamResults
                scheduleRowPreparation(forceFullPreparation: true)
            } else {
                showAnalysisCompletionMessage = false
                scheduleRowPreparation(forceFullPreparation: false)
            }
        }
        .onDisappear {
            rowPreparationTask?.cancel()
            rowPreparationTask = nil
            viewModel.releaseTemporaryImageMemory(clearSourceImages: true)
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
                    "We weren't able to identify any items in this video. You can try recording again or add an item manually."
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

    @ViewBuilder
    private func duplicateGroupHeader(itemCount: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "link")
                .font(.caption)
            Text("Potential duplicates (\(itemCount))")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    private var placeholderItem: DetectedInventoryItem {
        DetectedInventoryItem(
            id: "placeholder",
            title: "Analyzing item...",
            description: "Getting details from additional frames.",
            category: "",
            make: "",
            model: "",
            estimatedPrice: "",
            confidence: 0.0
        )
    }

    private var selectionSummaryView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.selectedItemsCount) of \(viewModel.detectedItems.count) selected")
                        .font(.headline)
                        .accessibilityIdentifier("videoItemSelectionCounter")

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

                    if isStreamingResults {
                        Text("More items may still appear while analysis completes.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if viewModel.selectedItemsCount == viewModel.detectedItems.count {
                    Button("Deselect All") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.deselectAllItems()
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("videoItemDeselectAllButton")
                } else {
                    Button("Select All") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectAllItems()
                        }
                    }
                    .backport.glassProminentButtonStyle()
                    .accessibilityIdentifier("videoItemSelectAllButton")
                }
            }

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
                .accessibilityIdentifier("videoItemLocationButton")
            }
        }
        .padding(.vertical, 16)
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
                    if isStreamingResults {
                        Text("Finalizing analysis...")
                            .font(.headline)
                    } else {
                        Text(
                            "Add \(viewModel.selectedItemsCount) Item\(viewModel.selectedItemsCount == 1 ? "" : "s")"
                        )
                        .font(.headline)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("videoItemContinueButton")
    }

    private var bottomActionPanel: some View {
        VStack(spacing: 0) {
            selectionSummaryView
                .padding(.horizontal, 16)

            continueButton
                .backport.glassProminentButtonStyle()
                .disabled(viewModel.selectedItemsCount == 0 || viewModel.isProcessingSelection || isStreamingResults)
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
        .background(
            .ultraThinMaterial,
            in: TopRoundedCorners(radius: bottomPanelCornerRadius)
        )
        .overlay(alignment: .top) {
            Divider()
                .opacity(0.35)
        }
    }

    @MainActor
    private func prepareRows() async {
        guard !viewModel.detectedItems.isEmpty else {
            isPreparingRows = false
            return
        }

        isPreparingRows = true
        let prewarmCount = min(6, viewModel.detectedItems.count)
        await viewModel.computeCroppedImages(limit: prewarmCount)
        guard !Task.isCancelled else {
            isPreparingRows = false
            return
        }
        isPreparingRows = false

        await viewModel.computeCroppedImages()
        guard !Task.isCancelled else { return }
        viewModel.startEnrichment(settings: settingsManager)
    }

    @MainActor
    private func prepareStreamingRows() async {
        guard !viewModel.detectedItems.isEmpty else {
            isPreparingRows = false
            return
        }

        isPreparingRows = true
        await viewModel.computeCroppedImages(limit: viewModel.detectedItems.count)
        guard !Task.isCancelled else { return }
        isPreparingRows = false
    }

    @MainActor
    private func scheduleRowPreparation(forceFullPreparation: Bool) {
        rowPreparationTask?.cancel()
        rowPreparationTask = nil

        rowPreparationTask = Task { @MainActor in
            if forceFullPreparation {
                await prepareRows()
            } else {
                await prepareStreamingRows()
            }
        }
    }

    private var analysisResponseSignature: String {
        analysisResponse.safeItems
            .map {
                "\($0.id)|\($0.title)|\($0.category)|\($0.make)|\($0.model)|\($0.confidence)"
            }
            .joined(separator: "||")
    }

    private var isPerformanceModeEnabled: Bool {
        viewModel.detectedItems.count > 24
    }

    private var listMutationAnimation: Animation? {
        isPerformanceModeEnabled ? nil : .easeOut(duration: 0.18)
    }

    private var insertionTransition: AnyTransition {
        isPerformanceModeEnabled ? .identity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
    }

    private var itemRankLookup: [String: Int] {
        var ranks: [String: Int] = [:]
        for (index, id) in itemDisplayOrder.enumerated() {
            ranks[id] = index
        }

        var nextRank = itemDisplayOrder.count
        for item in viewModel.detectedItems where ranks[item.id] == nil {
            ranks[item.id] = nextRank
            nextRank += 1
        }
        return ranks
    }

    private var orderedDetectedItemGroups: [MultiItemSelectionViewModel.DetectedItemDisplayGroup] {
        let ranks = itemRankLookup
        return viewModel.detectedItemGroups.sorted { lhs, rhs in
            groupRank(lhs, using: ranks) < groupRank(rhs, using: ranks)
        }
    }

    private func orderedItems(in group: MultiItemSelectionViewModel.DetectedItemDisplayGroup) -> [DetectedInventoryItem] {
        let ranks = itemRankLookup
        return group.items.sorted { lhs, rhs in
            (ranks[lhs.id] ?? Int.max) < (ranks[rhs.id] ?? Int.max)
        }
    }

    private func groupRank(
        _ group: MultiItemSelectionViewModel.DetectedItemDisplayGroup,
        using ranks: [String: Int]
    ) -> Int {
        group.items.map { ranks[$0.id] ?? Int.max }.min() ?? Int.max
    }

    private func refreshItemOrdering() {
        let currentIDs = viewModel.detectedItems.map(\.id)
        let currentIDSet = Set(currentIDs)

        if itemDisplayOrder.isEmpty {
            itemDisplayOrder = currentIDs
            knownDetectedItemIDs = currentIDSet
            return
        }

        let newIDs = currentIDs.filter { !knownDetectedItemIDs.contains($0) }
        itemDisplayOrder.removeAll { !currentIDSet.contains($0) }

        if !newIDs.isEmpty {
            itemDisplayOrder = newIDs + itemDisplayOrder
        }

        let missingIDs = currentIDs.filter { !itemDisplayOrder.contains($0) }
        if !missingIDs.isEmpty {
            itemDisplayOrder.append(contentsOf: missingIDs)
        }

        knownDetectedItemIDs = currentIDSet
    }

    private func handleContinue() {
        guard viewModel.selectedItemsCount > 0 else { return }

        Task {
            do {
                viewModel.updateSelectedLocation(selectedLocation)
                let createdItems = try await viewModel.createSelectedInventoryItems()
                onItemsSelected(createdItems)
            } catch {
                print("Error creating items: \(error)")
            }
        }
    }
}

private struct VideoDetectedItemListCard: View {
    let item: DetectedInventoryItem
    let isSelected: Bool
    let matchedLabel: InventoryLabel?
    let thumbnail: UIImage?
    let duplicateGroupHint: String?
    let isSkeleton: Bool
    let useSimplifiedRendering: Bool
    let onToggleSelection: () -> Void

    var body: some View {
        Button(action: onToggleSelection) {
            HStack(alignment: .top, spacing: 12) {
                thumbnailView

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        confidenceBadge
                    }

                    if let matchedLabel {
                        Label(matchedLabel.name, systemImage: "tag")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let duplicateGroupHint {
                        Label(duplicateGroupHint, systemImage: "person.2.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }

                    if !item.make.isEmpty || !item.model.isEmpty {
                        Text("\(item.make) \(item.model)".trimmingCharacters(in: .whitespaces))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if !item.estimatedPrice.isEmpty {
                        Text(item.estimatedPrice)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.subheadline)
                            .foregroundStyle(isSelected ? .blue : .secondary)
                        Text(isSelected ? "Selected for adding" : "Tap to select")
                            .font(.caption)
                            .foregroundStyle(isSelected ? .blue : .secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(useSimplifiedRendering ? Color(.secondarySystemBackground) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray5), lineWidth: isSelected ? 2 : 1)
                    .animation(useSimplifiedRendering ? nil : .easeInOut(duration: 0.2), value: isSelected)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(useSimplifiedRendering ? 1.0 : (isSelected ? 1.01 : 1.0))
        .animation(useSimplifiedRendering ? nil : .easeInOut(duration: 0.2), value: isSelected)
        .redacted(reason: isSkeleton ? .placeholder : [])
        .modifier(ShimmerModifier(isActive: isSkeleton))
    }

    private var thumbnailView: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain")
                .font(.caption2)

            Text(item.formattedConfidence)
                .font(.caption2)
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

private struct VideoAnalysisCompletedBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Video analysis complete")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Review the list for potential duplicates before adding items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = -0.8

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.45),
                                Color.white.opacity(0.0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.8)
                        .offset(x: geometry.size.width * phase)
                    }
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard isActive else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
            .onChange(of: isActive) {
                if isActive {
                    phase = -0.8
                    withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                        phase = 1.2
                    }
                }
            }
    }
}

private struct TopRoundedCorners: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
