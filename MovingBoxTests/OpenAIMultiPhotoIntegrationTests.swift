import Testing
import SwiftData
import UIKit
@testable import MovingBox

@MainActor
struct OpenAIMultiPhotoIntegrationTests {
    
    @Test("OpenAI Service - Single Image Request Format")
    func testSingleImageRequestFormat() async throws {
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, InventoryLocation.self, InventoryLabel.self, configurations: config)
        let modelContext = container.mainContext
        let settingsManager = SettingsManager()
        
        // Create a test image and convert to base64
        let testImage = createTestImage()
        let base64String = await OptimizedImageManager.shared.prepareImageForAI(from: testImage)
        
        guard let base64String = base64String else {
            throw TestError.imagePreparationFailed
        }
        
        // Test single image service initialization
        let singleImageService = OpenAIService(imageBase64: base64String, settings: settingsManager, modelContext: modelContext)
        
        // Verify service properties
        #expect(singleImageService.imageBase64 == base64String)
        #expect(singleImageService.imageBase64Array.count == 1)
        #expect(singleImageService.imageBase64Array.first == base64String)
        
        // Test URL request generation
        let urlRequest = try singleImageService.generateURLRequest(httpMethod: .post)
        
        // Verify request structure
        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization")?.starts(with: "Bearer ") == true)
        
        // Parse and verify request body
        guard let bodyData = urlRequest.httpBody else {
            throw TestError.requestBodyMissing
        }
        
        let payload = try singleImageService.decodePayload(from: bodyData)
        
        // Verify payload structure for single image
        #expect(payload.messages.count == 1)
        let message = payload.messages[0]
        #expect(message.role == "user")
        #expect(message.content.count == 2) // Should have text + 1 image
        
        // Verify content types
        let textContent = message.content.first { $0.type == "text" }
        let imageContent = message.content.first { $0.type == "image_url" }
        
        #expect(textContent != nil)
        #expect(imageContent != nil)
        #expect(textContent?.text?.contains("Analyze this image") == true)
        #expect(imageContent?.image_url?.url.starts(with: "data:image/png:base64,") == true)
        
        print("✅ Single image request format verified")
    }
    
    @Test("OpenAI Service - Multi Image Request Format")
    func testMultiImageRequestFormat() async throws {
        // Setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, InventoryLocation.self, InventoryLabel.self, configurations: config)
        let modelContext = container.mainContext
        let settingsManager = SettingsManager()
        
        // Create multiple test images
        let testImages = [createTestImage(), createTestImage(), createTestImage()]
        let base64Images = await OptimizedImageManager.shared.prepareMultipleImagesForAI(from: testImages)
        
        #expect(base64Images.count == 3)
        
        // Test multi-image service initialization
        let multiImageService = OpenAIService(imageBase64Array: base64Images, settings: settingsManager, modelContext: modelContext)
        
        // Verify service properties
        #expect(multiImageService.imageBase64Array.count == 3)
        #expect(multiImageService.imageBase64 == base64Images.first)
        
        // Test URL request generation
        let urlRequest = try multiImageService.generateURLRequest(httpMethod: .post)
        
        // Parse and verify request body
        guard let bodyData = urlRequest.httpBody else {
            throw TestError.requestBodyMissing
        }
        
        let payload = try multiImageService.decodePayload(from: bodyData)
        
        // Verify payload structure for multiple images
        #expect(payload.messages.count == 1)
        let message = payload.messages[0]
        #expect(message.role == "user")
        #expect(message.content.count == 4) // Should have text + 3 images
        
        // Verify content types
        let textContent = message.content.filter { $0.type == "text" }
        let imageContents = message.content.filter { $0.type == "image_url" }
        
        #expect(textContent.count == 1)
        #expect(imageContents.count == 3)
        #expect(textContent.first?.text?.contains("Analyze these 3 images") == true)
        #expect(textContent.first?.text?.contains("comprehensive description") == true)
        
        // Verify all images are properly formatted
        for imageContent in imageContents {
            #expect(imageContent.image_url?.url.starts(with: "data:image/png:base64,") == true)
            #expect(imageContent.image_url?.detail != nil)
        }
        
        // Verify function call structure is the same (should return single response)
        #expect(payload.functions.count == 1)
        #expect(payload.functions[0].name == "process_inventory_item")
        #expect(payload.function_call["name"] == "process_inventory_item")
        
        print("✅ Multi-image request format verified")
        print("📋 Request summary:")
        print("  - Messages: \(payload.messages.count)")
        print("  - Content items: \(message.content.count)")
        print("  - Text prompts: \(textContent.count)")
        print("  - Images: \(imageContents.count)")
        print("  - Function call: \(payload.function_call)")
    }
    
    @Test("OpenAI Service - Live Backend Integration (Multi-Photo)", .disabled("Requires live API"))
    func testLiveMultiPhotoAPICall() async throws {
        // This test is disabled by default but can be enabled for debugging
        // Remove .disabled() to run with live API
        
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, InventoryLocation.self, InventoryLabel.self, configurations: config)
        let modelContext = container.mainContext
        let settingsManager = SettingsManager()
        
        // Create test images
        let testImages = [createTestImage(), createTestImage()]
        let base64Images = await OptimizedImageManager.shared.prepareMultipleImagesForAI(from: testImages)
        
        let service = OpenAIService(imageBase64Array: base64Images, settings: settingsManager, modelContext: modelContext)
        
        do {
            let result = try await service.getImageDetails()
            print("✅ Live API call successful!")
            print("📝 Response: \(result)")
            
            // Verify response structure
            #expect(!result.title.isEmpty)
            #expect(!result.description.isEmpty)
            #expect(!result.category.isEmpty)
            
        } catch let error as OpenAIError {
            print("❌ OpenAI API Error: \(error)")
            print("📄 User-friendly message: \(error.userFriendlyMessage)")
            throw error
        } catch {
            print("❌ Unexpected error: \(error)")
            throw error
        }
    }
    
    @Test("OpenAI Service - Compare Single vs Multi Photo Responses")
    func testSingleVsMultiPhotoResponseFormat() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, InventoryLocation.self, InventoryLabel.self, configurations: config)
        let modelContext = container.mainContext
        let settingsManager = SettingsManager()
        
        let testImage = createTestImage()
        let base64String = await OptimizedImageManager.shared.prepareImageForAI(from: testImage)!
        
        // Test single image request
        let singleImageService = OpenAIService(imageBase64: base64String, settings: settingsManager, modelContext: modelContext)
        let singleRequest = try singleImageService.generateURLRequest(httpMethod: .post)
        let singlePayload = try singleImageService.decodePayload(from: singleRequest.httpBody!)
        
        // Test multi-image request
        let multiImageService = OpenAIService(imageBase64Array: [base64String, base64String], settings: settingsManager, modelContext: modelContext)
        let multiRequest = try multiImageService.generateURLRequest(httpMethod: .post)
        let multiPayload = try multiImageService.decodePayload(from: multiRequest.httpBody!)
        
        // Both should have the same function structure (ensuring single response)
        #expect(singlePayload.functions.count == multiPayload.functions.count)
        #expect(singlePayload.function_call == multiPayload.function_call)
        #expect(singlePayload.model == multiPayload.model)
        #expect(singlePayload.max_tokens == multiPayload.max_tokens)
        
        // The key difference should be in message content count and prompt text
        let singleMessage = singlePayload.messages[0]
        let multiMessage = multiPayload.messages[0]
        
        #expect(singleMessage.content.count == 2) // text + 1 image
        #expect(multiMessage.content.count == 3) // text + 2 images
        
        let singleText = singleMessage.content.first { $0.type == "text" }?.text ?? ""
        let multiText = multiMessage.content.first { $0.type == "text" }?.text ?? ""
        
        #expect(singleText.contains("this image"))
        #expect(multiText.contains("these 2 images"))
        
        print("✅ Single vs Multi-photo request comparison verified")
        print("📊 Single: \(singleMessage.content.count) content items")
        print("📊 Multi: \(multiMessage.content.count) content items")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.white.setFill()
            context.fill(CGRect(x: 25, y: 25, width: 50, height: 50))
        }
    }
    
    private enum TestError: Error {
        case imagePreparationFailed
        case requestBodyMissing
    }
}