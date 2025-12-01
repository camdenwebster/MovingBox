import Foundation
import SwiftUI

// MARK: - Distribution Type

/// Represents the current distribution type of the app
public enum Distribution: Sendable {
    case debug
    case beta
    case appstore
}

extension Distribution {
    /// Gets the current distribution based on compilation conditions
    static var current: Self {
        #if BETA
        return .beta
        #elseif DEBUG
        return .debug
        #else
        return .appstore
        #endif
    }
}

// MARK: - Feature Flags

/// Centralized feature flag configuration
public struct FeatureFlags: Sendable {
    /// Show the zoom control UI in the camera
    /// - Debug: disabled by default (can be toggled via debug menu)
    /// - Beta/TestFlight: disabled by default (can be toggled via debug menu)
    /// - Production: always disabled
    public let showZoomControl: Bool

    /// Initialize feature flags based on distribution type
    /// - Parameter distribution: The current app distribution
    public init(distribution: Distribution) {
        switch distribution {
        case .debug:
            // In debug builds, zoom is disabled by default but available for testing
            self.showZoomControl = false
        case .beta:
            // In beta/TestFlight builds, zoom is disabled by default but available for testing
            self.showZoomControl = false
        case .appstore:
            // In production builds, zoom is always disabled
            self.showZoomControl = false
        }
    }

    /// Internal initializer for testing with specific values
    init(showZoomControl: Bool) {
        self.showZoomControl = showZoomControl
    }
}

// MARK: - SwiftUI Environment Integration

extension EnvironmentValues {
    @Entry public var featureFlags = FeatureFlags(distribution: .current)
}
