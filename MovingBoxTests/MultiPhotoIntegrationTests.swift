import Testing
import SwiftData
import UIKit
@testable import MovingBox

@MainActor
struct MultiPhotoIntegrationTests {
    
    @Test("Multi-photo capture and AI analysis integration")
    func testMultiPhotoIntegrationFlow() async throws {
        // Setup test environment
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, InventoryLocation.self, InventoryLabel.self, configurations: config)
        let modelContext = container.mainContext
        
        let settingsManager = SettingsManager()
        
        // Create test images
        let testImages = createTestImages(count: 3)
        
        // Test 1: Multi-photo item creation
        let newItem = InventoryItem(
            title: "",
            quantityString: "1",
            quantityInt: 1,
            desc: "",
            serial: "",
            model: "",
            make: "",
            location: nil,
            label: nil,
            price: Decimal.zero,
            insured: false,
            assetId: UUID().uuidString,
            notes: "",
            showInvalidQuantityAlert: false
        )
        
        // Simulate saving multiple images
        let itemId = newItem.assetId
        let primaryImageURL = try await OptimizedImageManager.shared.saveImage(testImages[0], id: itemId)
        newItem.imageURL = primaryImageURL
        
        if testImages.count > 1 {
            let secondaryImages = Array(testImages.dropFirst())
            let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(secondaryImages, itemId: itemId)
            newItem.secondaryPhotoURLs = secondaryURLs
        }
        
        modelContext.insert(newItem)
        try modelContext.save()
        
        // Verify multi-photo storage
        #expect(newItem.imageURL != nil)
        #expect(newItem.secondaryPhotoURLs.count == 2)
        #expect(newItem.getTotalPhotoCount() == 3)
        
        // Test 2: OpenAI service with multiple images
        let base64Images = await OptimizedImageManager.shared.prepareMultipleImagesForAI(from: testImages)
        #expect(base64Images.count == 3)
        #expect(!base64Images.isEmpty)
        
        // Verify OpenAI service can handle multiple images
        let openAIService = OpenAIService(imageBase64Array: base64Images, settings: settingsManager, modelContext: modelContext)
        #expect(openAIService.imageBase64Array.count == 3)
        
        // Test 3: Adding photos to existing item
        let additionalImages = createTestImages(count: 2)
        let additionalURLs = try await OptimizedImageManager.shared.saveSecondaryImages(additionalImages, itemId: itemId)
        newItem.secondaryPhotoURLs.append(contentsOf: additionalURLs)
        
        #expect(newItem.getTotalPhotoCount() == 5)
        #expect(newItem.secondaryPhotoURLs.count == 4)
        
        // Test 4: Photo deletion with primary promotion
        let originalPrimaryURL = newItem.imageURL
        newItem.imageURL = nil // Simulate deleting primary
        
        // Promote first secondary to primary
        if !newItem.secondaryPhotoURLs.isEmpty {
            if let firstSecondaryURL = URL(string: newItem.secondaryPhotoURLs.first!) {
                newItem.imageURL = firstSecondaryURL
                newItem.secondaryPhotoURLs.removeFirst()
            }
        }
        
        #expect(newItem.imageURL != nil)
        #expect(newItem.imageURL != originalPrimaryURL)
        #expect(newItem.secondaryPhotoURLs.count == 3)
        #expect(newItem.getTotalPhotoCount() == 4)
        
        // Cleanup test images
        try await cleanupTestImages(item: newItem)
    }
    
    @Test("Memory performance with multiple high-resolution images")
    func testMemoryPerformanceWithMultipleImages() async throws {
        let startMemory = getCurrentMemoryUsage()
        
        // Create 5 high-resolution test images
        let largeImages = createLargeTestImages(count: 5)
        
        // Process images through OptimizedImageManager
        let itemId = UUID().uuidString
        let primaryURL = try await OptimizedImageManager.shared.saveImage(largeImages[0], id: itemId)
        let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(Array(largeImages.dropFirst()), itemId: itemId)
        
        // Verify images are optimized (should be much smaller than original)
        for url in [primaryURL] + secondaryURLs.compactMap({ URL(string: $0) }) {
            let data = try Data(contentsOf: url)
            // Optimized images should be reasonable size (under 2MB each)
            #expect(data.count < 2_000_000, "Image should be optimized to under 2MB: \(data.count) bytes")
        }
        
        // Test AI preparation
        let base64Images = await OptimizedImageManager.shared.prepareMultipleImagesForAI(from: largeImages)
        #expect(base64Images.count == 5)
        
        let endMemory = getCurrentMemoryUsage()
        let memoryIncrease = endMemory - startMemory
        
        // Memory increase should be reasonable (under 200MB for 5 large images in simulator)
        // Note: This is lenient because simulator memory reporting can be inconsistent
        #expect(memoryIncrease < 200_000_000, "Memory increase should be under 200MB: \(memoryIncrease) bytes")
        
        // Cleanup
        for url in [primaryURL] + secondaryURLs.compactMap({ URL(string: $0) }) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    @Test("Error handling scenarios")
    func testErrorHandlingScenarios() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, configurations: config)
        let modelContext = container.mainContext
        
        // Test 1: Invalid image data
        let invalidImage = UIImage()
        let itemId = UUID().uuidString
        
        do {
            _ = try await OptimizedImageManager.shared.saveImage(invalidImage, id: itemId)
            #expect(Bool(false), "Should throw error for invalid image")
        } catch {
            // Expected to fail
            #expect(error is OptimizedImageManager.ImageError)
        }
        
        // Test 2: Empty image array for AI
        let emptyBase64Array: [String] = []
        let settingsManager = SettingsManager()
        let openAIService = OpenAIService(imageBase64Array: emptyBase64Array, settings: settingsManager, modelContext: modelContext)
        
        #expect(openAIService.imageBase64Array.isEmpty)
        
        // Test 3: Invalid URL string for photo deletion
        let item = InventoryItem(
            title: "Test",
            quantityString: "1",
            quantityInt: 1,
            desc: "",
            serial: "",
            model: "",
            make: "",
            location: nil,
            label: nil,
            price: Decimal.zero,
            insured: false,
            assetId: "",
            notes: "",
            showInvalidQuantityAlert: false
        )
        
        item.secondaryPhotoURLs = ["invalid-url", "another-invalid-url"]
        
        // Should handle invalid URLs gracefully
        do {
            try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: "invalid-url")
        } catch {
            // Expected behavior - invalid URLs should be handled gracefully
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImages(count: Int) -> [UIImage] {
        return (0..<count).compactMap { _ in
            createSquareTestImage(size: 200)
        }
    }
    
    private func createLargeTestImages(count: Int) -> [UIImage] {
        return (0..<count).compactMap { _ in
            createSquareTestImage(size: 2000) // Large images for memory testing
        }
    }
    
    private func createSquareTestImage(size: Int) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            // Create a simple colored square
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            
            // Add some content
            UIColor.white.setFill()
            context.fill(CGRect(x: size/4, y: size/4, width: size/2, height: size/2))
        }
    }
    
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
    
    private func cleanupTestImages(item: InventoryItem) async throws {
        // Clean up primary image
        if let primaryURL = item.imageURL {
            try? FileManager.default.removeItem(at: primaryURL)
        }
        
        // Clean up secondary images
        for urlString in item.secondaryPhotoURLs {
            if let url = URL(string: urlString) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}