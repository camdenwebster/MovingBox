//
//  SyncableProtocol.swift
//  MovingBox
//
//  Created by Camden Webster on 6/22/25.
//

import Foundation
import SwiftData

// MARK: - Syncable Protocol

/// Protocol for models that can be synchronized across different sync services
protocol Syncable {
    /// Remote identifier assigned by the sync service
    var remoteId: String? { get set }
    
    /// Timestamp when the model was last modified locally
    var lastModified: Date { get set }
    
    /// Timestamp when the model was last successfully synced
    var lastSynced: Date? { get set }
    
    /// Flag indicating if the model has local changes that need to be synced
    var needsSync: Bool { get set }
    
    /// Flag indicating if the model has been deleted locally
    var isDeleted: Bool { get set }
    
    /// The type of sync service this model was last synced with
    var syncServiceType: SyncServiceType? { get set }
    
    /// Version number for conflict resolution (incremented on each change)
    var version: Int { get set }
}

// MARK: - Default Implementations

extension Syncable {
    /// Mark the model as needing synchronization
    mutating func markForSync() {
        self.needsSync = true
        self.lastModified = Date()
        self.version += 1
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
        self.version += 1
    }
    
    /// Check if the model needs to be synced
    var requiresSync: Bool {
        return needsSync && !isDeleted
    }
    
    /// Check if the model is pending deletion sync
    var pendingDeletion: Bool {
        return isDeleted && needsSync
    }
    
    /// Check if the model has ever been synced
    var hasBeenSynced: Bool {
        return remoteId != nil && lastSynced != nil
    }
    
    /// Get the time since last sync
    var timeSinceLastSync: TimeInterval? {
        guard let lastSynced = lastSynced else { return nil }
        return Date().timeIntervalSince(lastSynced)
    }
}

// MARK: - Sync Conflict Resolution

/// Represents a conflict between local and remote versions of a model
struct SyncConflict<T: Syncable> {
    let localVersion: T
    let remoteVersion: T
    let conflictType: ConflictType
    
    enum ConflictType {
        case bothModified
        case localDeletedRemoteModified
        case localModifiedRemoteDeleted
    }
}

/// Strategy for resolving sync conflicts
enum ConflictResolutionStrategy {
    case lastWriteWins
    case localWins
    case remoteWins
    case manual
}

/// Result of conflict resolution
enum ConflictResolution<T: Syncable> {
    case useLocal(T)
    case useRemote(T)
    case merged(T)
    case requiresManualResolution
}

// MARK: - Sync Metadata Helper

/// Helper struct for managing sync metadata
struct SyncMetadata {
    let remoteId: String?
    let lastModified: Date
    let lastSynced: Date?
    let needsSync: Bool
    let isDeleted: Bool
    let syncServiceType: SyncServiceType?
    let version: Int
    
    init<T: Syncable>(from model: T) {
        self.remoteId = model.remoteId
        self.lastModified = model.lastModified
        self.lastSynced = model.lastSynced
        self.needsSync = model.needsSync
        self.isDeleted = model.isDeleted
        self.syncServiceType = model.syncServiceType
        self.version = model.version
    }
}

// MARK: - Sync Change Tracking

/// Tracks the type of change for sync purposes
enum SyncChangeType: String, CaseIterable {
    case created
    case updated
    case deleted
    
    var description: String {
        switch self {
        case .created:
            return "Created"
        case .updated:
            return "Updated"
        case .deleted:
            return "Deleted"
        }
    }
}

/// Represents a change that needs to be synced
struct SyncChange<T: Syncable> {
    let model: T
    let changeType: SyncChangeType
    let timestamp: Date
    let syncServiceType: SyncServiceType
    
    init(model: T, changeType: SyncChangeType, serviceType: SyncServiceType) {
        self.model = model
        self.changeType = changeType
        self.timestamp = Date()
        self.syncServiceType = serviceType
    }
}

// MARK: - Sync Statistics

/// Statistics about sync operations
struct SyncStatistics {
    let totalItems: Int
    let itemsCreated: Int
    let itemsUpdated: Int
    let itemsDeleted: Int
    let conflicts: Int
    let errors: Int
    let startTime: Date
    let endTime: Date
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    var successRate: Double {
        let successfulItems = itemsCreated + itemsUpdated + itemsDeleted
        return totalItems > 0 ? Double(successfulItems) / Double(totalItems) : 0.0
    }
}