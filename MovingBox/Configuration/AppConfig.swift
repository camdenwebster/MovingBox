import Foundation

enum AppConfig {
    enum Keys {
        static let jwtSecret = "JWT_SECRET"
    }
    
    // ADD: Static initializer to check environment at build time
    static let environmentChecks: Void = {
        #if DEBUG
        // Check environment variables
        let missingKeys = [Keys.jwtSecret].filter { key in
            let envValue = ProcessInfo.processInfo.environment[key]
            if envValue != nil { return false }
            
            // Check plist if not in environment
            let bundle = Bundle.main
            guard let path = bundle.path(forResource: "Config", ofType: "plist"),
                  let config = NSDictionary(contentsOfFile: path),
                  config[key] != nil else {
                return true
            }
            return false
        }
        
        if !missingKeys.isEmpty {
            print("⚠️ WARNING: Missing configuration for keys: \(missingKeys.joined(separator: ", "))")
            print("💡 Ensure these keys are either:")
            print("   1. Set in Config.plist for local development")
            print("   2. Set as environment variables for CI")
        }
        #endif
    }()
    
    static func value(for key: String) -> String? {
        // Trigger environment check at first use
        _ = environmentChecks
        
        // First check if we're running in CI environment
        if let ciValue = ProcessInfo.processInfo.environment[key] {
            return ciValue
        }
        
        // If not in CI, check local plist
        let bundle = Bundle.main
        guard let path = bundle.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let value = config[key] as? String else {
            #if DEBUG
            print("⚠️ No value found for key: \(key)")
            #endif
            return nil
        }
        return value
    }
    
    static var jwtSecret: String {
        guard let secret = value(for: Keys.jwtSecret) else {
            fatalError("JWT_SECRET not found in Config.plist or Environment Variables")
        }
        return secret
    }
}
