//
//  BaseIntent.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents
import SwiftData

/// Base protocol for all MovingBox App Intents
protocol MovingBoxIntent: AppIntent {
    associatedtype PerformResult
}

/// Base class for intents that need data access
@available(iOS 16.0, *)
class BaseDataIntent {
    
    /// Shared model container for all intents
    static var sharedContainer: ModelContainer = {
        do {
            // Use the same configuration as the main app
            let configuration = ModelConfiguration("MovingBoxModel")
            return try ModelContainer(
                for: InventoryItem.self, 
                InventoryLocation.self, 
                InventoryLabel.self, 
                Home.self, 
                InsurancePolicy.self,
                configurations: configuration
            )
        } catch {
            // Fallback to in-memory container for testing/error cases
            do {
                return try ModelContainer(
                    for: InventoryItem.self, 
                    InventoryLocation.self, 
                    InventoryLabel.self, 
                    Home.self, 
                    InsurancePolicy.self
                )
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }()
    
    /// Create a new model context for background operations
    func createBackgroundContext() -> ModelContext {
        let context = ModelContext(Self.sharedContainer)
        return context
    }
    
    /// Execute a database operation safely with error handling
    func executeDataOperation<T>(_ operation: (ModelContext) throws -> T) async throws -> T {
        let context = createBackgroundContext()
        
        do {
            let result = try operation(context)
            try context.save()
            return result
        } catch {
            throw IntentError.databaseError(error.localizedDescription)
        }
    }
    
    /// Log intent execution for analytics
    func logIntentExecution(_ intentName: String, parameters: [String: Any] = [:]) {
        // Integration with existing TelemetryManager
        print("📱 App Intent executed: \(intentName) with parameters: \(parameters)")
        // TODO: Integrate with TelemetryManager.shared once available in intent context
    }
}

/// Standard success response for data modification intents
struct StandardSuccessResult: Sendable {
    let message: String
    let openInApp: Bool
    
    init(message: String, openInApp: Bool = false) {
        self.message = message
        self.openInApp = openInApp
    }
}

/// Response wrapper for intents that can optionally open the app
struct IntentResultWithAppOption<T: Sendable>: Sendable {
    let result: T
    let openInApp: Bool
    
    init(result: T, openInApp: Bool = false) {
        self.result = result
        self.openInApp = openInApp
    }
}