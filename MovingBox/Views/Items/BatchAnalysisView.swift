//
//  BatchAnalysisView.swift
//  MovingBox
//
//  Created by Claude on 8/8/25.
//

import Dependencies
import MovingBoxAIAnalysis
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
    @State private var photoCounts: [UUID: Int] = [:]

    private var itemsWithImages: [SQLiteInventoryItem] {
        filteredItemsWithImages
    }

    @MainActor
    private func filterItemsWithImages() async {
        isFilteringItems = true
        var itemsWithPhotos: [SQLiteInventoryItem] = []
        var counts: [UUID: Int] = [:]
        for item in selectedItems {
            let count =
                (try? await database.read { db in
                    try SQLiteInventoryItemPhoto.photos(for: item.id, in: db).count
                }) ?? 0
            if count > 0 {
                itemsWithPhotos.append(item)
                counts[item.id] = count
            }
        }
        filteredItemsWithImages = itemsWithPhotos
        photoCounts = counts
        isFilteringItems = false
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

                                        let imageCount = photoCounts[item.id] ?? 0
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
        let photos = try await database.read { db in
            try SQLiteInventoryItemPhoto.photos(for: item.id, in: db)
        }

        let images = photos.compactMap { UIImage(data: $0.data) }

        guard !images.isEmpty else {
            throw NSError(
                domain: "BatchAnalysis", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No images could be loaded"])
        }

        let aiService = AIAnalysisServiceFactory.create()

        // Build AIAnalysisContext from database
        let context = await AIAnalysisContext.from(database: database, settings: settings)

        let imageDetails = try await aiService.getImageDetails(
            from: images,
            settings: settings,
            context: context
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
