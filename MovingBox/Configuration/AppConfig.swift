import Foundation
import UIKit

enum BuildType {
    case production
    case beta
}

enum BuildConfiguration {
    case debug
    case release
}

struct AppConfig {
    static let shared = AppConfig()

    let buildType: BuildType
    let configuration: BuildConfiguration

    private(set) var isPro: Bool

    private init() {
        #if BETA
            buildType = .beta
        #else
            buildType = .production
        #endif

        #if DEBUG
            configuration = .debug
        #else
            configuration = .release
        #endif

        // Pro features enabled for:
        // 1. All beta builds
        // 2. When "Is-Pro" launch argument is present (DEBUG only)
        isPro = buildType == .beta
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("Is-Pro") {
                // Set UserDefaults for isPro
                UserDefaults.standard.set(true, forKey: "isPro")
            }
        #endif
    }

    var isDebugLoggingEnabled: Bool {
        // Enable debug logging for both debug builds and beta-release builds
        configuration == .debug || buildType == .beta
    }

    enum Keys {
        static let jwtSecret = "JWT_SECRET"
        static let revenueCatAPIKey = "REVENUE_CAT_API_KEY"
        static let sentryDsn = "SENTRY_DSN"
        static let telemetryDeckAppId = "TELEMETRY_DECK_APP_ID"
        static let wishKitAPIKey = "WISHKIT_API_KEY"
    }

    private static func checkBundleVariable(_ key: String) -> String? {
        // Check Info.plist first
        if let infoValue = Bundle.main.object(forInfoDictionaryKey: key) as? String, !infoValue.isEmpty {
            return infoValue
        }

        // Check xcconfig values via main bundle
        if let configValue = Bundle.main.infoDictionary?[key] as? String, !configValue.isEmpty {
            return configValue
        }

        // Check Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
            let config = NSDictionary(contentsOfFile: path),
            let value = config[key] as? String,
            !value.isEmpty
        {
            return value
        }

        #if DEBUG
            // Finally check environment
            if let envValue = ProcessInfo.processInfo.environment[key], !envValue.isEmpty {
                return envValue
            }
        #endif

        return nil
    }

    static var jwtSecret: String {
        if let secret = checkBundleVariable(Keys.jwtSecret) {
            return secret
        }
        return "missing-jwt-secret"
    }

    static var revenueCatAPIKey: String {
        if let key = checkBundleVariable(Keys.revenueCatAPIKey) {
            return key
        }
        return "missing-rc-api-key"
    }

    static var sentryDsn: String {
        // Check for debug override first
        #if DEBUG
            if let debugDsn = ProcessInfo.processInfo.environment["SENTRY_DSN_DEBUG"] {
                return debugDsn
            }
        #endif

        if let dsn = checkBundleVariable(Keys.sentryDsn) {
            return dsn
        }

        #if DEBUG
            print("⚠️ Warning: Using fallback Sentry DSN")
        #endif
        return "missing-sentry-dsn"
    }

    static var telemetryDeckAppId: String {
        if let appId = checkBundleVariable(Keys.telemetryDeckAppId) {
            return appId
        }
        return "missing-telemetrydeck-app-id"
    }

    static var wishKitAPIKey: String {
        if let key = checkBundleVariable(Keys.wishKitAPIKey) {
            return key
        }
        return "missing-wishkit-api-key"
    }
}
