//
//  SavedAnalysisVideoStore.swift
//  MovingBox
//
//  Created by Codex on 2/6/26.
//

import Foundation

struct SavedAnalysisVideo: Codable, Identifiable, Hashable {
    let id: UUID
    let url: URL
    let createdAt: Date
    let locationID: UUID?
    let locationName: String?

    init(
        id: UUID = UUID(),
        url: URL,
        createdAt: Date = Date(),
        locationID: UUID?,
        locationName: String?
    ) {
        self.id = id
        self.url = url
        self.createdAt = createdAt
        self.locationID = locationID
        self.locationName = locationName
    }

    var fileName: String {
        url.lastPathComponent
    }
}

@MainActor
enum SavedAnalysisVideoStore {
    private static let key = "savedAnalysisVideos.v1"
    private static let fileManager = FileManager.default

    static func allVideos() -> [SavedAnalysisVideo] {
        let decoded = loadStoredVideos()
        let existing = decoded.filter { fileManager.fileExists(atPath: $0.url.path) }

        if existing.count != decoded.count {
            save(existing)
        }

        return existing.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    static func addVideo(_ url: URL, location: InventoryLocation?) -> SavedAnalysisVideo {
        var videos = allVideos()
        let entry = SavedAnalysisVideo(
            url: url,
            locationID: location?.id,
            locationName: location?.name
        )
        videos.append(entry)
        save(videos)
        return entry
    }

    private static func loadStoredVideos() -> [SavedAnalysisVideo] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }

        do {
            return try JSONDecoder().decode([SavedAnalysisVideo].self, from: data)
        } catch {
            print("⚠️ SavedAnalysisVideoStore - Failed to decode saved videos: \(error.localizedDescription)")
            return []
        }
    }

    private static func save(_ videos: [SavedAnalysisVideo]) {
        do {
            let data = try JSONEncoder().encode(videos)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("⚠️ SavedAnalysisVideoStore - Failed to save videos: \(error.localizedDescription)")
        }
    }
}
