import Foundation
import CryptoKit

class JWTManager {
    static let shared = JWTManager()
    
    private var secret: String {
        AppConfig.jwtSecret
    }
    
    func generateToken() -> String {
        let header = ["alg": "HS256", "typ": "JWT"]
        let payload = [
            "iss": "moving-box-app",
            "iat": Date().timeIntervalSince1970,
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970 // 1 hour expiration
        ] as [String : Any]
        
        let headerString = base64UrlEncode(try! JSONSerialization.data(withJSONObject: header))
        let payloadString = base64UrlEncode(try! JSONSerialization.data(withJSONObject: payload))
        
        let toSign = "\(headerString).\(payloadString)"
        let signature = generateSignature(for: toSign)
        
        return "\(toSign).\(signature)"
    }
    
    private func generateSignature(for message: String) -> String {
        let key = SymmetricKey(data: secret.data(using: .utf8)!)
        let signature = HMAC<SHA256>.authenticationCode(for: message.data(using: .utf8)!, using: key)
        return base64UrlEncode(Data(signature))
    }
    
    private func base64UrlEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
