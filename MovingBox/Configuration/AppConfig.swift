import Foundation

enum AppConfig {
    enum Keys {
        static let jwtSecret = "JWT_SECRET"
    }
    
    static func value(for key: String) -> String? {
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
