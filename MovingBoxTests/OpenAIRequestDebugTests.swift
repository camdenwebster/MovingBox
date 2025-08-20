import Testing
import SwiftData
import UIKit
@testable import MovingBox

@MainActor
struct OpenAIRequestDebugTests {
    
    @Test("Debug Multi-Photo Request JSON Structure")
    func debugMultiPhotoRequestJSON() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, InventoryLocation.self, InventoryLabel.self, configurations: config)
        let modelContext = container.mainContext
        let settingsManager = SettingsManager()
        
        // Create test images
        let testImages = [createTestImage(), createTestImage(), createTestImage()]
        let base64Images = await OptimizedImageManager.shared.prepareMultipleImagesForAI(from: testImages)
        
        let service = OpenAIService(imageBase64Array: base64Images, settings: settingsManager, modelContext: modelContext)
        let urlRequest = try service.generateURLRequest(httpMethod: .post)
        
        guard let bodyData = urlRequest.httpBody else {
            throw TestError.requestBodyMissing
        }
        
        // Pretty print the JSON request
        let jsonObject = try JSONSerialization.jsonObject(with: bodyData)
        let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
        let prettyJSON = String(data: prettyData, encoding: .utf8) ?? "Unable to format JSON"
        
        print("🔍 Multi-Photo Request JSON Structure:")
        print(String(repeating: "=", count: 60))
        print(prettyJSON)
        print(String(repeating: "=", count: 60))
        
        // Verify specific structure
        let payload = try service.decodePayload(from: bodyData)
        
        print("\n📋 Request Summary:")
        print("- Model: \(payload.model)")
        print("- Max Tokens: \(payload.max_completion_tokens)")
        print("- Messages Count: \(payload.messages.count)")
        print("- Content Items: \(payload.messages[0].content.count)")
        print("- Function Name: \(payload.tools[0].function.name)")
        print("- Function Description: \(payload.tools[0].function.description)")
        
        // Check function call structure
        print("\n🎯 Tool Choice:")
        print("- Tool Choice: \(payload.tool_choice)")
        
        // Verify content structure
        let message = payload.messages[0]
        let textContent = message.content.filter { $0.type == "text" }
        let imageContent = message.content.filter { $0.type == "image_url" }
        
        print("\n📝 Message Content:")
        print("- Text prompts: \(textContent.count)")
        print("- Images: \(imageContent.count)")
        print("- Text content: \(textContent.first?.text?.prefix(100) ?? "None")...")
        
        // Verify the structure follows OpenAI API expectations
        #expect(payload.messages.count == 1, "Should have exactly 1 message")
        #expect(message.role == "user", "Message should be from user")
        #expect(textContent.count == 1, "Should have exactly 1 text prompt")
        #expect(imageContent.count == 3, "Should have exactly 3 images")
        #expect(payload.tool_choice.function.name == "process_inventory_item", "Should call correct function")
        
        print("\n✅ Request structure validation passed")
    }
    
    @Test("Validate Request Headers and Auth")
    func validateRequestHeaders() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, configurations: config)
        let modelContext = container.mainContext
        let settingsManager = SettingsManager()
        
        let testImage = createTestImage()
        let base64String = await OptimizedImageManager.shared.prepareImageForAI(from: testImage)!
        
        let service = OpenAIService(imageBase64: base64String, settings: settingsManager, modelContext: modelContext)
        let urlRequest = try service.generateURLRequest(httpMethod: .post)
        
        print("🔗 Request Headers:")
        print("- URL: \(urlRequest.url?.absoluteString ?? "None")")
        print("- Method: \(urlRequest.httpMethod ?? "None")")
        print("- Content-Type: \(urlRequest.value(forHTTPHeaderField: "Content-Type") ?? "None")")
        
        let authHeader = urlRequest.value(forHTTPHeaderField: "Authorization") ?? ""
        print("- Authorization: \(authHeader.prefix(20))...")
        
        // Verify headers
        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(authHeader.starts(with: "Bearer "))
        #expect(urlRequest.url?.absoluteString.contains("/v1/chat/completions") == true)
        
        print("✅ Headers validation passed")
    }
    
    @Test("Compare Single vs Multi Request Size")
    func compareRequestSizes() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, configurations: config)
        let modelContext = container.mainContext
        let settingsManager = SettingsManager()
        
        let testImage = createTestImage()
        let base64String = await OptimizedImageManager.shared.prepareImageForAI(from: testImage)!
        
        // Single image request
        let singleService = OpenAIService(imageBase64: base64String, settings: settingsManager, modelContext: modelContext)
        let singleRequest = try singleService.generateURLRequest(httpMethod: .post)
        let singleSize = singleRequest.httpBody?.count ?? 0
        
        // Multi-image request (3 images)
        let multiService = OpenAIService(imageBase64Array: [base64String, base64String, base64String], settings: settingsManager, modelContext: modelContext)
        let multiRequest = try multiService.generateURLRequest(httpMethod: .post)
        let multiSize = multiRequest.httpBody?.count ?? 0
        
        print("📊 Request Size Comparison:")
        print("- Single image: \(singleSize) bytes (\(Double(singleSize) / 1024.0) KB)")
        print("- Multi image (3x): \(multiSize) bytes (\(Double(multiSize) / 1024.0) KB)")
        print("- Size ratio: \(Double(multiSize) / Double(singleSize))x")
        
        // Multi should be roughly 3x larger but not exactly due to prompt differences
        #expect(multiSize > singleSize * 2, "Multi-image request should be significantly larger")
        #expect(multiSize < singleSize * 5, "Multi-image request shouldn't be too much larger")
        
        print("✅ Size comparison validation passed")
    }
    
    @Test("Validate Function Response Schema")
    func validateFunctionResponseSchema() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, configurations: config)
        let modelContext = container.mainContext
        let settingsManager = SettingsManager()
        
        let testImage = createTestImage()
        let base64String = await OptimizedImageManager.shared.prepareImageForAI(from: testImage)!
        
        let service = OpenAIService(imageBase64Array: [base64String, base64String], settings: settingsManager, modelContext: modelContext)
        let urlRequest = try service.generateURLRequest(httpMethod: .post)
        let payload = try service.decodePayload(from: urlRequest.httpBody!)
        
        let function = payload.tools[0].function
        
        print("🔧 Function Schema:")
        print("- Name: \(function.name)")
        print("- Description: \(function.description)")
        print("- Parameter Type: \(function.parameters.type)")
        print("- Required Fields: \(function.parameters.required)")
        print("- Properties Count: \(function.parameters.properties.count)")
        
        // Verify function structure
        #expect(function.name == "process_inventory_item")
        #expect(function.parameters.type == "object")
        #expect(function.parameters.required.contains("title"))
        #expect(function.parameters.required.contains("description"))
        #expect(function.parameters.properties["title"] != nil)
        #expect(function.parameters.properties["description"] != nil)
        
        // Check if description field exists and has content
        if let descriptionParam = function.parameters.properties["description"] {
            print("- Description Parameter: \(descriptionParam.description ?? "None")")
            #expect(descriptionParam.description != nil, "Description parameter should have content")
        }
        
        print("✅ Function schema validation passed")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Create a more detailed test image
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.white.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 100, height: 100))
            
            UIColor.red.setFill()
            context.fill(CGRect(x: 75, y: 75, width: 50, height: 50))
        }
    }
    
    private enum TestError: Error {
        case requestBodyMissing
    }
}
