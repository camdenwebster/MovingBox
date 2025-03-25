import Foundation

enum AppConfig {
    enum Keys {
        static let jwtSecret = "JWT_SECRET"
    }
    
    // Check environment at build time
    static let environmentChecks: Void = {
        #if DEBUG
        // Debug: Print all environment variables to help with troubleshooting
        print("📋 All Environment Variables:")
        ProcessInfo.processInfo.environment.forEach { key, value in
            print("   \(key): \(String(value.prefix(4)))...")
        }
        #endif
        
        let missingKeys = [Keys.jwtSecret].filter { key in
            let envValue = ProcessInfo.processInfo.environment[key]
            let bundle = Bundle.main
            
            #if DEBUG
            print("🔍 Checking \(key):")
            print("   Environment value: \(envValue != nil ? "Found" : "Not found")")
            
            // Check plist status
            if let path = bundle.path(forResource: "Config", ofType: "plist"),
               let config = NSDictionary(contentsOfFile: path) {
                print("   Plist value: \(config[key] != nil ? "Found" : "Not found")")
            } else {
                print("   Plist status: Not found or couldn't be read")
            }
            #endif
            
            if envValue != nil { return false }
            
            // Check plist if not in environment
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
        }
        #endif
    }()
    
    static func value(for key: String) -> String? {
        _ = environmentChecks
        
        #if DEBUG
        print("🔐 Attempting to read key: \(key)")
        #endif
        
        // First check if we're running in CI environment
        if let ciValue = ProcessInfo.processInfo.environment[key] {
            #if DEBUG
            print("📦 Found value in environment variables for key: \(key)")
            #endif
            return ciValue
        }
        
        #if DEBUG
        print("🔍 Environment variable not found, checking plist...")
        #endif
        
        // If not in CI, check local plist
        let bundle = Bundle.main
        guard let path = bundle.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let value = config[key] as? String else {
            #if DEBUG
            print("⚠️ No value found in plist for key: \(key)")
            #endif
            return nil
        }
        
        #if DEBUG
        print("📄 Found value in plist for key: \(key)")
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
