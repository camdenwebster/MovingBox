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
    
    // Check environment variables without crashing
    private static func checkEnvironmentVariable(_ key: String) -> String? {
        // First check environment variables (CI/TestFlight)
        if let envValue = ProcessInfo.processInfo.environment[key] {
            return envValue
        }
        
        // Then check plist (local development)
        let bundle = Bundle.main
        guard let path = bundle.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let value = config[key] as? String else {
            return nil
        }
        
        return value
    }
    
    static func value(for key: String) -> String? {
        _ = environmentChecks
        
        #if DEBUG
        print("🔐 Attempting to read key: \(key)")
        #endif
        
        return checkEnvironmentVariable(key)
    }
    
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
        print("⚠️ JWT_SECRET not found in bundle or Config.plist")
        return "debug-secret-key"
        #else
        return "missing-jwt-secret"
        #endif
    }
}
