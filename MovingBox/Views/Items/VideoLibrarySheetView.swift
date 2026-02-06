//
//  VideoLibrarySheetView.swift
//  MovingBox
//
//  Created by Codex on 2/6/26.
//

import PhotosUI
import SwiftUI

struct VideoLibrarySheetView: View {
    @Environment(\.dismiss) private var dismiss

    let location: InventoryLocation?
    let onAnalyzeVideo: (URL) -> Void

    @State private var savedVideos: [SavedAnalysisVideo] = []
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var showingVideoPicker = false
    @State private var sharedVideo: SavedAnalysisVideo?
    @State private var processingVideo = false
    @State private var errorMessage: String?

    private var visibleVideos: [SavedAnalysisVideo] {
        guard let location else { return savedVideos }
        return savedVideos.filter { $0.locationID == location.id }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingVideoPicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Video")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("videoLibrary-addButton")
                }

                if visibleVideos.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Videos Yet",
                            systemImage: "video",
                            description: Text("Add a video to start video analysis.")
                        )
                    }
                } else {
                    Section("Saved Videos") {
                        ForEach(visibleVideos) { video in
                            HStack(spacing: 12) {
                                Image(systemName: "video.fill")
                                    .foregroundStyle(.tint)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(video.fileName)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Text(Self.dateFormatter.string(from: video.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if location == nil, let locationName = video.locationName, !locationName.isEmpty {
                                        Text(locationName)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer(minLength: 8)

                                Button("Analyze") {
                                    onAnalyzeVideo(video.url)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .accessibilityIdentifier("videoLibrary-analyze-\(video.id.uuidString)")

                                Button {
                                    sharedVideo = video
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("videoLibrary-share-\(video.id.uuidString)")
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if processingVideo {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                        ProgressView("Preparing video...")
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .alert("Video Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Unable to process selected video.")
            }
            .photosPicker(
                isPresented: $showingVideoPicker,
                selection: $selectedVideoItem,
                matching: .videos
            )
            .onChange(of: selectedVideoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    await processSelectedVideo(newValue)
                }
            }
            .sheet(item: $sharedVideo) { video in
                ShareSheet(activityItems: [video.url])
            }
            .onAppear {
                reloadVideos()
            }
        }
    }

    private func reloadVideos() {
        savedVideos = SavedAnalysisVideoStore.allVideos()
    }

    @MainActor
    private func processSelectedVideo(_ item: PhotosPickerItem) async {
        processingVideo = true
        defer {
            processingVideo = false
            selectedVideoItem = nil
            showingVideoPicker = false
        }

        do {
            if let url = try await item.loadTransferable(type: URL.self) {
                try await saveAndAnalyzeVideo(from: url)
                return
            }

            if let data = try await item.loadTransferable(type: Data.self) {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                try data.write(to: tempURL)
                try await saveAndAnalyzeVideo(from: tempURL)
                return
            }

            errorMessage = "Unable to load the selected video."
        } catch {
            errorMessage = "Failed to process video: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func saveAndAnalyzeVideo(from url: URL) async throws {
        let savedURL = try await OptimizedImageManager.shared.saveVideo(url)
        _ = SavedAnalysisVideoStore.addVideo(savedURL, location: location)
        reloadVideos()
        onAnalyzeVideo(savedURL)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
