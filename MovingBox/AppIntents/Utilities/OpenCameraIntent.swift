//
//  OpenCameraIntent.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct OpenCameraIntent: AppIntent, MovingBoxIntent {
    static let title: LocalizedStringResource = "Open Camera"
    static let description: IntentDescription = "Open MovingBox camera to add a new item"
    
    static let openAppWhenRun: Bool = true
    static let isDiscoverable: Bool = true
    
    @Parameter(title: "Default Location", description: "Optional: Pre-select this location for the new item")
    var defaultLocation: LocationEntity?
    
    @Parameter(title: "Default Label", description: "Optional: Pre-select this label for the new item")
    var defaultLabel: LabelEntity?
    
    static let parameterSummary = ParameterSummary(
        "Open camera to add new inventory item"
    )
    
    func perform() async throws -> some IntentResult & ProvidesDialog & OpensIntent {
        let baseIntent = BaseDataIntent()
        baseIntent.logIntentExecution("OpenCamera", parameters: [
            "hasDefaultLocation": defaultLocation != nil,
            "hasDefaultLabel": defaultLabel != nil
        ])
        
        // Create message based on pre-selected options
        var message = "Opening MovingBox camera to add a new item"
        
        if let location = defaultLocation?.name, let label = defaultLabel?.name {
            message += " in \(location) with \(label) category"
        } else if let location = defaultLocation?.name {
            message += " in \(location)"
        } else if let label = defaultLabel?.name {
            message += " with \(label) category"
        }
        
        let dialog = IntentDialog(stringLiteral: message)
        
        // In a full implementation, this would use deep linking to open the specific camera view
        // with the pre-selected location and label. For now, we'll just open the app.
        
        // The app will need to handle the deep link parameters to pre-populate the camera view
        // This could be implemented via URL schemes or app-specific deep linking
        
        return .result(dialog: dialog, opensIntent: OpenAppIntent())
    }
}

@available(iOS 16.0, *)
struct OpenAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Open MovingBox"
    static let description: IntentDescription = "Open the MovingBox app"
    
    static let openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Quick Camera Shortcut Intent

@available(iOS 16.0, *)
struct QuickCameraIntent: AppIntent, MovingBoxIntent {
    static let title: LocalizedStringResource = "Quick Camera"
    static let description: IntentDescription = "Quickly open camera with pre-configured settings for common scenarios"
    
    static let openAppWhenRun: Bool = true
    static let isDiscoverable: Bool = true
    
    @Parameter(title: "Preset", description: "Quick preset for common item types")
    var preset: CameraPreset
    
    static let parameterSummary = ParameterSummary(
        "Quick camera for \(\.$preset)"
    )
    
    func perform() async throws -> some IntentResult & ProvidesDialog & OpensIntent {
        let baseIntent = BaseDataIntent()
        baseIntent.logIntentExecution("QuickCamera", parameters: [
            "preset": preset.rawValue
        ])
        
        let message = "Opening camera with \(preset.rawValue) preset"
        let dialog = IntentDialog(stringLiteral: message)
        
        // In implementation, this would pass preset parameters to the camera view
        return .result(dialog: dialog, opensIntent: OpenAppIntent())
    }
}

@available(iOS 16.0, *)
enum CameraPreset: String, AppEnum, CaseIterable, Sendable {
    case electronics = "Electronics"
    case furniture = "Furniture"  
    case appliances = "Appliances"
    case tools = "Tools"
    case jewelry = "Jewelry"
    case books = "Books"
    case clothing = "Clothing"
    case kitchen = "Kitchen Items"
    case outdoor = "Outdoor Gear"
    case office = "Office Supplies"
    
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Camera Preset"
    
    static let caseDisplayRepresentations: [CameraPreset: DisplayRepresentation] = [
        .electronics: DisplayRepresentation(
            title: "Electronics",
            subtitle: "TVs, computers, phones, etc.",
            image: .systemName("tv.fill")
        ),
        .furniture: DisplayRepresentation(
            title: "Furniture", 
            subtitle: "Chairs, tables, sofas, etc.",
            image: .systemName("sofa.fill")
        ),
        .appliances: DisplayRepresentation(
            title: "Appliances",
            subtitle: "Kitchen & home appliances",
            image: .systemName("refrigerator.fill")
        ),
        .tools: DisplayRepresentation(
            title: "Tools",
            subtitle: "Hand tools, power tools, etc.",
            image: .systemName("hammer.fill")
        ),
        .jewelry: DisplayRepresentation(
            title: "Jewelry",
            subtitle: "Watches, rings, necklaces, etc.",
            image: .systemName("star.fill")
        ),
        .books: DisplayRepresentation(
            title: "Books",
            subtitle: "Books, magazines, documents",
            image: .systemName("book.fill")
        ),
        .clothing: DisplayRepresentation(
            title: "Clothing",
            subtitle: "Clothes, shoes, accessories",
            image: .systemName("tshirt.fill")
        ),
        .kitchen: DisplayRepresentation(
            title: "Kitchen Items",
            subtitle: "Cookware, utensils, dishes",
            image: .systemName("fork.knife")
        ),
        .outdoor: DisplayRepresentation(
            title: "Outdoor Gear",
            subtitle: "Camping, sports, garden tools",
            image: .systemName("tent.fill")
        ),
        .office: DisplayRepresentation(
            title: "Office Supplies",
            subtitle: "Stationery, equipment, furniture",
            image: .systemName("pencil.and.outline")
        )
    ]
    
    var suggestedLocation: String {
        switch self {
        case .electronics:
            return "Living Room"
        case .furniture:
            return "Living Room"
        case .appliances:
            return "Kitchen"
        case .tools:
            return "Garage"
        case .jewelry:
            return "Bedroom"
        case .books:
            return "Home Office"
        case .clothing:
            return "Bedroom"
        case .kitchen:
            return "Kitchen"
        case .outdoor:
            return "Garage"
        case .office:
            return "Home Office"
        }
    }
    
    var suggestedLabel: String {
        return self.rawValue
    }
}