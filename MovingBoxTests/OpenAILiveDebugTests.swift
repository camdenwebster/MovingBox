import Testing
import SwiftData
import UIKit
@testable import MovingBox

@MainActor
struct OpenAILiveDebugTests {
    
    // Enable this test by removing .disabled() when you want to debug with live API
    @Test("Live API - Single Image Test", .disabled("Enable for live debugging"))
    func testLiveSingleImageAPI() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, InventoryLocation.self, InventoryLabel.self, configurations: config)
        let modelContext = container.mainContext
        let settingsManager = SettingsManager()
        
        let testImage = createDetailedTestImage()
        let base64String = await OptimizedImageManager.shared.prepareImageForAI(from: testImage)!
        
        print("🧪 Testing SINGLE image API call...")
        
        let service = OpenAIService(imageBase64: base64String, settings: settingsManager, modelContext: modelContext)
        
        do {
            let result = try await service.getImageDetails()
            print("✅ Single image API call successful!")
            print("📝 Result: \(result)")
        } catch {
            print("❌ Single image API failed: \(error)")
            throw error
        }
    }
    
    // Enable this test by removing .disabled() when you want to debug with live API
    @Test("Live API - Multi Image Test", .disabled("Enable for live debugging"))
    func testLiveMultiImageAPI() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, InventoryLocation.self, InventoryLabel.self, configurations: config)
        let modelContext = container.mainContext
        let settingsManager = SettingsManager()
        
        // Create 2 different test images to simulate real multi-photo scenario
        let testImages = [createDetailedTestImage(), createAlternateTestImage()]
        let base64Images = await OptimizedImageManager.shared.prepareMultipleImagesForAI(from: testImages)
        
        print("🧪 Testing MULTI image API call with \(base64Images.count) images...")
        
        let service = OpenAIService(imageBase64Array: base64Images, settings: settingsManager, modelContext: modelContext)
        
        do {
            let result = try await service.getImageDetails()
            print("✅ Multi image API call successful!")
            print("📝 Result: \(result)")
            
            // Verify we got a single, comprehensive response
            #expect(!result.title.isEmpty, "Title should not be empty")
            #expect(!result.description.isEmpty, "Description should not be empty")
            #expect(result.description.count <= 160, "Description should be under 160 characters")
            
        } catch {
            print("❌ Multi image API failed: \(error)")
            print("💡 This is the error we need to fix!")
            throw error
        }
    }
    
    @Test("Compare Request Structures")
    func compareRequestStructures() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, configurations: config)
        let modelContext = container.mainContext
        let settingsManager = SettingsManager()
        
        let testImage = createDetailedTestImage()
        let base64String = await OptimizedImageManager.shared.prepareImageForAI(from: testImage)!
        
        // Single image request
        let singleService = OpenAIService(imageBase64: base64String, settings: settingsManager, modelContext: modelContext)
        let singleRequest = try singleService.generateURLRequest(httpMethod: .post)
        
        // Multi-image request (2 copies of same image)
        let multiService = OpenAIService(imageBase64Array: [base64String, base64String], settings: settingsManager, modelContext: modelContext)
        let multiRequest = try multiService.generateURLRequest(httpMethod: .post)
        
        // Compare sizes
        let singleSize = singleRequest.httpBody?.count ?? 0
        let multiSize = multiRequest.httpBody?.count ?? 0
        
        print("📊 Request Size Comparison:")
        print("  Single: \(singleSize) bytes (\(Double(singleSize) / 1024) KB)")
        print("  Multi:  \(multiSize) bytes (\(Double(multiSize) / 1024) KB)")
        print("  Ratio:  \(Double(multiSize) / Double(singleSize))x")
        
        // Parse and compare JSON structures
        let singlePayload = try singleService.decodePayload(from: singleRequest.httpBody!)
        let multiPayload = try multiService.decodePayload(from: multiRequest.httpBody!)
        
        print("📋 Structure Comparison:")
        print("  Single message content count: \(singlePayload.messages[0].content.count)")
        print("  Multi message content count:  \(multiPayload.messages[0].content.count)")
        
        let singleText = singlePayload.messages[0].content.first { $0.type == "text" }?.text ?? ""
        let multiText = multiPayload.messages[0].content.first { $0.type == "text" }?.text ?? ""
        
        print("📝 Prompt Comparison:")
        print("  Single: \(singleText.prefix(100))...")
        print("  Multi:  \(multiText.prefix(100))...")
        
        // Both should use the same function structure
        #expect(singlePayload.function_call == multiPayload.function_call)
        #expect(singlePayload.functions[0].name == multiPayload.functions[0].name)
        
        print("✅ Request comparison completed")
    }
    
    // MARK: - Helper Methods
    
    private func createDetailedTestImage() -> UIImage {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Create a detailed image that looks like a laptop
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Laptop screen
            UIColor.black.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 200, height: 150))
            
            // Screen content
            UIColor.blue.setFill()
            context.fill(CGRect(x: 60, y: 60, width: 180, height: 130))
            
            // Apple logo (white circle)
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 140, y: 220, width: 20, height: 20))
            
            // Keyboard area
            UIColor.lightGray.setFill()
            context.fill(CGRect(x: 50, y: 210, width: 200, height: 80))
        }
    }
    
    private func createAlternateTestImage() -> UIImage {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Create a different angle/view of the same laptop
            UIColor.lightGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Side view of laptop
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 100, y: 100, width: 100, height: 100))
            
            // Ports/connections
            UIColor.black.setFill()
            context.fill(CGRect(x: 95, y: 120, width: 5, height: 10))
            context.fill(CGRect(x: 95, y: 140, width: 5, height: 10))
            context.fill(CGRect(x: 95, y: 160, width: 5, height: 10))
            
            // Brand text area
            UIColor.white.setFill()
            context.fill(CGRect(x: 110, y: 130, width: 80, height: 20))
        }
    }
}