//
//  MultiItemSelectionView.swift
//  MovingBox
//
//  Created by Claude Code on 9/19/25.
//

import SwiftUI
import SwiftData

struct MultiItemSelectionView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel: MultiItemSelectionViewModel
    @Environment(\.dismiss) private var dismiss
    
    let onItemsSelected: ([InventoryItem]) -> Void
    let onCancel: () -> Void
    
    // MARK: - Animation Properties
    
    private let cardTransition = Animation.easeInOut(duration: 0.3)
    private let selectionHaptic = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Initialization
    
    init(
        analysisResponse: MultiItemAnalysisResponse,
        images: [UIImage],
        location: InventoryLocation?,
        modelContext: ModelContext,
        onItemsSelected: @escaping ([InventoryItem]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: images,
            location: location,
            modelContext: modelContext
        ))
        self.onItemsSelected = onItemsSelected
        self.onCancel = onCancel
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.hasNoItems {
                    noItemsView
                } else {
                    mainContentView
                        .ignoresSafeArea(edges: .top)
                }

                if viewModel.isProcessingSelection {
                    processingOverlay
                }
            }
            .navigationTitle("We found \(viewModel.detectedItems.count) item\(viewModel.detectedItems.count == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error Creating Items", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - View Components
    private var mainContentView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background image with gradient
                imageView
                    .frame(height: geometry.size.height * 0.5)

                // Card content overlay
                VStack(spacing: 0) {
                    // Spacer to push content down
                    Spacer()
                        .frame(height: geometry.size.height * 0.35)

                    // Card and controls section
                    VStack {
                        cardCarouselView
                        instructionText
                        selectionSummaryView
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
    
    private var noItemsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Items Detected")
                    .font(.headline)
                
                Text("We weren't able to identify any items in this photo. You can try taking another photo or add an item manually.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                onCancel()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 32)
    }
    

    
    private var instructionText: some View {
        Text("Swipe through and select the items you want to add to your inventory")
            .font(.caption)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }

    
    private var imageView: some View {
        ZStack(alignment: .bottom) {
            // Photo image - extends to edges
            if let image = viewModel.images.first {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                // Fallback placeholder
                Color.gray.opacity(0.3)
            }

            // Gradient overlay for smooth transition
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.clear,
                    Color(.systemBackground).opacity(0.3),
                    Color(.systemBackground).opacity(0.6),
                    Color(.systemBackground).opacity(0.9),
                    Color(.systemBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
        }
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
    }
    
    private var cardCarouselView: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(0..<viewModel.detectedItems.count, id: \.self) { index in
                        let item = viewModel.detectedItems[index]
                        DetectedItemCard(
                            item: item,
                            isSelected: viewModel.isItemSelected(item),
                            onToggleSelection: {
                                selectionHaptic.impactOccurred()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.toggleItemSelection(item)
                                }
                            }
                        )
                        .frame(width: geometry.size.width * 0.85, height: 200)
                        .scrollTransition { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1.0 : 0.8)
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.95)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, geometry.size.width * 0.075)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }
    
    private var navigationControlsView: some View {
        HStack(spacing: 20) {
            // Previous button
            Button(action: viewModel.goToPreviousCard) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(viewModel.canGoToPreviousCard ? .primary : .secondary)
            }
            .disabled(!viewModel.canGoToPreviousCard)
            
            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<viewModel.detectedItems.count, id: \.self) { index in
                    Circle()
                        .fill(index == viewModel.currentCardIndex ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == viewModel.currentCardIndex ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.currentCardIndex)
                }
            }
            
            // Next button
            Button(action: viewModel.goToNextCard) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(viewModel.canGoToNextCard ? .primary : .secondary)
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
                    
                    if viewModel.selectedItemsCount > 0 {
                        Text("Ready to add to inventory")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                } else {
                    Button("Select All") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectAllItems()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Continue button (full width)
            Button(action: handleContinue) {
                HStack {
                    Spacer()
                    Text("Add \(viewModel.selectedItemsCount) Item\(viewModel.selectedItemsCount == 1 ? "" : "s")")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedItemsCount == 0)
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Creating items...")
                    .font(.headline)
                
                if viewModel.creationProgress > 0 {
                    ProgressView(value: viewModel.creationProgress)
                        .frame(width: 200)
                    
                    Text("\(Int(viewModel.creationProgress * 100))% complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Actions
    
    private func handleContinue() {
        guard viewModel.selectedItemsCount > 0 else { return }
        
        Task {
            do {
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
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Spacer()
                    confidenceBadge
                }

                // Category and make/model
                if !item.category.isEmpty || (!item.make.isEmpty && !item.model.isEmpty) {
                    VStack(alignment: .leading, spacing: 2) {
                        if !item.category.isEmpty {
                            Label(item.category, systemImage: "tag")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if !item.make.isEmpty && !item.model.isEmpty {
                            Label("\(item.make) \(item.model)", systemImage: "info.circle")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Description
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                // Price
                if !item.estimatedPrice.isEmpty {
                    HStack {
                        Label("Estimated Value", systemImage: "dollarsign.circle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(item.estimatedPrice)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 4)
                }

                Spacer()

                // Selection status text (pinned to bottom)
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.callout)
                        .foregroundColor(isSelected ? .blue : .secondary)

                    Text(isSelected ? "Selected for adding" : "Tap to select")
                        .font(.caption)
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
            }
            .padding()
//            .frame(maxHeight: .infinity, alignment: .bottom)
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
    
    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain")
                .font(.caption)
            
            Text(item.formattedConfidence)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(confidenceColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidenceColor.opacity(0.1))
        .cornerRadius(8)
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
    let container = try! ModelContainer(for: InventoryItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
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
            )
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
        }
    )
    .modelContainer(container)
}
