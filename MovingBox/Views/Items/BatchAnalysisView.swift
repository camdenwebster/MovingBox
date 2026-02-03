//
//  BatchAnalysisView.swift
//  MovingBox
//
//  Created by Claude on 8/8/25.
//

import Dependencies
import SQLiteData
import SwiftData
import SwiftUI

struct BatchAnalysisView: View {
    @Dependency(\.defaultDatabase) var database
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: SettingsManager

    let selectedItems: [InventoryItem]
    let onDismiss: () -> Void

    @State private var analysisProgress: [PersistentIdentifier: AnalysisState] = [:]
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var currentDelay: TimeInterval = 1.0  // Initial delay
    @State private var consecutiveErrors = 0

    enum AnalysisState {
        case pending
        case analyzing
        case completed
        case failed(String)
    }

    @State private var filteredItemsWithImages: [InventoryItem] = []
    @State private var isFilteringItems = true

    private var itemsWithImages: [InventoryItem] {
        filteredItemsWithImages
    }

    private func hasAnalyzableImage(_ item: InventoryItem) -> Bool {
        // Check primary image URL
        if let imageURL = item.imageURL,
            !imageURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return true
        }

        // Check secondary photo URLs (filter out empty strings)
        if !item.secondaryPhotoURLs.isEmpty {
            let validURLs = item.secondaryPhotoURLs.filter { url in
                !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if !validURLs.isEmpty {
                return true
            }
        }

        // Check legacy data property (for items that haven't migrated yet)
        if let data = item.data, !data.isEmpty {
            return true
        }

        return false
    }

    @MainActor
    private func filterItemsWithImages() async {
        isFilteringItems = true

        var itemsWithValidImages: [InventoryItem] = []

        for item in selectedItems {
            let hasImages = await item.hasAnalyzableImageAfterMigration()
            if hasImages {
                itemsWithValidImages.append(item)
            }
        }

        filteredItemsWithImages = itemsWithValidImages
        isFilteringItems = false
    }

    private func getImageCount(for item: InventoryItem) -> Int {
        let primaryCount =
            (item.imageURL != nil
                && !item.imageURL!.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ? 1 : 0
        let secondaryCount = item.secondaryPhotoURLs.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        let legacyCount = (item.data != nil && !item.data!.isEmpty) ? 1 : 0
        return primaryCount + secondaryCount + legacyCount
    }

    var body: some View {
        NavigationView {
            VStack {
                if isFilteringItems {
                    ProgressView("Checking for images...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if itemsWithImages.isEmpty {
                    ContentUnavailableView(
                        "No Images Found",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("The selected items don't contain any images to analyze.")
                    )
                } else {
                    List {
                        Section {
                            Text(
                                "AI will analyze images from \(itemsWithImages.count) selected items and update their information automatically."
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        } header: {
                            Text("Batch Analysis")
                        }

                        Section {
                            ForEach(itemsWithImages) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title.isEmpty ? "Untitled Item" : item.title)
                                            .font(.headline)

                                        let imageCount = getImageCount(for: item)
                                        Text("\(imageCount) image\(imageCount == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    analysisStatusView(for: item)
                                }
                            }
                        } header: {
                            Text("Items to Analyze")
                        }
                    }

                    if !isAnalyzing {
                        Button(action: startBatchAnalysis) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Start Analysis")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("Batch AI Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onDismiss)
                }

                if isAnalyzing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .task {
                await filterItemsWithImages()
            }
        }
    }

    @ViewBuilder
    private func analysisStatusView(for item: InventoryItem) -> some View {
        let state = analysisProgress[item.persistentModelID] ?? .pending

        switch state {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.secondary)
        case .analyzing:
            ProgressView()
                .scaleEffect(0.8)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed(let error):
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .help(error)
        }
    }

    private func startBatchAnalysis() {
        Task {
            await performBatchAnalysis()
        }
    }

    @MainActor
    private func performBatchAnalysis() async {
        isAnalyzing = true
        errorMessage = nil
        currentDelay = 1.0  // Reset delay
        consecutiveErrors = 0  // Reset error counter

        // Initialize all items as pending
        for item in itemsWithImages {
            analysisProgress[item.persistentModelID] = .pending
        }

        for item in itemsWithImages {
            analysisProgress[item.persistentModelID] = .analyzing

            do {
                try await analyzeItem(item)
                analysisProgress[item.persistentModelID] = .completed

                // Success: reset consecutive errors and reduce delay slightly
                consecutiveErrors = 0
                currentDelay = max(0.5, currentDelay * 0.9)  // Reduce delay but keep minimum of 0.5s

            } catch {
                analysisProgress[item.persistentModelID] = .failed(error.localizedDescription)

                // Error: increase consecutive error count and apply exponential backoff
                consecutiveErrors += 1
                currentDelay = min(10.0, currentDelay * pow(2.0, Double(min(consecutiveErrors, 4))))  // Cap at 10 seconds
            }

            // Adaptive delay between requests based on success/failure rate
            let delayNanoseconds = UInt64(currentDelay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }

        isAnalyzing = false

        // Show completion message for a moment, then dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onDismiss()
        }
    }

    private func analyzeItem(_ item: InventoryItem) async throws {
        var images: [UIImage] = []

        // Ensure migration is complete before trying to load images
        _ = await item.hasAnalyzableImageAfterMigration()

        // Get primary image if exists
        if let imageURL = item.imageURL {
            do {
                let image = try await OptimizedImageManager.shared.loadImage(url: imageURL)
                images.append(image)
            } catch {
                // Failed to load primary image - continue with secondary images
            }
        }

        // Get secondary images if they exist
        if !item.secondaryPhotoURLs.isEmpty {
            do {
                let secondaryImages = try await OptimizedImageManager.shared.loadSecondaryImages(
                    from: item.secondaryPhotoURLs)
                images.append(contentsOf: secondaryImages)
            } catch {
                // Failed to load secondary images - continue with available images
            }
        }

        // Handle legacy data if no modern images are available
        if images.isEmpty, let data = item.data, let image = UIImage(data: data) {
            images.append(image)
        }

        // Skip if no images could be loaded
        guard !images.isEmpty else {
            throw NSError(
                domain: "BatchAnalysis", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No images could be loaded"])
        }

        // Perform AI analysis
        let openAI = OpenAIServiceFactory.create()
        let imageDetails = try await openAI.getImageDetails(
            from: images,
            settings: settings,
            database: database
        )

        // Update the item with analysis results
        item.title = imageDetails.title
        item.desc = imageDetails.description
        item.make = imageDetails.make
        item.model = imageDetails.model
        item.serial = imageDetails.serialNumber
        item.price = Decimal(string: imageDetails.price) ?? Decimal.zero
        item.hasUsedAI = true

        // Save the changes
        try modelContext.save()
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        let items = try previewer.container.mainContext.fetch(FetchDescriptor<InventoryItem>())

        return BatchAnalysisView(
            selectedItems: Array(items.prefix(3)),
            onDismiss: {}
        )
        .modelContainer(previewer.container)
        .environmentObject(SettingsManager())
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
