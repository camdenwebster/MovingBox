//
//  TestData.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Foundation
import SwiftData
import UIKit

@MainActor
struct TestData {
    // Helper method to load test image from asset catalog
    private static func loadTestImage(category: String, filename: String) -> Data? {
        // Use bundle to load image directly from asset catalog
        guard let image = UIImage(named: filename) else {
            print("❌ Could not load image: \(filename)")
            return nil
        }
        
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            print("❌ Could not convert image to data: \(filename)")
            return nil
        }
        
        print("✅ Successfully loaded image: \(filename)")
        return data
    }
    
    // Helper method to set up image URL for test data
    private static func setupImageURL(imageName: String, id: String) async -> URL? {
        guard let image = UIImage(named: imageName) else {
            print("❌ Could not load image: \(imageName)")
            return nil
        }
        
        do {
            let imageURL = try await OptimizedImageManager.shared.saveImage(image, id: id)
            print("✅ Successfully saved image and thumbnail: \(imageName)")
            return imageURL
        } catch {
            print("❌ Failed to save image: \(imageName), error: \(error)")
            return nil
        }
    }
    
    // Sample home with local image path
    static let homes: [(address1: String, imageName: String)] = [
        ("123 Main Street", "craftsman-home")
    ]
    
    // Sample locations with local image paths
    static let locations: [(name: String, desc: String, imageName: String)] = [
        ("Living Room", "Main living area with fireplace", "living-room"),
        ("Master Bedroom", "Primary bedroom suite", "master-bedroom"),
        ("Kitchen", "Modern kitchen with island", "kitchen"),
        ("Home Office", "Work from home setup", "home-office"),
        ("Garage", "Two-car garage with storage", "garage"),
        ("Basement", "Finished basement with storage", "basement")
    ]
    
    // Sample labels with softer, more pleasing colors and emojis
    static let labels: [(name: String, desc: String, color: UIColor, emoji: String)] = [
        ("Electronics", "Computers, phones, and gadgets", UIColor(red: 0.95, green: 0.61, blue: 0.61, alpha: 1.0), "📱"),   // Soft red
        ("Furniture", "Chairs, tables, and storage", UIColor(red: 0.82, green: 0.71, blue: 0.55, alpha: 1.0), "🪑"),       // Warm beige
        ("Kitchen", "Appliances and cookware", UIColor(red: 0.73, green: 0.87, blue: 0.68, alpha: 1.0), "🍳"),           // Sage green
        ("Books", "Books and magazines", UIColor(red: 0.67, green: 0.84, blue: 0.90, alpha: 1.0), "📚"),                 // Powder blue
        ("Art", "Paintings and decorative items", UIColor(red: 0.85, green: 0.75, blue: 0.86, alpha: 1.0), "🎨"),        // Soft lavender
        ("Tools", "Hand tools and power tools", UIColor(red: 0.80, green: 0.80, blue: 0.83, alpha: 1.0), "🔧"),         // Cool gray
        ("Sports", "Exercise and sports equipment", UIColor(red: 0.96, green: 0.76, blue: 0.56, alpha: 1.0), "🏀"),      // Peach
        ("Clothing", "Clothes and accessories", UIColor(red: 0.69, green: 0.88, blue: 0.90, alpha: 1.0), "👕"),          // Light teal
        // Additional labels
        ("Jewelry", "Watches, necklaces, and rings", UIColor(red: 0.90, green: 0.85, blue: 0.60, alpha: 1.0), "💍"),      // Pale gold
        ("Documents", "Important papers and files", UIColor(red: 0.87, green: 0.87, blue: 0.87, alpha: 1.0), "📄"),      // Light gray
        ("Collectibles", "Figurines, stamps, and memorabilia", UIColor(red: 0.78, green: 0.70, blue: 0.84, alpha: 1.0), "🏆"), // Medium purple
        ("Seasonal", "Holiday decorations and items", UIColor(red: 0.92, green: 0.70, blue: 0.70, alpha: 1.0), "🎄"),    // Light coral
        ("Bathroom", "Towels, toiletries, and accessories", UIColor(red: 0.65, green: 0.85, blue: 0.85, alpha: 1.0), "🚿"), // Light cyan
        ("Toys", "Children's toys and games", UIColor(red: 0.94, green: 0.82, blue: 0.65, alpha: 1.0), "🧸"),           // Light orange
        ("Gardening", "Plants, pots, and garden tools", UIColor(red: 0.60, green: 0.80, blue: 0.60, alpha: 1.0), "🌱"),  // Medium green
        ("Technology", "Chargers, cables, and accessories", UIColor(red: 0.75, green: 0.75, blue: 0.95, alpha: 1.0), "💻"), // Periwinkle
        ("Memorabilia", "Personal mementos and keepsakes", UIColor(red: 0.85, green: 0.80, blue: 0.70, alpha: 1.0), "🎞️"), // Light tan
        ("Pet Supplies", "Pet food, toys, and accessories", UIColor(red: 0.80, green: 0.90, blue: 0.75, alpha: 1.0), "🐾"), // Mint green
        ("Media", "DVDs, CDs, and physical media", UIColor(red: 0.70, green: 0.65, blue: 0.75, alpha: 1.0), "💿"),      // Muted purple
        ("Decorative", "Home decor and ornamental items", UIColor(red: 0.90, green: 0.80, blue: 0.90, alpha: 1.0), "🏺")  // Light pink
    ]
    
    // Sample inventory items with local image paths
    static let items: [(title: String, desc: String, make: String, model: String, price: Decimal, imageName: String, location: String, label: String)] = [
        ("MacBook Pro", "16-inch 2023 Model", "Apple", "MacBook Pro M2", Decimal(2499.99), "macbook", "Home Office", "Electronics"),
        ("OLED TV", "65-inch 4K Smart TV", "LG", "OLED65C1", Decimal(1999.99), "tv", "Living Room", "Electronics"),
        ("Coffee Maker", "Programmable 12-cup", "Cuisinart", "DCC-3200", Decimal(99.99), "coffee-maker", "Kitchen", "Kitchen"),
        ("Desk Chair", "Ergonomic Office Chair", "Herman Miller", "Aeron", Decimal(1095.00), "desk-chair", "Home Office", "Furniture"),
        ("Guitar", "Electric Guitar", "Fender", "Stratocaster", Decimal(1499.99), "guitar", "Living Room", "Art"),
        
        // Kitchen Items
        ("Stand Mixer", "Professional 5Qt Mixer", "KitchenAid", "Pro 5", Decimal(399.99), "stand-mixer", "Kitchen", "Kitchen"),
        ("Blender", "High-Performance Blender", "Vitamix", "5200", Decimal(449.99), "blender", "Kitchen", "Kitchen"),
        ("Air Fryer", "Digital Air Fryer", "Ninja", "AF101", Decimal(119.99), "air-fryer", "Kitchen", "Kitchen"),
        
        // Electronics
        ("Gaming Console", "Next-gen gaming system", "Sony", "PlayStation 5", Decimal(499.99), "gaming-console", "Living Room", "Electronics"),
        ("Smart Speaker", "Voice-controlled speaker", "Amazon", "Echo 4th Gen", Decimal(99.99), "smart-speaker", "Living Room", "Electronics"),
        ("Tablet", "11-inch Tablet", "Apple", "iPad Pro", Decimal(799.99), "tablet", "Living Room", "Electronics"),
        
        // Furniture
        ("Sofa", "3-Seater Leather Sofa", "West Elm", "Hamilton", Decimal(2199.99), "sofa", "Living Room", "Furniture"),
        ("Dining Table", "Solid Wood Dining Table", "Pottery Barn", "Banks", Decimal(1899.99), "dining-table", "Living Room", "Furniture"),
        ("Bed Frame", "King Size Platform Bed", "Article", "Timber", Decimal(1299.99), "bed-frame", "Master Bedroom", "Furniture"),
        
        // Sports Equipment
        ("Treadmill", "Smart Treadmill", "Peloton", "Tread+", Decimal(4295.00), "treadmill", "Basement", "Sports"),
        ("Bicycle", "Mountain Bike", "Trek", "Fuel EX 8", Decimal(3299.99), "bicycle", "Garage", "Sports"),
        ("Weight Set", "Adjustable Dumbbells", "Bowflex", "SelectTech 552", Decimal(399.99), "weight-set", "Home Office", "Sports"),
        
        // Tools
        ("Power Drill", "20V Cordless Drill", "DeWalt", "DCD777C2", Decimal(159.99), "power-drill", "Garage", "Tools"),
        ("Table Saw", "10-inch Table Saw", "Bosch", "4100XC-10", Decimal(599.99), "table-saw", "Garage", "Tools"),
        ("Tool Chest", "Heavy-Duty Tool Storage", "Husky", "H52CH6TR9", Decimal(499.99), "tool-chest", "Garage", "Tools"),
        
        // Art & Decor
        ("Canvas Print", "Large Abstract Art", "West Elm", "Summer Sky", Decimal(299.99), "canvas-print", "Living Room", "Art"),
        ("Area Rug", "8x10 Wool Rug", "Safavieh", "Persian", Decimal(899.99), "area-rug", "Living Room", "Furniture"),
        ("Floor Lamp", "Modern Arc Lamp", "CB2", "Big Dipper", Decimal(299.99), "floor-lamp", "Living Room", "Furniture"),
        
        // Additional Electronics
        ("Smart TV", "55-inch QLED", "Samsung", "QN55Q80B", Decimal(997.99), "smart-tv", "Living Room", "Electronics"),
        ("Sound Bar", "3.1 Channel", "Sonos", "Arc", Decimal(899.99), "sound-bar", "Living Room", "Electronics"),
        ("Wireless Router", "Mesh WiFi System", "Google", "Nest WiFi", Decimal(349.99), "wireless-router", "Home Office", "Electronics"),
        
        // Additional Kitchen Items
        ("Espresso Machine", "Semi-Automatic", "Breville", "Barista Express", Decimal(699.99), "espresso-machine", "Kitchen", "Kitchen"),
        ("Food Processor", "14-Cup", "Cuisinart", "DFP-14BCNY", Decimal(229.99), "food-processor", "Kitchen", "Kitchen"),
        ("Wine Fridge", "28 Bottle", "Wine Enthusiast", "Classic", Decimal(399.99), "wine-fridge", "Kitchen", "Kitchen"),
        
        // Additional Furniture
        ("Bookshelf", "5-Tier Bookcase", "Crate & Barrel", "Anderson", Decimal(499.99), "bookshelf", "Home Office", "Furniture"),
        ("TV Stand", "Media Console", "Pottery Barn", "Griffin", Decimal(899.99), "tv-stand", "Living Room", "Furniture"),
        ("Office Desk", "L-Shaped Desk", "Fully", "Jarvis L", Decimal(795.00), "office-desk", "Home Office", "Furniture"),
        
        // Outdoor Items
        ("Grill", "Gas Grill", "Weber", "Genesis II", Decimal(999.99), "grill", "Garage", "Furniture"),
        ("Patio Set", "4-Piece Furniture Set", "Hampton Bay", "Laguna", Decimal(799.99), "patio-set", "Garage", "Furniture"),
        ("Fire Pit", "Wood Burning", "Solo Stove", "Bonfire", Decimal(399.99), "fire-pit", "Garage", "Furniture"),
        
        // Musical Instruments
        ("Digital Piano", "88-Key Digital Piano", "Roland", "FP-90X", Decimal(1899.99), "digital-piano", "Living Room", "Art"),
        ("Bass Guitar", "4-String Electric Bass", "Fender", "Precision", Decimal(1499.99), "bass-guitar", "Living Room", "Art"),
        ("Drum Kit", "5-Piece Acoustic Kit", "Pearl", "Export", Decimal(699.99), "drum-kit", "Living Room", "Art"),
        
        // Home Office
        ("Monitor", "27-inch 4K Display", "LG", "27UK850-W", Decimal(449.99), "monitor", "Home Office", "Electronics"),
        ("Printer", "Color LaserJet", "HP", "M479fdw", Decimal(449.99), "printer", "Home Office", "Electronics"),
        ("Webcam", "4K Webcam", "Logitech", "Brio", Decimal(199.99), "webcam", "Home Office", "Electronics"),
        
        // Storage & Organization
        ("Filing Cabinet", "3-Drawer Cabinet", "HON", "H320", Decimal(299.99), "filing-cabinet", "Home Office", "Furniture"),
        ("Storage Bench", "Entryway Bench", "Threshold", "Carson", Decimal(199.99), "storage-bench", "Garage", "Furniture"),
        ("Closet System", "Walk-in Closet Kit", "ClosetMaid", "Suite Symphony", Decimal(499.99), "closet-system", "Master Bedroom", "Furniture"),
        
        // Appliances
        ("Washer", "Front Load Washer", "LG", "WM4000HBA", Decimal(999.99), "washer", "Basement", "Furniture"),
        ("Dryer", "Electric Dryer", "LG", "DLEX4000B", Decimal(999.99), "dryer", "Basement", "Furniture"),
        ("Dishwasher", "Stainless Steel", "Bosch", "SHPM88Z75N", Decimal(1099.99), "dishwasher", "Kitchen", "Kitchen"),
        
        // Entertainment
        ("Record Player", "Bluetooth Turntable", "Audio-Technica", "AT-LP120XBT", Decimal(349.99), "record-player", "Living Room", "Art"),
        ("Board Game Collection", "Classic Board Games Set", "Various", "Classics", Decimal(199.99), "board-games", "Living Room", "Art"),
        ("Projector", "4K Home Theater", "Epson", "5050UB", Decimal(2999.99), "projector", "Living Room", "Electronics"),
        
        // Lighting
        ("Chandelier", "Crystal Chandelier", "Pottery Barn", "Clarissa", Decimal(799.99), "chandelier", "Living Room", "Furniture"),
        ("Table Lamp Set", "Ceramic Table Lamps", "West Elm", "Asymmetry", Decimal(299.99), "table-lamps", "Living Room", "Furniture"),
        ("Smart Bulbs", "Color Changing Set", "Philips", "Hue", Decimal(199.99), "smart-bulbs", "Home Office", "Electronics")
    ]
    
    // Helper method to load default data (labels only) into SwiftData
    static func loadDefaultData(context: ModelContext) async {
        // Create only the labels
        for labelData in labels {
            let label = InventoryLabel(
                name: labelData.name,
                desc: labelData.desc,
                color: labelData.color,
                emoji: labelData.emoji
            )
            context.insert(label)
        }
    }
    
    @MainActor
    static func loadTestData(modelContext: ModelContext) async {
        // Create labels first
        let inventoryLabels = labels.map { labelData -> InventoryLabel in
            let label = InventoryLabel(
                name: labelData.name,
                desc: labelData.desc,
                color: labelData.color,
                emoji: labelData.emoji
            )
            modelContext.insert(label)
            return label
        }
        
        // Create home
        let descriptor = FetchDescriptor<Home>()
        let existingHomes = try? modelContext.fetch(descriptor)
        let home: Home
        
        if let firstHome = existingHomes?.first {
            home = firstHome
        } else {
            home = Home()
            modelContext.insert(home)
        }
        
        // Update home properties
        home.address1 = homes[0].address1
        let homeId = UUID().uuidString
        if let imageURL = await setupImageURL(imageName: homes[0].imageName, id: homeId) {
            home.imageURL = imageURL
        }
        
        // Create locations sequentially to maintain data consistency
        var inventoryLocations = [InventoryLocation]()
        for locationData in locations {
            let location = InventoryLocation()
            location.name = locationData.name
            location.desc = locationData.desc
            let locationId = UUID().uuidString
            if let imageURL = await setupImageURL(imageName: locationData.imageName, id: locationId) {
                location.imageURL = imageURL
            }
            modelContext.insert(location)
            inventoryLocations.append(location)
        }
        
        // Create items sequentially to maintain data consistency
        for itemData in items {
            let location = inventoryLocations.first { $0.name == itemData.location } ?? inventoryLocations[0]
            let label = inventoryLabels.first { $0.name == itemData.label } ?? inventoryLabels[0]
            
            let item = InventoryItem(
                title: itemData.title,
                quantityString: "1",
                quantityInt: 1,
                desc: itemData.desc,
                serial: "SN\(UUID().uuidString.prefix(8))",
                model: itemData.model,
                make: itemData.make,
                location: location,
                label: label,
                price: itemData.price,
                insured: false,
                assetId: "",
                notes: "",
                showInvalidQuantityAlert: false,
                hasUsedAI: true
            )
            
            let itemId = UUID().uuidString
            if let imageURL = await setupImageURL(imageName: itemData.imageName, id: itemId) {
                item.imageURL = imageURL
            }
            modelContext.insert(item)
        }
        
        try? modelContext.save()
    }
}
