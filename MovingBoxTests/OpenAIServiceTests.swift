import Testing
import UIKit
import Foundation
import SwiftData

@testable import MovingBox

@Suite struct OpenAIServiceTests {
    // Helper function to create a test service
    func createTestService() -> OpenAIService {
        let testImage = UIImage(systemName: "photo")!
        let imageData = testImage.pngData()!
        let base64String = imageData.base64EncodedString()
        let settings = SettingsManager()
        settings.apiKey = "test_key_123"
        settings.aiModel = "gpt-4o-mini"
        settings.maxTokens = 150
        settings.isHighDetail = false
        
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: InventoryItem.self, configurations: config)
        let context = ModelContext(container)
        
        return OpenAIService(imageBase64: base64String, settings: settings, modelContext: context)
    }
    
    @Test("Test URL request generation")
    func testURLRequestGeneration() async throws {
        // Given
        let service = createTestService()
        
        // When
        let request = try await MainActor.run {
            try service.generateURLRequest(httpMethod: .post)
        }
        
        // Then
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test_key_123")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpBody != nil)
    }
    
    @Test("Test empty API key handling")
    func testEmptyAPIKey() async throws {
        // Given
        let service = createTestService()
        service.settings.apiKey = ""
        
        // Then
        await #expect(throws: OpenAIError.invalidResponse) {
            try await MainActor.run {
                try service.generateURLRequest(httpMethod: .post)
            }
        }
    }
    
    @Test("Test response parsing")
    func testResponseParsing() async throws {
        // Given
        let mockResponse = "{\"choices\":[{\"message\":{\"function_call\":{\"name\":\"process_inventory_item\",\"arguments\":\"{\\\"title\\\":\\\"Test Item\\\",\\\"quantity\\\":\\\"1\\\",\\\"description\\\":\\\"A test item\\\",\\\"make\\\":\\\"TestMake\\\",\\\"model\\\":\\\"TestModel\\\",\\\"category\\\":\\\"None\\\",\\\"location\\\":\\\"None\\\",\\\"price\\\":\\\"$99.99\\\"}\"}}}]}"
        
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
}
