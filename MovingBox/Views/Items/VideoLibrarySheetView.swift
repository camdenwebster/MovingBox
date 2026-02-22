//
//  VideoLibrarySheetView.swift
//  MovingBox
//
//  Created by Codex on 2/6/26.
//

import AVFoundation
import PhotosUI
import SQLiteData
import SwiftUI

struct VideoLibrarySheetView: View {
    @Environment(\.dismiss) private var dismiss

    let location: SQLiteInventoryLocation?
    let onAnalyzeVideo: (URL) async throws -> Void

    @State private var savedVideos: [SavedAnalysisVideo] = []
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var showingVideoPicker = false
    @State private var sharedVideo: SavedAnalysisVideo?
    @State private var processingVideo = false
    @State private var errorMessage: String?
    @State private var videoThumbnails: [UUID: UIImage] = [:]
    @State private var thumbnailLoadingIDs: Set<UUID> = []

    private var visibleVideos: [SavedAnalysisVideo] {
        guard let location else { return savedVideos }
        return savedVideos.filter { $0.locationID == location.id }
    }

    var body: some View {
        NavigationStack {
            List {
                addNewVideoRow

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
                                videoThumbnailView(for: video)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(video.fileName)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Text(Self.dateFormatter.string(from: video.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if let location {
                                        Image(location.sfSymbolName ?? "mappin.circle.fill")
                                        Text(location.name)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer(minLength: 8)

                                Button("Analyze") {
                                    Task {
                                        await analyzeSavedVideo(video)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(processingVideo)
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
                            .task(id: video.id) {
                                await loadThumbnailIfNeeded(for: video)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        dismiss()
                    }
                    .accessibilityIdentifier("video-sheet-done")
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

    private var addNewVideoRow: some View {
        Button {
            showingVideoPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                Text("Add New Video")
                    .fontWeight(.semibold)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityIdentifier("videoLibrary-addButton")
    }

    private func reloadVideos() {
        savedVideos = SavedAnalysisVideoStore.allVideos()
        let validIDs = Set(savedVideos.map(\.id))
        videoThumbnails = videoThumbnails.filter { validIDs.contains($0.key) }
        thumbnailLoadingIDs = Set(thumbnailLoadingIDs.filter { validIDs.contains($0) })
    }

    @ViewBuilder
    private func videoThumbnailView(for video: SavedAnalysisVideo) -> some View {
        Group {
            if let thumbnail = videoThumbnails[video.id] {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemFill))
                    Image(systemName: "video.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(.rect(cornerRadius: 8))
    }

    @MainActor
    private func loadThumbnailIfNeeded(for video: SavedAnalysisVideo) async {
        guard videoThumbnails[video.id] == nil else { return }
        guard !thumbnailLoadingIDs.contains(video.id) else { return }

        thumbnailLoadingIDs.insert(video.id)
        defer { thumbnailLoadingIDs.remove(video.id) }

        if let thumbnail = await Self.generateThumbnail(from: video.url) {
            videoThumbnails[video.id] = thumbnail
        }
    }

    private static func generateThumbnail(from url: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 240, height: 240)

            do {
                let firstFrameTime = CMTime(seconds: 0, preferredTimescale: 600)
                let cgImage = try generator.copyCGImage(at: firstFrameTime, actualTime: nil)
                return UIImage(cgImage: cgImage)
            } catch {
                print("⚠️ VideoLibrarySheetView - Failed to generate thumbnail: \(error.localizedDescription)")
                return nil
            }
        }.value
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
        try await onAnalyzeVideo(savedURL)
    }

    @MainActor
    private func analyzeSavedVideo(_ video: SavedAnalysisVideo) async {
        processingVideo = true
        defer {
            processingVideo = false
        }

        do {
            try await onAnalyzeVideo(video.url)
        } catch {
            errorMessage = "Failed to prepare video: \(error.localizedDescription)"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
