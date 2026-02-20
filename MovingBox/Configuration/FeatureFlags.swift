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
    /// Controls per-home sharing/scoping UI and behavior.
    /// - Default: disabled in all distributions.
    /// - Debug/Test override: launch argument `Enable-Family-Sharing-Scoping`.
    public let familySharingScopingEnabled: Bool

    /// Initialize feature flags based on distribution type
    /// - Parameter distribution: The current app distribution
    public init(distribution: Distribution) {
        self.init(
            distribution: distribution,
            launchArguments: ProcessInfo.processInfo.arguments
        )
    }

    init(distribution: Distribution, launchArguments: [String]) {
        let forceScopingEnabled = launchArguments.contains("Enable-Family-Sharing-Scoping")

        switch distribution {
        case .debug:
            // In debug builds, zoom is disabled by default but available for testing
            self.showZoomControl = true
            self.familySharingScopingEnabled = forceScopingEnabled
        case .beta:
            // In beta/TestFlight builds, zoom is disabled by default but available for testing
            self.showZoomControl = false
            self.familySharingScopingEnabled = forceScopingEnabled
        case .appstore:
            // In production builds, zoom is always disabled
            self.showZoomControl = false
            self.familySharingScopingEnabled = false
        }
    }

    /// Internal initializer for testing with specific values
    init(showZoomControl: Bool, familySharingScopingEnabled: Bool = false) {
        self.showZoomControl = showZoomControl
        self.familySharingScopingEnabled = familySharingScopingEnabled
    }
}

// MARK: - SwiftUI Environment Integration

extension EnvironmentValues {
    @Entry public var featureFlags = FeatureFlags(distribution: .current)
}
