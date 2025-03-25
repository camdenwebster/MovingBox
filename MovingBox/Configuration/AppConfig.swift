import Foundation

enum AppConfig {
    enum Keys {
        static let jwtSecret = "JWT_SECRET"
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
