import Testing
import UIKit
import Foundation
import SwiftData

@testable import MovingBox

@MainActor
@Suite struct OpenAIServiceTests {
    
    func createTestService() async throws -> OpenAIService {
        let testImage = UIImage(systemName: "photo")!
        let imageData = testImage.pngData()!
        let base64String = imageData.base64EncodedString()
        
        let settings = SettingsManager()
        settings.apiKey = "test_key_123"
        settings.aiModel = "gpt-4o-mini"
        settings.maxTokens = 150
        settings.isHighDetail = false
        
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, configurations: config)
        let context = ModelContext(container)
        
        let service = OpenAIService(imageBase64: base64String, settings: settings, modelContext: context)
        return service
    }
    
    @Test("Test URL request generation")
    func testURLRequestGeneration() async throws {
        // Given
        let service = try await createTestService()
        
        // When
        let request = try service.generateURLRequest(httpMethod: .post)
        
        // Then
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://7mc060nx64.execute-api.us-east-2.amazonaws.com/prod/v1/chat/completions")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpBody != nil)
    }
    
    @Test("Test response parsing")
    func testResponseParsing() async throws {
        // Given
        let mockResponse = """
        {
            "choices": [{
                "message": {
                    "function_call": {
                        "name": "process_inventory_item",
                        "arguments": "{\\"title\\":\\"Test Item\\",\\"quantity\\":\\"1\\",\\"description\\":\\"A test item\\",\\"make\\":\\"TestMake\\",\\"model\\":\\"TestModel\\",\\"category\\":\\"None\\",\\"location\\":\\"None\\",\\"price\\":\\"$99.99\\",\\"serialNumber\\":\\"SN123456\\"}"
                    }
                }
            }]
        }
        """
        
        let data = mockResponse.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GPTResponse.self, from: data)
        let functionCallArgs = decoded.choices[0].message.function_call?.arguments ?? ""
        let details = try JSONDecoder().decode(ImageDetails.self, from: functionCallArgs.data(using: .utf8)!)
        
        // Then
        #expect(details.title == "Test Item")
        #expect(details.quantity == "1")
        #expect(details.make == "TestMake")
        #expect(details.model == "TestModel")
        #expect(details.category == "None")
        #expect(details.location == "None")
        #expect(details.price == "$99.99")
        #expect(details.serialNumber == "SN123456")
    }
    
    @Test("Test complete integration flow")
    func testCompleteIntegrationFlow() async throws {
        // Given
        let service = try await createTestService()
        
        // When
        let request = try service.generateURLRequest(httpMethod: .post)
        
        // Then
        #expect(request.httpBody != nil)
        if let body = request.httpBody {
            let decoder = JSONDecoder()
            let payload = try decoder.decode(GPTPayload.self, from: body)
            
            // Verify payload structure
            #expect(payload.model == "gpt-4o-mini")
            #expect(payload.max_tokens == 150)
            #expect(payload.messages.count == 1)
            #expect(payload.messages[0].role == "user")
            #expect(payload.messages[0].content.count == 2)
            #expect(payload.functions.count == 1)
            #expect(payload.function_call["name"] == "process_inventory_item")
        }
    }
    
    @Test("Test error handling for invalid response")
    func testErrorHandlingInvalidResponse() async throws {
        // Given
        let mockResponse = "{invalid_json}"
        let data = mockResponse.data(using: .utf8)!
        
        // Then
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(GPTResponse.self, from: data)
        }
    }
    
    @Test("Test high detail mode")
    func testHighDetailMode() async throws {
        // Given
        let service = try await createTestService()
        service.settings.isHighDetail = true
        
        // When
        let request = try service.generateURLRequest(httpMethod: .post)
        
        // Then
        #expect(request.httpBody != nil)
        
        if let body = request.httpBody,
           let decoded = try? JSONDecoder().decode(GPTPayload.self, from: body),
           let imageMessage = decoded.messages[0].content.last,
           let imageUrl = imageMessage.image_url {
            
            #expect(imageMessage.type == "image_url")
            #expect(imageUrl.url.starts(with: "data:image/png:base64,"))
            #expect(imageUrl.detail == "high")
        } else {
            #expect(Bool(false), "Failed to decode request payload")
        }
    }
    
    @Test("Test invalid response data handling")
    func testInvalidResponseData() async throws {
        // Given
        let invalidData = "Invalid JSON".data(using: .utf8)!
        
        // Then
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(GPTResponse.self, from: invalidData)
        }
    }
    
    @Test("Test function call argument parsing")
    func testFunctionCallArgumentParsing() async throws {
        // Given
        let validResponse = """
        {
            "choices": [{
                "message": {
                    "function_call": {
                        "name": "process_inventory_item",
                        "arguments": "{\\"title\\":\\"Test Item\\",\\"quantity\\":\\"1\\",\\"description\\":\\"A test item\\",\\"make\\":\\"TestMake\\",\\"model\\":\\"TestModel\\",\\"category\\":\\"None\\",\\"location\\":\\"None\\",\\"price\\":\\"$99.99\\",\\"serialNumber\\":\\"SN789\\"}"
                    }
                }
            }]
        }
        """
        
        let data = validResponse.data(using: .utf8)!
        
        // When
        let response = try JSONDecoder().decode(GPTResponse.self, from: data)
        let arguments = response.choices[0].message.function_call?.arguments ?? ""
        let details = try JSONDecoder().decode(ImageDetails.self, from: arguments.data(using: .utf8)!)
        
        // Then
        #expect(details.title == "Test Item")
        #expect(details.quantity == "1")
        #expect(details.description == "A test item")
        #expect(details.make == "TestMake")
        #expect(details.model == "TestModel")
        #expect(details.category == "None")
        #expect(details.location == "None")
        #expect(details.price == "$99.99")
    }
    
    @Test("Test image encoding in request")
    func testImageEncoding() async throws {
        // Given
        let service = try await createTestService()
        
        // When
        let request = try service.generateURLRequest(httpMethod: .post)
        
        // Then
        #expect(request.httpBody != nil)
        
        if let body = request.httpBody,
           let decoded = try? JSONDecoder().decode(GPTPayload.self, from: body),
           let imageMessage = decoded.messages[0].content.last,
           let imageUrl = imageMessage.image_url {
            
            #expect(imageMessage.type == "image_url")
            let startsWithBase64 = imageUrl.url.starts(with: "data:image/png:base64,")
            #expect(startsWithBase64)
            #expect(imageUrl.detail == "low") // Based on default settings
        } else {
            #expect(Bool(false), "Failed to decode request payload")
        }
    }
}
