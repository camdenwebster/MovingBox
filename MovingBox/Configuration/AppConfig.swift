import Foundation

enum AppConfig {
    enum Keys {
        static let jwtSecret = "JWT_SECRET"
    }
    
    // Check environment at build time, but only show warnings in Debug
    static let environmentChecks: Void = {
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
        
        #if DEBUG
        if !missingKeys.isEmpty {
            print("⚠️ WARNING: Missing configuration for keys: \(missingKeys.joined(separator: ", "))")
            print("💡 Ensure these keys are either:")
            print("   1. Set in Config.plist for local development")
            print("   2. Set as environment variables for CI")
        }
        #endif
        
        // In Release, fail fast if we're missing required configuration
        #if !DEBUG
        if !missingKeys.isEmpty {
            fatalError("Missing required configuration keys: \(missingKeys.joined(separator: ", "))")
        }
        #endif
    }()
    
    static func value(for key: String) -> String? {
        // Always trigger environment check at first use, regardless of build configuration
        _ = environmentChecks
        
        // First check if we're running in CI environment
        if let ciValue = ProcessInfo.processInfo.environment[key] {
            #if DEBUG
            print("📦 Using environment variable for key: \(key)")
            #endif
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
        
        #if DEBUG
        print("📄 Using plist value for key: \(key)")
        #endif
        return value
    }
    
    static var jwtSecret: String {
        guard let secret = value(for: Keys.jwtSecret) else {
            fatalError("JWT_SECRET not found in Config.plist or Environment Variables")
        }
        return secret
    }
}
