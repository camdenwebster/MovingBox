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
    // Helper function to get the test images directory
    private static var testImagesDirectory: URL {
        Bundle.main.bundleURL.appendingPathComponent("Resources/TestImages")
    }
    
    private static func loadTestImage(category: String, filename: String) -> Data? {
        let imageURL = testImagesDirectory
            .appendingPathComponent(category)
            .appendingPathComponent(filename)
            .appendingPathExtension("jpg")
        return try? Data(contentsOf: imageURL)
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
    
    // Sample labels with colors
    static let labels: [(name: String, desc: String, color: UIColor)] = [
        ("Electronics", "Computers, phones, and gadgets", .red),
        ("Furniture", "Chairs, tables, and storage", .brown),
        ("Kitchen", "Appliances and cookware", .green),
        ("Books", "Books and magazines", .blue),
        ("Art", "Paintings and decorative items", .purple),
        ("Tools", "Hand tools and power tools", .gray),
        ("Sports", "Exercise and sports equipment", .orange),
        ("Clothing", "Clothes and accessories", .cyan)
    ]
    
    // Sample inventory items with local image paths
    static let items: [(title: String, desc: String, make: String, model: String, price: Decimal, imageName: String)] = [
        ("MacBook Pro", "16-inch 2023 Model", "Apple", "MacBook Pro M2", Decimal(2499.99), "macbook"),
        ("OLED TV", "65-inch 4K Smart TV", "LG", "OLED65C1", Decimal(1999.99), "tv"),
        ("Coffee Maker", "Programmable 12-cup", "Cuisinart", "DCC-3200", Decimal(99.99), "coffee-maker"),
        ("Desk Chair", "Ergonomic Office Chair", "Herman Miller", "Aeron", Decimal(1095.00), "desk-chair"),
        ("Guitar", "Electric Guitar", "Fender", "Stratocaster", Decimal(1499.99), "guitar"),
        
        // Kitchen Items
        ("Stand Mixer", "Professional 5Qt Mixer", "KitchenAid", "Pro 5", Decimal(399.99), "stand-mixer"),
        ("Blender", "High-Performance Blender", "Vitamix", "5200", Decimal(449.99), "blender"),
        ("Air Fryer", "Digital Air Fryer", "Ninja", "AF101", Decimal(119.99), "air-fryer"),
        
        // Electronics
        ("Gaming Console", "Next-gen gaming system", "Sony", "PlayStation 5", Decimal(499.99), "gaming-console"),
        ("Smart Speaker", "Voice-controlled speaker", "Amazon", "Echo 4th Gen", Decimal(99.99), "smart-speaker"),
        ("Tablet", "11-inch Tablet", "Apple", "iPad Pro", Decimal(799.99), "tablet"),
        
        // Furniture
        ("Sofa", "3-Seater Leather Sofa", "West Elm", "Hamilton", Decimal(2199.99), "sofa"),
        ("Dining Table", "Solid Wood Dining Table", "Pottery Barn", "Banks", Decimal(1899.99), "dining-table"),
        ("Bed Frame", "King Size Platform Bed", "Article", "Timber", Decimal(1299.99), "bed-frame"),
        
        // Sports Equipment
        ("Treadmill", "Smart Treadmill", "Peloton", "Tread+", Decimal(4295.00), "treadmill"),
        ("Bicycle", "Mountain Bike", "Trek", "Fuel EX 8", Decimal(3299.99), "bicycle"),
        ("Weight Set", "Adjustable Dumbbells", "Bowflex", "SelectTech 552", Decimal(399.99), "weight-set"),
        
        // Tools
        ("Power Drill", "20V Cordless Drill", "DeWalt", "DCD777C2", Decimal(159.99), "power-drill"),
        ("Table Saw", "10-inch Table Saw", "Bosch", "4100XC-10", Decimal(599.99), "table-saw"),
        ("Tool Chest", "Heavy-Duty Tool Storage", "Husky", "H52CH6TR9", Decimal(499.99), "tool-chest"),
        
        // Art & Decor
        ("Canvas Print", "Large Abstract Art", "West Elm", "Summer Sky", Decimal(299.99), "canvas-print"),
        ("Area Rug", "8x10 Wool Rug", "Safavieh", "Persian", Decimal(899.99), "area-rug"),
        ("Floor Lamp", "Modern Arc Lamp", "CB2", "Big Dipper", Decimal(299.99), "floor-lamp"),
        
        // Additional Electronics
        ("Smart TV", "55-inch QLED", "Samsung", "QN55Q80B", Decimal(997.99), "smart-tv"),
        ("Sound Bar", "3.1 Channel", "Sonos", "Arc", Decimal(899.99), "sound-bar"),
        ("Wireless Router", "Mesh WiFi System", "Google", "Nest WiFi", Decimal(349.99), "wireless-router"),
        
        // Additional Kitchen Items
        ("Espresso Machine", "Semi-Automatic", "Breville", "Barista Express", Decimal(699.99), "espresso-machine"),
        ("Food Processor", "14-Cup", "Cuisinart", "DFP-14BCNY", Decimal(229.99), "food-processor"),
        ("Wine Fridge", "28 Bottle", "Wine Enthusiast", "Classic", Decimal(399.99), "wine-fridge"),
        
        // Additional Furniture
        ("Bookshelf", "5-Tier Bookcase", "Crate & Barrel", "Anderson", Decimal(499.99), "bookshelf"),
        ("TV Stand", "Media Console", "Pottery Barn", "Griffin", Decimal(899.99), "tv-stand"),
        ("Office Desk", "L-Shaped Desk", "Fully", "Jarvis L", Decimal(795.00), "office-desk"),
        
        // Outdoor Items
        ("Grill", "Gas Grill", "Weber", "Genesis II", Decimal(999.99), "grill"),
        ("Patio Set", "4-Piece Furniture Set", "Hampton Bay", "Laguna", Decimal(799.99), "patio-set"),
        ("Fire Pit", "Wood Burning", "Solo Stove", "Bonfire", Decimal(399.99), "fire-pit"),
        
        // Musical Instruments
        ("Digital Piano", "88-Key Digital Piano", "Roland", "FP-90X", Decimal(1899.99), "digital-piano"),
        ("Bass Guitar", "4-String Electric Bass", "Fender", "Precision", Decimal(1499.99), "bass-guitar"),
        ("Drum Kit", "5-Piece Acoustic Kit", "Pearl", "Export", Decimal(699.99), "drum-kit"),
        
        // Home Office
        ("Monitor", "27-inch 4K Display", "LG", "27UK850-W", Decimal(449.99), "monitor"),
        ("Printer", "Color LaserJet", "HP", "M479fdw", Decimal(449.99), "printer"),
        ("Webcam", "4K Webcam", "Logitech", "Brio", Decimal(199.99), "webcam"),
        
        // Storage & Organization
        ("Filing Cabinet", "3-Drawer Cabinet", "HON", "H320", Decimal(299.99), "filing-cabinet"),
        ("Storage Bench", "Entryway Bench", "Threshold", "Carson", Decimal(199.99), "storage-bench"),
        ("Closet System", "Walk-in Closet Kit", "ClosetMaid", "Suite Symphony", Decimal(499.99), "closet-system"),
        
        // Appliances
        ("Washer", "Front Load Washer", "LG", "WM4000HBA", Decimal(999.99), "washer"),
        ("Dryer", "Electric Dryer", "LG", "DLEX4000B", Decimal(999.99), "dryer"),
        ("Dishwasher", "Stainless Steel", "Bosch", "SHPM88Z75N", Decimal(1099.99), "dishwasher"),
        
        // Entertainment
        ("Record Player", "Bluetooth Turntable", "Audio-Technica", "AT-LP120XBT", Decimal(349.99), "record-player"),
        ("Board Game Collection", "Classic Board Games Set", "Various", "Classics", Decimal(199.99), "board-games"),
        ("Projector", "4K Home Theater", "Epson", "5050UB", Decimal(2999.99), "projector"),
        
        // Lighting
        ("Chandelier", "Crystal Chandelier", "Pottery Barn", "Clarissa", Decimal(799.99), "chandelier"),
        ("Table Lamp Set", "Ceramic Table Lamps", "West Elm", "Asymmetry", Decimal(299.99), "table-lamp"),
        ("Smart Bulbs", "Color Changing Set", "Philips", "Hue", Decimal(199.99), "smart-bulbs")
    ]
    
    // Helper method to load test data into SwiftData
    static func loadTestData(context: ModelContext) async {
        // Create home
        let home = Home()
        home.address1 = homes[0].address1
        home.data = loadTestImage(category: "homes", filename: homes[0].imageName)
        context.insert(home)
        
        // Create locations
        let inventoryLocations = locations.map { locationData -> InventoryLocation in
            let location = InventoryLocation()
            location.name = locationData.name
            location.desc = locationData.desc
            location.data = loadTestImage(category: "locations", filename: locationData.imageName)
            return location
        }
        
        // Create labels with system colors
        let inventoryLabels = labels.map { labelData -> InventoryLabel in
            InventoryLabel(
                name: labelData.name,
                desc: labelData.desc,
                color: labelData.color
            )
        }
        
        // Create items
        for (index, itemData) in items.enumerated() {
            let location = inventoryLocations[index % inventoryLocations.count]
            let label = inventoryLabels[index % inventoryLabels.count]
            
            let item = InventoryItem(
                title: itemData.title,
                quantityString: "1",
                quantityInt: 1,
                desc: itemData.desc,
                serial: "SN\(index + 1000)",
                model: itemData.model,
                make: itemData.make,
                location: location,
                label: label,
                price: itemData.price,
                insured: false,
                assetId: "",
                notes: "",
                showInvalidQuantityAlert: false
            )
            
            item.data = loadTestImage(category: "items", filename: itemData.imageName)
            context.insert(item)
        }
    }
}
