//
//  BatchAnalysisView.swift
//  MovingBox
//
//  Created by Claude on 8/8/25.
//

import SwiftUI
import SwiftData

struct BatchAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: SettingsManager
    
    let selectedItems: [InventoryItem]
    let onDismiss: () -> Void
    
    @State private var analysisProgress: [PersistentIdentifier: AnalysisState] = [:]
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var currentDelay: TimeInterval = 1.0 // Initial delay
    @State private var consecutiveErrors = 0
    
    enum AnalysisState {
        case pending
        case analyzing
        case completed
        case failed(String)
    }
    
    private var itemsWithImages: [InventoryItem] {
        selectedItems.filter { item in
            item.imageURL != nil || !item.secondaryPhotoURLs.isEmpty
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if itemsWithImages.isEmpty {
                    ContentUnavailableView(
                        "No Images Found",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("The selected items don't contain any images to analyze.")
                    )
                } else {
                    List {
                        Section {
                            Text("AI will analyze images from \(itemsWithImages.count) selected items and update their information automatically.")
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
                                        
                                        let imageCount = (item.imageURL != nil ? 1 : 0) + item.secondaryPhotoURLs.count
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
        currentDelay = 1.0 // Reset delay
        consecutiveErrors = 0 // Reset error counter
        
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
                currentDelay = max(0.5, currentDelay * 0.9) // Reduce delay but keep minimum of 0.5s
                
            } catch {
                analysisProgress[item.persistentModelID] = .failed(error.localizedDescription)
                
                // Error: increase consecutive error count and apply exponential backoff
                consecutiveErrors += 1
                currentDelay = min(10.0, currentDelay * pow(2.0, Double(min(consecutiveErrors, 4)))) // Cap at 10 seconds
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
        var imageBase64Array: [String] = []
        
        // Get primary image if exists
        if let imageURL = item.imageURL {
            do {
                let image = try await OptimizedImageManager.shared.loadImage(url: imageURL)
                let base64Array = await OptimizedImageManager.shared.prepareMultipleImagesForAI(from: [image])
                imageBase64Array.append(contentsOf: base64Array)
            } catch {
                // Failed to load primary image - continue with secondary images
            }
        }
        
        // Get secondary images if they exist
        if !item.secondaryPhotoURLs.isEmpty {
            do {
                let secondaryImages = try await OptimizedImageManager.shared.loadSecondaryImages(from: item.secondaryPhotoURLs)
                let base64Array = await OptimizedImageManager.shared.prepareMultipleImagesForAI(from: secondaryImages)
                imageBase64Array.append(contentsOf: base64Array)
            } catch {
                // Failed to load secondary images - continue with available images
            }
        }
        
        // Skip if no images could be loaded
        guard !imageBase64Array.isEmpty else {
            throw NSError(domain: "BatchAnalysis", code: 1, userInfo: [NSLocalizedDescriptionKey: "No images could be loaded"])
        }
        
        // Perform AI analysis
        let openAI = OpenAIService(imageBase64Array: imageBase64Array, settings: settings, modelContext: modelContext)
        let imageDetails = try await openAI.getImageDetails()
        
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