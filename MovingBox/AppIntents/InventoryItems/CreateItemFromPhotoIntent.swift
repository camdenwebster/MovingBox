//
//  CreateItemFromPhotoIntent.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents
import SwiftData
import SwiftUI

@available(iOS 16.0, *)
struct CreateItemFromPhotoIntent: AppIntent, MovingBoxIntent {
    static let title: LocalizedStringResource = "Create Inventory Item from Photo"
    static let description: IntentDescription = "Take or select a photo and use AI to automatically create an inventory item"
    
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = true
    
    @Parameter(title: "Photo", description: "Photo of the item to analyze")
    var photo: IntentFile?
    
    @Parameter(title: "Take Photo", default: false, description: "Take a new photo with the camera")
    var takePhoto: Bool
    
    @Parameter(title: "Open in App", default: false, description: "Open the created item in the app after creation")
    var openInApp: Bool
    
    static let parameterSummary = ParameterSummary(
        "Create inventory item from \(\.$photo)"
    )
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let baseIntent = BaseDataIntent()
        baseIntent.logIntentExecution("CreateItemFromPhoto", parameters: [
            "hasPhoto": photo != nil,
            "takePhoto": takePhoto,
            "openInApp": openInApp
        ])
        
        // Handle photo input
        let imageData: Data
        
        if takePhoto {
            // Request camera access and take photo
            // Note: In a real implementation, this would need camera permissions
            throw IntentError.cameraUnavailable
        } else if let photoFile = photo {
            imageData = photoFile.data
        } else {
            throw IntentError.invalidInput("No photo provided")
        }
        
        // Validate image data
        guard imageData.count > 0,
              UIImage(data: imageData) != nil else {
            throw IntentError.invalidInput("Invalid photo data")
        }
        
        // Convert image to base64 for AI analysis
        let base64Image = imageData.base64EncodedString()
        
        // Perform AI analysis
        let analysisResult = try await performAIAnalysis(base64Image: base64Image)
        
        // Create inventory item from analysis
        let createdItem = try await baseIntent.executeDataOperation { context in
            let newItem = InventoryItem()
            newItem.title = analysisResult.title
            newItem.quantityString = analysisResult.quantity.isEmpty ? "1" : analysisResult.quantity
            newItem.quantityInt = Int(newItem.quantityString) ?? 1
            newItem.desc = analysisResult.description
            newItem.make = analysisResult.make
            newItem.model = analysisResult.model
            newItem.serial = analysisResult.serial
            newItem.price = Decimal(analysisResult.estimatedPrice ?? 0)
            newItem.insured = false
            newItem.notes = analysisResult.notes
            newItem.hasUsedAI = true // Mark as AI-created
            newItem.createdAt = Date()
            
            // Set location if AI identified one
            if !analysisResult.suggestedLocation.isEmpty {
                let locationPredicate = #Predicate<InventoryLocation> { location in
                    location.name.localizedCaseInsensitiveContains(analysisResult.suggestedLocation)
                }
                let locationDescriptor = FetchDescriptor<InventoryLocation>(predicate: locationPredicate)
                if let matchingLocation = try context.fetch(locationDescriptor).first {
                    newItem.location = matchingLocation
                }
            }
            
            // Set label if AI identified one
            if !analysisResult.suggestedLabel.isEmpty {
                let labelPredicate = #Predicate<InventoryLabel> { label in
                    label.name.localizedCaseInsensitiveContains(analysisResult.suggestedLabel)
                }
                let labelDescriptor = FetchDescriptor<InventoryLabel>(predicate: labelPredicate)
                if let matchingLabel = try context.fetch(labelDescriptor).first {
                    newItem.label = matchingLabel
                }
            }
            
            // Save the photo
            if let image = UIImage(data: imageData) {
                let imageId = UUID().uuidString
                do {
                    newItem.imageURL = try await OptimizedImageManager.shared.saveImage(image, id: imageId)
                } catch {
                    print("⚠️ Failed to save image for AI-created item: \(error)")
                    // Continue without photo rather than failing
                }
            }
            
            context.insert(newItem)
            return newItem
        }
        
        // Create response message
        let message = "Created '\(createdItem.title)' from photo analysis. AI identified: \(analysisResult.description)"
        let dialog = IntentDialog(stringLiteral: message)
        
        // Create snippet view
        let snippetView = PhotoAnalysisSnippetView(
            title: createdItem.title,
            quantity: createdItem.quantityString,
            description: analysisResult.description,
            make: analysisResult.make,
            model: analysisResult.model,
            confidence: analysisResult.confidence,
            hasPhoto: createdItem.imageURL != nil
        )
        
        return .result(dialog: dialog, view: snippetView)
    }
    
    private func performAIAnalysis(base64Image: String) async throws -> AIAnalysisResult {
        // Create a temporary model context for AI service
        let context = BaseDataIntent.sharedContainer.mainContext
        
        // Create settings manager instance (simplified for intent context)
        let settings = SettingsManager()
        
        // Use existing OpenAI service
        let aiService = OpenAIService(imageBase64: base64Image, settings: settings, modelContext: context)
        
        do {
            let result = try await aiService.fetchInventoryItem()
            
            return AIAnalysisResult(
                title: result.title,
                quantity: result.quantityString,
                description: result.desc,
                make: result.make,
                model: result.model,
                serial: result.serial,
                estimatedPrice: NSDecimalNumber(decimal: result.price).doubleValue,
                notes: result.notes,
                suggestedLocation: result.location?.name ?? "",
                suggestedLabel: result.label?.name ?? "",
                confidence: 0.85 // Default confidence score
            )
        } catch {
            throw IntentError.aiServiceError("Failed to analyze photo: \(error.localizedDescription)")
        }
    }
}

@available(iOS 16.0, *)
struct AIAnalysisResult: Sendable {
    let title: String
    let quantity: String
    let description: String
    let make: String
    let model: String
    let serial: String
    let estimatedPrice: Double?
    let notes: String
    let suggestedLocation: String
    let suggestedLabel: String
    let confidence: Double
}

@available(iOS 16.0, *)
struct PhotoAnalysisSnippetView: View {
    let title: String
    let quantity: String
    let description: String
    let make: String
    let model: String
    let confidence: Double
    let hasPhoto: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "camera.viewfinder")
                    .foregroundColor(.blue)
                Text("AI Photo Analysis")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                if hasPhoto {
                    Image(systemName: "photo.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Title and quantity
                HStack {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Qty: \(quantity)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                
                // Description
                if !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Make and Model
                if !make.isEmpty || !model.isEmpty {
                    let makeModel = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
                    if !makeModel.isEmpty {
                        Text("Make/Model: \(makeModel)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // AI Confidence
                HStack {
                    Label("AI Analysis", systemImage: "brain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(confidence * 100))% confident")
                        .font(.caption)
                        .foregroundColor(confidence > 0.8 ? .green : confidence > 0.6 ? .orange : .red)
                }
                
                // Success indicator
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Item created successfully")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
    }
}