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
        // 2. When "UI-Testing-Pro" launch argument is present (DEBUG only)
        isPro = buildType == .beta
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UI-Testing-Pro") {
            isPro = true
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
    }
    
    // ADD: RevenueCat API key
    static let revenueCatAPIKey: String = {
        guard let key = Bundle.main.infoDictionary?["REVENUE_CAT_API_KEY"] as? String else {
            fatalError("RevenueCat API key not found in configuration")
        }
        return key
    }()
    
    private static func checkBundleVariable(_ key: String) -> String? {
        // Check Info.plist first (for runtime values injected during build)
        if let infoValue = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return infoValue
        }
        
        // Then check Config.plist (for development)
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let value = config[key] as? String {
            return value
        }
        
        #if DEBUG
        // Finally check environment (for local testing)
        return ProcessInfo.processInfo.environment[key]
        #else
        return nil
        #endif
    }
    
    static var jwtSecret: String {
        if let secret = checkBundleVariable(Keys.jwtSecret) {
            return secret
        }
        
        #if DEBUG
        print(" JWT_SECRET not found in bundle or Config.plist")
        return "debug-secret-key"
        #else
        return "missing-jwt-secret"
        #endif
    }
}
