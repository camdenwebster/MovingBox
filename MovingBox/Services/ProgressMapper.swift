//
//  ProgressMapper.swift
//  MovingBox
//
//  Created by Camden Webster on 11/10/25.
//

import Foundation
import SwiftData

/// Maps raw progress events to normalized 0-1 progress values
struct ProgressMapper {
    /// Progress weight configuration for export operations
    ///
    /// These weights determine how much of the total progress bar each phase occupies:
    /// - Data Fetching: 30% (0.00-0.30) - Batched fetching from SwiftData
    /// - CSV Writing: 20% (0.30-0.50) - Fast, typically <1s
    /// - Photo Copying: 30% (0.50-0.80) - Longest phase, scales with photo count
    /// - Archiving: 20% (0.80-1.00) - Scales with total data size
    struct ExportWeights {
        static let dataFetching: Double = 0.30
        static let csvWriting: Double = 0.20
        static let photoCopying: Double = 0.30
        static let archiving: Double = 0.20
    }
    
    /// Progress weight configuration for import operations
    ///
    /// These weights determine how much of the total progress bar each phase occupies:
    /// - Unzipping: 20% (0.00-0.20) - Extracting archive
    /// - Reading CSV: 20% (0.20-0.40) - Parsing CSV files
    /// - Processing Data: 40% (0.40-0.80) - Creating SwiftData objects
    /// - Copying Photos: 20% (0.80-1.00) - Copying image files
    struct ImportWeights {
        static let unzipping: Double = 0.20
        static let readingCSV: Double = 0.20
        static let processingData: Double = 0.40
        static let copyingPhotos: Double = 0.20
    }
    
    /// Maps export progress to 0-1 range with human-readable phase description
    ///
    /// - Parameter progress: The raw export progress event
    /// - Returns: A tuple containing normalized progress (0-1) and phase description
    static func mapExportProgress(_ progress: DataManager.ExportProgress) -> (progress: Double, phase: String) {
        switch progress {
        case .preparing:
            return (0.0, "Preparing export...")
            
        case .fetchingData(let phase, let progressValue):
            return (
                progressValue * ExportWeights.dataFetching,
                "Fetching \(phase)..."
            )
            
        case .writingCSV(let progressValue):
            return (
                ExportWeights.dataFetching + (progressValue * ExportWeights.csvWriting),
                "Writing CSV files..."
            )
            
        case .copyingPhotos(let current, let total):
            let photoProgress = total > 0 ? Double(current) / Double(total) : 0.0
            let baseProgress = ExportWeights.dataFetching + ExportWeights.csvWriting
            return (
                baseProgress + (photoProgress * ExportWeights.photoCopying),
                "Copying photos (\(current)/\(total))..."
            )
            
        case .creatingArchive(let progressValue):
            let baseProgress = ExportWeights.dataFetching + ExportWeights.csvWriting + ExportWeights.photoCopying
            return (
                baseProgress + (progressValue * ExportWeights.archiving),
                "Creating archive..."
            )
            
        case .completed, .error:
            return (1.0, "")
        }
    }
    
    /// Maps import progress to 0-1 range with human-readable phase description
    ///
    /// - Parameter progress: The raw import progress event
    /// - Returns: A tuple containing normalized progress (0-1) and phase description
    static func mapImportProgress(_ progress: DataManager.ImportProgress) -> (progress: Double, phase: String) {
        switch progress {
        case .progress(let value):
            return (value, "Importing data...")
            
        case .completed:
            return (1.0, "")
            
        case .error:
            return (0.0, "")
        }
    }
    
    /// Determines photo progress reporting threshold based on total count
    ///
    /// Adaptive thresholds provide optimal UX by reducing update frequency for large photo sets:
    /// - Small exports (< 50 photos): Report every photo
    /// - Medium exports (50-200 photos): Report every 5 photos
    /// - Large exports (> 200 photos): Report every 10 photos
    ///
    /// - Parameter totalPhotos: The total number of photos to copy
    /// - Returns: The number of photos to process before reporting progress
    static func photoProgressThreshold(for totalPhotos: Int) -> Int {
        switch totalPhotos {
        case 0..<50:
            return 1
        case 50..<200:
            return 5
        default:
            return 10
        }
    }
}
