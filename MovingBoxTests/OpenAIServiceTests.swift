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
                    "tool_calls": [
                        {
                            "id": "call_123",
                            "type": "function",
                            "function": {
                                "name": "process_inventory_item",
                                "arguments": "{\\"title\\":\\"Test Item\\",\\"quantity\\":\\"1\\",\\"description\\":\\"A test item\\",\\"make\\":\\"TestMake\\",\\"model\\":\\"TestModel\\",\\"category\\":\\"None\\",\\"location\\":\\"None\\",\\"price\\":\\"$99.99\\",\\"serialNumber\\":\\"SN123456\\"}"
                            }
                        }
                    ]
                }
            }]
        }
        """
        
        let data = mockResponse.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GPTResponse.self, from: data)
        let functionCallArgs = decoded.choices[0].message.tool_calls?[0].function.arguments ?? ""
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
            #expect(payload.model == "gpt-4o")
            #expect(payload.max_completion_tokens == 150)
            #expect(payload.messages.count == 1)
            #expect(payload.messages[0].role == "user")
            #expect(payload.messages[0].content.count == 2)
            #expect(payload.tools.count == 1)
            #expect(payload.tool_choice.function.name == "process_inventory_item")
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
        
        // Set both isPro and highQualityAnalysisEnabled to enable high detail mode on main actor
        await MainActor.run {
            service.settings.isPro = true
            service.settings.highQualityAnalysisEnabled = true
        }
        
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
                    "tool_calls": [
                        {
                            "id": "call_456",
                            "type": "function",
                            "function": {
                                "name": "process_inventory_item",
                                "arguments": "{\\"title\\":\\"Test Item\\",\\"quantity\\":\\"1\\",\\"description\\":\\"A test item\\",\\"make\\":\\"TestMake\\",\\"model\\":\\"TestModel\\",\\"category\\":\\"None\\",\\"location\\":\\"None\\",\\"price\\":\\"$99.99\\",\\"serialNumber\\":\\"SN789\\"}"
                            }
                        }
                    ]
                }
            }]
        }
        """
        
        let data = validResponse.data(using: .utf8)!
        
        // When
        let response = try JSONDecoder().decode(GPTResponse.self, from: data)
        let arguments = response.choices[0].message.tool_calls?[0].function.arguments ?? ""
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
    
    @Test("Test extended properties configuration")
    func testExtendedPropertiesConfiguration() async throws {
        // Given
        let service = try await createTestService()
        
        // When
        let request = try service.generateURLRequest(httpMethod: .post)
        
        // Then
        #expect(request.httpBody != nil)
        
        if let body = request.httpBody,
           let decoded = try? JSONDecoder().decode(GPTPayload.self, from: body) {
            
            let properties = decoded.tools[0].function.parameters.properties
            
            // Verify core properties are present
            #expect(properties["title"] != nil)
            #expect(properties["quantity"] != nil)
            #expect(properties["description"] != nil)
            #expect(properties["make"] != nil)
            #expect(properties["model"] != nil)
            #expect(properties["category"] != nil)
            #expect(properties["location"] != nil)
            #expect(properties["price"] != nil)
            #expect(properties["serialNumber"] != nil)
            
            // Verify enabled extended properties are present
            #expect(properties["condition"] != nil)
            #expect(properties["color"] != nil)
            #expect(properties["dimensions"] != nil)
            #expect(properties["weight"] != nil)
            #expect(properties["purchaseLocation"] != nil)
            #expect(properties["replacementCost"] != nil)
            #expect(properties["storageRequirements"] != nil)
            #expect(properties["isFragile"] != nil)
            
            // Verify disabled properties are not present
            #expect(properties["dimensionLength"] == nil)
            #expect(properties["dimensionWidth"] == nil)
            #expect(properties["dimensionHeight"] == nil)
            #expect(properties["dimensionUnit"] == nil)
            #expect(properties["weightValue"] == nil)
            #expect(properties["weightUnit"] == nil)
        } else {
            #expect(Bool(false), "Failed to decode request payload")
        }
    }
    
    @Test("Test extended properties response parsing")
    func testExtendedPropertiesResponseParsing() async throws {
        // Given
        let mockResponse = """
        {
            "choices": [{
                "message": {
                    "tool_calls": [
                        {
                            "id": "call_123",
                            "type": "function",
                            "function": {
                                "name": "process_inventory_item",
                                "arguments": "{\\"title\\":\\"Test Item\\",\\"quantity\\":\\"1\\",\\"description\\":\\"A test item\\",\\"make\\":\\"TestMake\\",\\"model\\":\\"TestModel\\",\\"category\\":\\"None\\",\\"location\\":\\"None\\",\\"price\\":\\"$99.99\\",\\"serialNumber\\":\\"SN123456\\",\\"condition\\":\\"Good\\",\\"color\\":\\"Blue\\",\\"dimensions\\":\\"12 x 8 x 4 inches\\",\\"weight\\":\\"2.5 lbs\\",\\"purchaseLocation\\":\\"Best Buy\\",\\"replacementCost\\":\\"$119.99\\",\\"storageRequirements\\":\\"Keep dry\\",\\"isFragile\\":\\"false\\"}"
                            }
                        }
                    ]
                }
            }]
        }
        """
        
        let data = mockResponse.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GPTResponse.self, from: data)
        let functionCallArgs = decoded.choices[0].message.tool_calls?[0].function.arguments ?? ""
        let details = try JSONDecoder().decode(ImageDetails.self, from: functionCallArgs.data(using: .utf8)!)
        
        // Then - verify core properties
        #expect(details.title == "Test Item")
        #expect(details.quantity == "1")
        #expect(details.make == "TestMake")
        #expect(details.model == "TestModel")
        #expect(details.category == "None")
        #expect(details.location == "None")
        #expect(details.price == "$99.99")
        #expect(details.serialNumber == "SN123456")
        
        // Then - verify extended properties
        #expect(details.condition == "Good")
        #expect(details.color == "Blue")
        #expect(details.dimensions == "12 x 8 x 4 inches")
        #expect(details.weight == "2.5 lbs")
        #expect(details.purchaseLocation == "Best Buy")
        #expect(details.replacementCost == "$119.99")
        #expect(details.storageRequirements == "Keep dry")
        #expect(details.isFragile == "false")
    }
    
    @Test("Test response parsing with missing extended properties")
    func testResponseParsingWithMissingExtendedProperties() async throws {
        // Given - response with only core properties (backward compatibility)
        let mockResponse = """
        {
            "choices": [{
                "message": {
                    "tool_calls": [
                        {
                            "id": "call_123",
                            "type": "function",
                            "function": {
                                "name": "process_inventory_item",
                                "arguments": "{\\"title\\":\\"Test Item\\",\\"quantity\\":\\"1\\",\\"description\\":\\"A test item\\",\\"make\\":\\"TestMake\\",\\"model\\":\\"TestModel\\",\\"category\\":\\"None\\",\\"location\\":\\"None\\",\\"price\\":\\"$99.99\\",\\"serialNumber\\":\\"SN123456\\"}"
                            }
                        }
                    ]
                }
            }]
        }
        """
        
        let data = mockResponse.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GPTResponse.self, from: data)
        let functionCallArgs = decoded.choices[0].message.tool_calls?[0].function.arguments ?? ""
        let details = try JSONDecoder().decode(ImageDetails.self, from: functionCallArgs.data(using: .utf8)!)
        
        // Then - verify core properties work
        #expect(details.title == "Test Item")
        #expect(details.quantity == "1")
        #expect(details.price == "$99.99")
        
        // Then - verify extended properties are nil when not provided
        #expect(details.condition == nil)
        #expect(details.color == nil)
        #expect(details.dimensions == nil)
        #expect(details.weight == nil)
        #expect(details.purchaseLocation == nil)
        #expect(details.replacementCost == nil)
        #expect(details.storageRequirements == nil)
        #expect(details.isFragile == nil)
    }
    
    @Test("Test condition enum values configuration")
    func testConditionEnumValuesConfiguration() async throws {
        // Given
        let service = try await createTestService()
        
        // When
        let request = try service.generateURLRequest(httpMethod: .post)
        
        // Then
        #expect(request.httpBody != nil)
        
        if let body = request.httpBody,
           let decoded = try? JSONDecoder().decode(GPTPayload.self, from: body) {
            
            let properties = decoded.tools[0].function.parameters.properties
            let conditionProperty = properties["condition"]
            
            #expect(conditionProperty != nil)
            #expect(conditionProperty?.enum_values != nil)
            #expect(conditionProperty?.enum_values?.contains("New") == true)
            #expect(conditionProperty?.enum_values?.contains("Like New") == true)
            #expect(conditionProperty?.enum_values?.contains("Good") == true)
            #expect(conditionProperty?.enum_values?.contains("Fair") == true)
            #expect(conditionProperty?.enum_values?.contains("Poor") == true)
        } else {
            #expect(Bool(false), "Failed to decode request payload")
        }
    }
    
    @Test("Test required fields configuration")
    func testRequiredFieldsConfiguration() async throws {
        // Given
        let service = try await createTestService()
        
        // When
        let request = try service.generateURLRequest(httpMethod: .post)
        
        // Then
        #expect(request.httpBody != nil)
        
        if let body = request.httpBody,
           let decoded = try? JSONDecoder().decode(GPTPayload.self, from: body) {
            
            let required = decoded.tools[0].function.parameters.required
            
            // Verify all core properties are required
            #expect(required.contains("title"))
            #expect(required.contains("quantity"))
            #expect(required.contains("description"))
            #expect(required.contains("make"))
            #expect(required.contains("model"))
            #expect(required.contains("category"))
            #expect(required.contains("location"))
            #expect(required.contains("price"))
            #expect(required.contains("serialNumber"))
            
            // Verify extended properties are not required
            #expect(!required.contains("condition"))
            #expect(!required.contains("color"))
            #expect(!required.contains("dimensions"))
            #expect(!required.contains("weight"))
        } else {
            #expect(Bool(false), "Failed to decode request payload")
        }
    }
}
