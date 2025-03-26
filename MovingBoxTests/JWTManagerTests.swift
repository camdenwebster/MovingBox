import Testing
import Foundation
@testable import MovingBox
import CryptoKit

struct JWTManagerTests {
    var jwtManager: JWTManager!
    
    init() {
        jwtManager = JWTManager.shared
    }
    
    @Test("Token generation follows JWT format")
    func tokenHasValidFormat() {
        // When
        let token = jwtManager.generateToken()
        let components = token.components(separatedBy: ".")
        
        // Then
        #expect(components.count == 3, "JWT should have three components separated by dots")
        
        // Verify each component is base64URL encoded
        components.forEach { component in
            #expect(!component.contains("+"), "Component should not contain '+'")
            #expect(!component.contains("/"), "Component should not contain '/'")
            #expect(!component.contains("="), "Component should not contain '='")
        }
    }
    
    @Test("Token header contains valid algorithm and type")
    func tokenHasValidHeader() throws {
        // When
        let token = jwtManager.generateToken()
        let components = token.components(separatedBy: ".")
        let paddedHeader = components[0].padding(toLength: ((components[0].count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        
        // Then
        guard let headerData = Data(base64Encoded: paddedHeader) else {
            Issue.record("Could not decode header")
            return
        }
        
        guard let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: String] else {
            Issue.record("Could not parse header JSON")
            return
        }
        
        #expect(header["alg"] == "HS256", "Algorithm should be HS256")
        #expect(header["typ"] == "JWT", "Type should be JWT")
    }
    
    @Test("Token payload contains required claims")
    func tokenHasValidPayload() throws {
        // When
        let token = jwtManager.generateToken()
        let components = token.components(separatedBy: ".")
        let paddedPayload = components[1].padding(toLength: ((components[1].count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        
        // Then
        guard let payloadData = Data(base64Encoded: paddedPayload) else {
            Issue.record("Could not decode payload")
            return
        }
        
        guard let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            Issue.record("Could not parse payload JSON")
            return
        }
        
        #expect(payload["iss"] as? String == "moving-box-app", "Issuer should be moving-box-app")
        
        guard let exp = payload["exp"] as? Double else {
            Issue.record("Expiration time missing")
            return
        }
        
        guard let iat = payload["iat"] as? Double else {
            Issue.record("Issued at time missing")
            return
        }
        
        #expect(abs((exp - iat) - 3600) < 1, "Expiration should be 1 hour after issued at time")
    }
    
    @Test("Generated tokens are unique")
    func tokensAreUnique() {
        // When
        let token1 = jwtManager.generateToken()
        let token2 = jwtManager.generateToken()
        
        // Then
        #expect(token1 != token2, "Generated tokens should be unique")
    }
    
    @Test("Token signature can be verified")
    func signatureIsValid() throws {
        // When
        let token = jwtManager.generateToken()
        let components = token.components(separatedBy: ".")
        
        // Then
        #expect(components.count == 3, "Token should have three components")
        
        let toSign = "\(components[0]).\(components[1])"
        let key = SymmetricKey(data: AppConfig.jwtSecret.data(using: .utf8)!)
        let expectedSignature = HMAC<SHA256>.authenticationCode(
            for: toSign.data(using: .utf8)!,
            using: key
        )
        
        let paddedSignature = components[2].padding(toLength: ((components[2].count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        
        // Convert base64url to base64 standard
        let standardBase64 = paddedSignature
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        guard let actualSignatureData = Data(base64Encoded: standardBase64) else {
            #expect(Bool(false), "Could not decode signature from base64")
            return
        }
        
        #expect(Data(expectedSignature) == actualSignatureData, "Signature should be valid")
    }
}
