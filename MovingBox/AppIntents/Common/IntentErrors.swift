//
//  IntentErrors.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents

enum IntentError: Swift.Error, CustomIntentError, LocalizedError {
    case itemNotFound
    case locationNotFound
    case labelNotFound
    case homeNotFound
    case insurancePolicyNotFound
    case invalidInput(String)
    case databaseError(String)
    case aiServiceError(String)
    case exportError(String)
    case cameraUnavailable
    case permissionDenied(String)
    case networkError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "The requested inventory item could not be found."
        case .locationNotFound:
            return "The requested location could not be found."
        case .labelNotFound:
            return "The requested label could not be found."
        case .homeNotFound:
            return "Home details could not be found."
        case .insurancePolicyNotFound:
            return "Insurance policy could not be found."
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .aiServiceError(let message):
            return "AI service error: \(message)"
        case .exportError(let message):
            return "Export error: \(message)"
        case .cameraUnavailable:
            return "Camera is not available on this device."
        case .permissionDenied(let permission):
            return "Permission denied for \(permission). Please check your app settings."
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknownError(let message):
            return "An unknown error occurred: \(message)"
        }
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(self.errorDescription ?? "Unknown Error")")
    }
}