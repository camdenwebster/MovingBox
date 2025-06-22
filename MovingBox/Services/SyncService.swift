//
//  SyncService.swift
//  MovingBox
//
//  Created by Camden Webster on 6/22/25.
//

import Foundation
import SwiftData

// MARK: - Sync Service Protocol

/// Protocol that defines the interface for sync services (iCloud, HomeBox, etc.)
protocol SyncService: Actor {
    /// The name of the sync service (e.g., "iCloud", "HomeBox")
    var serviceName: String { get }
    
    /// Whether the sync service is currently configured and ready to use
    var isConfigured: Bool { get async }
    
    /// Whether the sync service is currently authenticated
    var isAuthenticated: Bool { get async }
    
    /// Current sync status
    var syncStatus: SyncStatus { get async }
    
    // MARK: - Configuration
    
    /// Configure the sync service with necessary parameters
    /// - Parameter config: Service-specific configuration
    func configure(with config: SyncConfiguration) async throws
    
    /// Authenticate with the sync service
    /// - Parameter credentials: Service-specific authentication credentials
    func authenticate(with credentials: SyncCredentials) async throws
    
    /// Disconnect from the sync service and clear authentication
    func disconnect() async throws
    
    // MARK: - Sync Operations
    
    /// Perform a full bidirectional sync of all data
    func fullSync() async throws
    
    /// Sync specific items that have changed locally
    /// - Parameter items: Array of items to sync
    func syncLocalChanges<T: SyncableModel>(_ items: [T]) async throws
    
    /// Pull remote changes from the sync service
    func pullRemoteChanges() async throws
    
    /// Push local changes to the sync service
    func pushLocalChanges() async throws
    
    // MARK: - Individual Item Operations
    
    /// Create a new item in the remote sync service
    /// - Parameter item: The item to create
    func createItem<T: SyncableModel>(_ item: T) async throws
    
    /// Update an existing item in the remote sync service
    /// - Parameter item: The item to update
    func updateItem<T: SyncableModel>(_ item: T) async throws
    
    /// Delete an item from the remote sync service
    /// - Parameter item: The item to delete
    func deleteItem<T: SyncableModel>(_ item: T) async throws
    
    // MARK: - Photo Operations
    
    /// Upload a photo to the sync service
    /// - Parameters:
    ///   - imageURL: Local URL of the image
    ///   - itemId: ID of the item the photo belongs to
    /// - Returns: Remote URL of the uploaded photo
    func uploadPhoto(imageURL: URL, for itemId: String) async throws -> URL
    
    /// Download a photo from the sync service
    /// - Parameter remoteURL: Remote URL of the photo
    /// - Returns: Local URL where the photo was saved
    func downloadPhoto(from remoteURL: URL) async throws -> URL
    
    /// Delete a photo from the sync service
    /// - Parameter remoteURL: Remote URL of the photo to delete
    func deletePhoto(at remoteURL: URL) async throws
}

// MARK: - Supporting Types

/// Current status of sync operations
enum SyncStatus: Sendable {
    case idle
    case syncing(progress: Double)
    case completed(at: Date)
    case failed(error: SyncError)
}

/// Configuration data for sync services
protocol SyncConfiguration: Sendable {
    var serviceType: SyncServiceType { get }
}

/// Authentication credentials for sync services
protocol SyncCredentials: Sendable {
    var serviceType: SyncServiceType { get }
}

/// Types of sync services available
enum SyncServiceType: String, CaseIterable, Sendable {
    case icloud = "iCloud"
    case homebox = "HomeBox"
    
    var displayName: String {
        return self.rawValue
    }
}

/// Errors that can occur during sync operations
enum SyncError: LocalizedError, Sendable {
    case notConfigured
    case notAuthenticated
    case networkUnavailable
    case serverError(statusCode: Int, message: String?)
    case authenticationFailed(reason: String?)
    case conflictResolutionFailed
    case invalidData(description: String)
    case photoUploadFailed(url: URL)
    case photoDownloadFailed(url: URL)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sync service is not configured"
        case .notAuthenticated:
            return "Sync service is not authenticated"
        case .networkUnavailable:
            return "Network connection is unavailable"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown error")"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason ?? "Unknown reason")"
        case .conflictResolutionFailed:
            return "Failed to resolve sync conflicts"
        case .invalidData(let description):
            return "Invalid data: \(description)"
        case .photoUploadFailed(let url):
            return "Failed to upload photo: \(url.lastPathComponent)"
        case .photoDownloadFailed(let url):
            return "Failed to download photo: \(url.lastPathComponent)"
        case .unknownError(let error):
            return "Unknown sync error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Syncable Model Protocol

/// Protocol that models must conform to in order to be synced
protocol SyncableModel: Model, Sendable {
    /// Unique identifier for the model
    var id: UUID { get }
    
    /// Remote ID assigned by the sync service (nil if not synced yet)
    var remoteId: String? { get set }
    
    /// Timestamp of last modification
    var lastModified: Date { get set }
    
    /// Timestamp of last successful sync
    var lastSynced: Date? { get set }
    
    /// Whether the item has local changes that need to be synced
    var needsSync: Bool { get set }
    
    /// Whether the item has been deleted locally (for sync purposes)
    var isDeleted: Bool { get set }
    
    /// The type of sync service this item was last synced with
    var syncServiceType: SyncServiceType? { get set }
}

// MARK: - Default SyncableModel Implementation

extension SyncableModel {
    /// Mark the model as needing sync
    mutating func markForSync() {
        self.needsSync = true
        self.lastModified = Date()
    }
    
    /// Mark the model as successfully synced
    mutating func markSynced(remoteId: String, serviceType: SyncServiceType) {
        self.remoteId = remoteId
        self.lastSynced = Date()
        self.needsSync = false
        self.syncServiceType = serviceType
    }
    
    /// Mark the model as deleted for sync purposes
    mutating func markDeleted() {
        self.isDeleted = true
        self.needsSync = true
        self.lastModified = Date()
    }
}