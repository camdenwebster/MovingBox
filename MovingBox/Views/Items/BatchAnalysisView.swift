//
//  BatchAnalysisView.swift
//  MovingBox
//
//  Created by Claude on 8/8/25.
//

import Dependencies
import SQLiteData
import SwiftUI

struct BatchAnalysisView: View {
    @Dependency(\.defaultDatabase) var database
    @EnvironmentObject private var settings: SettingsManager

    let selectedItems: [SQLiteInventoryItem]
    let onDismiss: () -> Void

    @State private var analysisProgress: [UUID: AnalysisState] = [:]
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var currentDelay: TimeInterval = 1.0
    @State private var consecutiveErrors = 0

    enum AnalysisState {
        case pending
        case analyzing
        case completed
        case failed(String)
    }

    @State private var filteredItemsWithImages: [SQLiteInventoryItem] = []
    @State private var isFilteringItems = true

    private var itemsWithImages: [SQLiteInventoryItem] {
        filteredItemsWithImages
    }

    private func hasAnalyzableImage(_ item: SQLiteInventoryItem) -> Bool {
        if let imageURL = item.imageURL,
            !imageURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return true
        }

        if !item.secondaryPhotoURLs.isEmpty {
            let validURLs = item.secondaryPhotoURLs.filter { url in
                !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if !validURLs.isEmpty {
                return true
            }
        }

        return false
    }

    @MainActor
    private func filterItemsWithImages() async {
        isFilteringItems = true
        filteredItemsWithImages = selectedItems.filter { hasAnalyzableImage($0) }
        isFilteringItems = false
    }

    private func getImageCount(for item: SQLiteInventoryItem) -> Int {
        let primaryCount =
            (item.imageURL != nil
                && !item.imageURL!.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ? 1 : 0
        let secondaryCount = item.secondaryPhotoURLs.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        return primaryCount + secondaryCount
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
                            .foregroundStyle(.secondary)
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
                                            .foregroundStyle(.secondary)
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
                        .foregroundStyle(.red)
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
    private func analysisStatusView(for item: SQLiteInventoryItem) -> some View {
        let state = analysisProgress[item.id] ?? .pending

        switch state {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .analyzing:
            ProgressView()
                .scaleEffect(0.8)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let error):
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
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
        currentDelay = 1.0
        consecutiveErrors = 0

        for item in itemsWithImages {
            analysisProgress[item.id] = .pending
        }

        for item in itemsWithImages {
            analysisProgress[item.id] = .analyzing

            do {
                try await analyzeItem(item)
                analysisProgress[item.id] = .completed

                consecutiveErrors = 0
                currentDelay = max(0.5, currentDelay * 0.9)

            } catch {
                analysisProgress[item.id] = .failed(error.localizedDescription)

                consecutiveErrors += 1
                currentDelay = min(10.0, currentDelay * pow(2.0, Double(min(consecutiveErrors, 4))))
            }

            try? await Task.sleep(for: .seconds(currentDelay))
        }

        isAnalyzing = false

        try? await Task.sleep(for: .seconds(1.5))
        onDismiss()
    }

    private func analyzeItem(_ item: SQLiteInventoryItem) async throws {
        var images: [UIImage] = []

        if let imageURL = item.imageURL {
            do {
                let image = try await OptimizedImageManager.shared.loadImage(url: imageURL)
                images.append(image)
            } catch {
                // Failed to load primary image - continue with secondary images
            }
        }

        if !item.secondaryPhotoURLs.isEmpty {
            do {
                let secondaryImages = try await OptimizedImageManager.shared.loadSecondaryImages(
                    from: item.secondaryPhotoURLs)
                images.append(contentsOf: secondaryImages)
            } catch {
                // Failed to load secondary images - continue with available images
            }
        }

        guard !images.isEmpty else {
            throw NSError(
                domain: "BatchAnalysis", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No images could be loaded"])
        }

        let openAI = OpenAIServiceFactory.create()
        let imageDetails = try await openAI.getImageDetails(
            from: images,
            settings: settings,
            database: database
        )

        try await database.write { db in
            try SQLiteInventoryItem.find(item.id).update {
                $0.title = imageDetails.title
                $0.desc = imageDetails.description
                $0.make = imageDetails.make
                $0.model = imageDetails.model
                $0.serial = imageDetails.serialNumber
                $0.price = Decimal(string: imageDetails.price) ?? Decimal.zero
                $0.hasUsedAI = true
            }.execute(db)
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    BatchAnalysisView(
        selectedItems: [],
        onDismiss: {}
    )
    .environmentObject(SettingsManager())
}
