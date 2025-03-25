import Foundation

enum AppConfig {
    enum Keys {
        static let jwtSecret = "JWT_SECRET"
    }
    
    static func value(for key: String) -> String? {
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
            fatalError("JWT_SECRET not found in Config.plist")
        }
        return secret
    }
}
