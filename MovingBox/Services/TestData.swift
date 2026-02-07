//
//  TestData.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Foundation
import UIKit

@MainActor
struct TestData {
    // Sample homes with local image paths
    static let homes:
        [(name: String, address1: String, city: String, state: String, imageName: String, isPrimary: Bool)] = [
            ("Main House", "123 Main Street", "Portland", "OR", "craftsman-home", true),
            ("Beach House", "456 Ocean Drive", "Malibu", "CA", "beach-house", false),
        ]

    // Sample locations with local image paths, SF Symbols, and home index
    // homeIndex: 0 = Main House, 1 = Beach House
    static let locations: [(name: String, desc: String, imageName: String, sfSymbol: String, homeIndex: Int)] = [
        // Main House locations
        ("Living Room", "Main living area with fireplace", "living-room", "sofa.fill", 0),
        ("Master Bedroom", "Primary bedroom suite", "master-bedroom", "bed.double.fill", 0),
        ("Kitchen", "Modern kitchen with island", "kitchen", "fork.knife", 0),
        ("Home Office", "Work from home setup", "home-office", "desktopcomputer", 0),
        ("Garage", "Two-car garage with storage", "garage", "door.garage.closed", 0),
        ("Basement", "Finished basement with storage", "basement", "building.columns.fill", 0),
        // Beach House locations
        ("Beach Living Room", "Open concept living with ocean views", "beach-living-room", "sofa.fill", 1),
        ("Beach Bedroom", "Master suite with balcony", "beach-bedroom", "bed.double.fill", 1),
        ("Beach Kitchen", "Coastal kitchen with breakfast bar", "beach-kitchen", "fork.knife", 1),
        ("Deck", "Outdoor entertaining space", "beach-deck", "sun.max.fill", 1),
    ]

    // Default rooms for first launch with SFSymbol icons
    static let defaultRooms: [(name: String, desc: String, sfSymbol: String)] = [
        ("Living Room", "Main living and entertainment area", "sofa.fill"),
        ("Kitchen", "Cooking and dining area", "fork.knife"),
        ("Master Bedroom", "Primary bedroom", "bed.double.fill"),
        ("Bedroom", "Additional bedroom", "bed.double"),
        ("Bathroom", "Bathroom facilities", "shower.fill"),
        ("Home Office", "Work and study space", "desktopcomputer"),
        ("Garage", "Vehicle and tool storage", "door.garage.closed"),
        ("Basement", "Lower level storage and utility", "building.columns.fill"),
        ("Attic", "Upper level storage", "house.lodge.fill"),
        ("Dining Room", "Formal dining area", "table.furniture.fill"),
        ("Laundry Room", "Washing and drying space", "washer.fill"),
        ("Closet", "Storage closet", "cabinet.fill"),
    ]

    // Sample labels with softer, more pleasing colors and emojis
    static let labels: [(name: String, desc: String, color: UIColor, emoji: String)] = [
        (
            "Electronics", "Computers, phones, and gadgets",
            UIColor(red: 0.95, green: 0.61, blue: 0.61, alpha: 1.0), "📱"
        ),  // Soft red
        (
            "Furniture", "Chairs, tables, and storage",
            UIColor(red: 0.82, green: 0.71, blue: 0.55, alpha: 1.0), "🪑"
        ),  // Warm beige
        (
            "Kitchen", "Appliances and cookware", UIColor(red: 0.73, green: 0.87, blue: 0.68, alpha: 1.0),
            "🍳"
        ),  // Sage green
        ("Books", "Books and magazines", UIColor(red: 0.67, green: 0.84, blue: 0.90, alpha: 1.0), "📚"),  // Powder blue
        (
            "Art", "Paintings and decorative items",
            UIColor(red: 0.85, green: 0.75, blue: 0.86, alpha: 1.0), "🎨"
        ),  // Soft lavender
        (
            "Tools", "Hand tools and power tools",
            UIColor(red: 0.80, green: 0.80, blue: 0.83, alpha: 1.0), "🔧"
        ),  // Cool gray
        (
            "Sports", "Exercise and sports equipment",
            UIColor(red: 0.96, green: 0.76, blue: 0.56, alpha: 1.0), "🏀"
        ),  // Peach
        (
            "Clothing", "Clothes and accessories",
            UIColor(red: 0.69, green: 0.88, blue: 0.90, alpha: 1.0), "👕"
        ),  // Light teal
        // Additional labels
        (
            "Jewelry", "Watches, necklaces, and rings",
            UIColor(red: 0.90, green: 0.85, blue: 0.60, alpha: 1.0), "💍"
        ),  // Pale gold
        (
            "Documents", "Important papers and files",
            UIColor(red: 0.87, green: 0.87, blue: 0.87, alpha: 1.0), "📄"
        ),  // Light gray
        (
            "Collectibles", "Figurines, stamps, and memorabilia",
            UIColor(red: 0.78, green: 0.70, blue: 0.84, alpha: 1.0), "🏆"
        ),  // Medium purple
        (
            "Seasonal", "Holiday decorations and items",
            UIColor(red: 0.92, green: 0.70, blue: 0.70, alpha: 1.0), "🎄"
        ),  // Light coral
        (
            "Bathroom", "Towels, toiletries, and accessories",
            UIColor(red: 0.65, green: 0.85, blue: 0.85, alpha: 1.0), "🚿"
        ),  // Light cyan
        (
            "Toys", "Children's toys and games", UIColor(red: 0.94, green: 0.82, blue: 0.65, alpha: 1.0),
            "🧸"
        ),  // Light orange
        (
            "Gardening", "Plants, pots, and garden tools",
            UIColor(red: 0.60, green: 0.80, blue: 0.60, alpha: 1.0), "🌱"
        ),  // Medium green
        (
            "Technology", "Chargers, cables, and accessories",
            UIColor(red: 0.75, green: 0.75, blue: 0.95, alpha: 1.0), "💻"
        ),  // Periwinkle
        (
            "Memorabilia", "Personal mementos and keepsakes",
            UIColor(red: 0.85, green: 0.80, blue: 0.70, alpha: 1.0), "🎞️"
        ),  // Light tan
        (
            "Pet Supplies", "Pet food, toys, and accessories",
            UIColor(red: 0.80, green: 0.90, blue: 0.75, alpha: 1.0), "🐾"
        ),  // Mint green
        (
            "Media", "DVDs, CDs, and physical media",
            UIColor(red: 0.70, green: 0.65, blue: 0.75, alpha: 1.0), "💿"
        ),  // Muted purple
        (
            "Decorative", "Home decor and ornamental items",
            UIColor(red: 0.90, green: 0.80, blue: 0.90, alpha: 1.0), "🏺"
        ),  // Light pink
    ]

    // Sample inventory items with local image paths
    // homeIndex: 0 = Main House, 1 = Beach House
    static let items:
        [(
            title: String, desc: String, make: String, model: String, price: Decimal, imageName: String,
            location: String, label: String, homeIndex: Int
        )] = [
            // Main House items (homeIndex: 0)
            (
                "MacBook Pro", "16-inch 2023 Model", "Apple", "MacBook Pro M2", Decimal(2499.99), "macbook",
                "Home Office", "Electronics", 0
            ),
            (
                "OLED TV", "65-inch 4K Smart TV", "LG", "OLED65C1", Decimal(1999.99), "tv", "Living Room",
                "Electronics", 0
            ),
            (
                "Coffee Maker", "Programmable 12-cup", "Cuisinart", "DCC-3200", Decimal(99.99),
                "coffee-maker", "Kitchen", "Kitchen", 0
            ),
            (
                "Desk Chair", "Ergonomic Office Chair", "Herman Miller", "Aeron", Decimal(1095.00),
                "desk-chair", "Home Office", "Furniture", 0
            ),

            // Kitchen Items
            (
                "Stand Mixer", "Professional 5Qt Mixer", "KitchenAid", "Pro 5", Decimal(399.99),
                "stand-mixer", "Kitchen", "Kitchen", 0
            ),
            (
                "Blender", "High-Performance Blender", "Vitamix", "5200", Decimal(449.99), "blender",
                "Kitchen", "Kitchen", 0
            ),
            (
                "Air Fryer", "Digital Air Fryer", "Ninja", "AF101", Decimal(119.99), "air-fryer", "Kitchen",
                "Kitchen", 0
            ),

            // Electronics
            (
                "Gaming Console", "Next-gen gaming system", "Sony", "PlayStation 5", Decimal(499.99),
                "gaming-console", "Living Room", "Electronics", 0
            ),
            (
                "Smart Speaker", "Voice-controlled speaker", "Amazon", "Echo 4th Gen", Decimal(99.99),
                "smart-speaker", "Living Room", "Electronics", 0
            ),

            // Furniture
            (
                "Sofa", "3-Seater Leather Sofa", "West Elm", "Hamilton", Decimal(2199.99), "sofa",
                "Living Room", "Furniture", 0
            ),
            (
                "Dining Table", "Solid Wood Dining Table", "Pottery Barn", "Banks", Decimal(1899.99),
                "dining-table", "Living Room", "Furniture", 0
            ),
            (
                "Bed Frame", "King Size Platform Bed", "Article", "Timber", Decimal(1299.99), "bed-frame",
                "Master Bedroom", "Furniture", 0
            ),

            // Sports Equipment
            (
                "Treadmill", "Smart Treadmill", "Peloton", "Tread+", Decimal(4295.00), "treadmill",
                "Basement", "Sports", 0
            ),
            (
                "Weight Set", "Adjustable Dumbbells", "Bowflex", "SelectTech 552", Decimal(399.99),
                "weight-set", "Home Office", "Sports", 0
            ),

            // Tools
            (
                "Power Drill", "20V Cordless Drill", "DeWalt", "DCD777C2", Decimal(159.99), "power-drill",
                "Garage", "Tools", 0
            ),
            (
                "Table Saw", "10-inch Table Saw", "Bosch", "4100XC-10", Decimal(599.99), "table-saw",
                "Garage", "Tools", 0
            ),
            (
                "Tool Chest", "Heavy-Duty Tool Storage", "Husky", "H52CH6TR9", Decimal(499.99),
                "tool-chest", "Garage", "Tools", 0
            ),

            // Art & Decor
            (
                "Canvas Print", "Large Abstract Art", "West Elm", "Summer Sky", Decimal(299.99),
                "canvas-print", "Living Room", "Art", 0
            ),
            (
                "Area Rug", "8x10 Wool Rug", "Safavieh", "Persian", Decimal(899.99), "area-rug",
                "Living Room", "Furniture", 0
            ),
            (
                "Floor Lamp", "Modern Arc Lamp", "CB2", "Big Dipper", Decimal(299.99), "floor-lamp",
                "Living Room", "Furniture", 0
            ),

            // Additional Electronics
            (
                "Smart TV", "55-inch QLED", "Samsung", "QN55Q80B", Decimal(997.99), "smart-tv",
                "Living Room", "Electronics", 0
            ),
            (
                "Sound Bar", "3.1 Channel", "Sonos", "Arc", Decimal(899.99), "sound-bar", "Living Room",
                "Electronics", 0
            ),
            (
                "Wireless Router", "Mesh WiFi System", "Google", "Nest WiFi", Decimal(349.99),
                "wireless-router", "Home Office", "Electronics", 0
            ),

            // Additional Kitchen Items
            (
                "Espresso Machine", "Semi-Automatic", "Breville", "Barista Express", Decimal(699.99),
                "espresso-machine", "Kitchen", "Kitchen", 0
            ),
            (
                "Food Processor", "14-Cup", "Cuisinart", "DFP-14BCNY", Decimal(229.99), "food-processor",
                "Kitchen", "Kitchen", 0
            ),
            (
                "Wine Fridge", "28 Bottle", "Wine Enthusiast", "Classic", Decimal(399.99), "wine-fridge",
                "Kitchen", "Kitchen", 0
            ),

            // Additional Furniture
            (
                "Bookshelf", "5-Tier Bookcase", "Crate & Barrel", "Anderson", Decimal(499.99), "bookshelf",
                "Home Office", "Furniture", 0
            ),
            (
                "TV Stand", "Media Console", "Pottery Barn", "Griffin", Decimal(899.99), "tv-stand",
                "Living Room", "Furniture", 0
            ),
            (
                "Office Desk", "L-Shaped Desk", "Fully", "Jarvis L", Decimal(795.00), "office-desk",
                "Home Office", "Furniture", 0
            ),

            // Outdoor Items
            (
                "Grill", "Gas Grill", "Weber", "Genesis II", Decimal(999.99), "grill", "Garage", "Furniture", 0
            ),
            (
                "Patio Set", "4-Piece Furniture Set", "Hampton Bay", "Laguna", Decimal(799.99), "patio-set",
                "Garage", "Furniture", 0
            ),
            (
                "Fire Pit", "Wood Burning", "Solo Stove", "Bonfire", Decimal(399.99), "fire-pit", "Garage",
                "Furniture", 0
            ),

            // Musical Instruments
            (
                "Digital Piano", "88-Key Digital Piano", "Roland", "FP-90X", Decimal(1899.99),
                "digital-piano", "Living Room", "Collectibles", 0
            ),
            (
                "Saxophone", "Tenor sax by Jupiter", "Jupiter", "JTS700", Decimal(1499.99), "sax",
                "Living Room", "Collectibles", 0
            ),
            (
                "Drum Kit", "5-Piece Acoustic Kit", "Pearl", "Export", Decimal(699.99), "drum-kit",
                "Living Room", "Collectibles", 0
            ),

            // Home Office
            (
                "Monitor", "27-inch 4K Display", "LG", "27UK850-W", Decimal(449.99), "monitor",
                "Home Office", "Electronics", 0
            ),
            (
                "Printer", "Color LaserJet", "HP", "M479fdw", Decimal(449.99), "printer", "Home Office",
                "Electronics", 0
            ),
            (
                "Webcam", "4K Webcam", "Logitech", "Brio", Decimal(199.99), "webcam", "Home Office",
                "Electronics", 0
            ),

            // Storage & Organization
            (
                "Filing Cabinet", "3-Drawer Cabinet", "HON", "H320", Decimal(299.99), "filing-cabinet",
                "Home Office", "Furniture", 0
            ),
            (
                "Storage Bench", "Entryway Bench", "Threshold", "Carson", Decimal(199.99), "storage-bench",
                "Garage", "Furniture", 0
            ),
            (
                "Closet System", "Walk-in Closet Kit", "ClosetMaid", "Suite Symphony", Decimal(499.99),
                "closet-system", "Master Bedroom", "Furniture", 0
            ),

            // Appliances
            (
                "Washer", "Front Load Washer", "LG", "WM4000HBA", Decimal(999.99), "washer", "Basement",
                "Furniture", 0
            ),
            (
                "Dryer", "Electric Dryer", "LG", "DLEX4000B", Decimal(999.99), "dryer", "Basement",
                "Furniture", 0
            ),
            (
                "Dishwasher", "Stainless Steel", "Bosch", "SHPM88Z75N", Decimal(1099.99), "dishwasher",
                "Kitchen", "Kitchen", 0
            ),

            // Entertainment
            (
                "Record Player", "Bluetooth Turntable", "Audio-Technica", "AT-LP120XBT", Decimal(349.99),
                "record-player", "Living Room", "Art", 0
            ),
            (
                "Board Game Collection", "Classic Board Games Set", "Various", "Classics", Decimal(199.99),
                "board-games", "Living Room", "Art", 0
            ),
            (
                "Projector", "4K Home Theater", "Epson", "5050UB", Decimal(2999.99), "projector",
                "Living Room", "Electronics", 0
            ),

            // Lighting
            (
                "Chandelier", "Crystal Chandelier", "Pottery Barn", "Clarissa", Decimal(799.99),
                "chandelier", "Living Room", "Furniture", 0
            ),
            (
                "Table Lamp Set", "Ceramic Table Lamps", "West Elm", "Asymmetry", Decimal(299.99),
                "table-lamps", "Living Room", "Furniture", 0
            ),
            (
                "Smart Bulbs", "Color Changing Set", "Philips", "Hue", Decimal(199.99), "smart-bulbs",
                "Home Office", "Electronics", 0
            ),

            // Most recent items (Main House)
            (
                "Tablet", "11-inch Tablet", "Apple", "iPad Pro", Decimal(799.99), "tablet", "Living Room",
                "Electronics", 0
            ),
            (
                "Bicycle", "Mountain Bike", "Trek", "Fuel EX 8", Decimal(3299.99), "bicycle", "Garage",
                "Sports", 0
            ),
            (
                "Guitar", "Electric Guitar", "Gibson", "ES-335", Decimal(1499.99), "guitar", "Living Room",
                "Collectibles", 0
            ),

            // ============================================================
            // Additional Items from Downloaded Images (Main House)
            // ============================================================

            // Electronics
            (
                "iMac Desktop", "27-inch Retina 5K Display with Magic Keyboard and Mouse", "Apple", "iMac M3",
                Decimal(1999.99), "desktop-computer", "Home Office", "Electronics", 0
            ),
            (
                "iPad", "10.9-inch Space Gray with Apple Pencil", "Apple", "iPad 10th Gen",
                Decimal(449.99), "tablet", "Living Room", "Electronics", 0
            ),
            (
                "Over-Ear Headphones", "Wireless Noise-Canceling Headphones in White", "Sony", "WH-1000XM5",
                Decimal(349.99), "headphones", "Home Office", "Electronics", 0
            ),
            (
                "Mirrorless Camera", "Full-Frame Mirrorless Camera Body", "Canon", "EOS R6",
                Decimal(2499.99), "camera-dslr", "Home Office", "Electronics", 0
            ),
            (
                "Retro Gaming Console", "Classic 16-bit Console with Super Mario World", "Nintendo", "SNES",
                Decimal(199.99), "gaming-console", "Living Room", "Collectibles", 0
            ),
            (
                "Apple Watch", "GPS + Cellular with Black Sport Band", "Apple", "Watch Series 9",
                Decimal(499.99), "smart-watch", "Master Bedroom", "Electronics", 0
            ),
            (
                "WiFi 6 Router", "Dual-Band Wireless Router with External Antennas", "TP-Link", "Archer AX6000",
                Decimal(249.99), "router-wifi", "Home Office", "Electronics", 0
            ),

            // Kitchen Appliances
            (
                "Built-in Microwave", "Stainless Steel Over-the-Range Microwave", "Samsung", "ME21M706BAS",
                Decimal(449.99), "microwave", "Kitchen", "Kitchen", 0
            ),
            (
                "2-Slice Toaster", "Modern Black Toaster with Wide Slots", "Smeg", "TSF01BLUS",
                Decimal(169.99), "toaster", "Kitchen", "Kitchen", 0
            ),
            (
                "Knife Block Set", "5-Piece Stainless Steel Knives in Bamboo Magnetic Block", "Wüsthof", "Classic",
                Decimal(599.99), "knife-set", "Kitchen", "Kitchen", 0
            ),
            (
                "Cookware Set", "10-Piece Stainless Steel with Glass Lids", "All-Clad", "D3",
                Decimal(699.99), "pots-pans", "Kitchen", "Kitchen", 0
            ),
            (
                "Bamboo Cutting Board", "Large Cutting Board with Juice Groove", "Totally Bamboo", "Pro",
                Decimal(49.99), "cutting-board", "Kitchen", "Kitchen", 0
            ),
            (
                "Tea Kettle", "Classic Red Stovetop Kettle", "Le Creuset", "Classic",
                Decimal(99.99), "kettle-electric", "Kitchen", "Kitchen", 0
            ),

            // Furniture
            (
                "Velvet Armchair", "Classic Red Velvet Accent Chair with Gold Frame", "Jonathan Adler", "Bacharach",
                Decimal(1895.00), "armchair", "Living Room", "Furniture", 0
            ),
            (
                "Glass Coffee Table", "Brass and Glass Two-Tier Coffee Table", "Safavieh", "Couture",
                Decimal(899.99), "coffee-table", "Living Room", "Furniture", 0
            ),
            (
                "Bedside Table", "Modern Nightstand with Lamp and Storage", "West Elm", "Mid-Century",
                Decimal(399.99), "nightstand", "Master Bedroom", "Furniture", 0
            ),
            (
                "Vanity Dresser", "Mahogany Dresser with Mirror and Louvered Doors", "Ethan Allen", "British Classics",
                Decimal(2499.99), "dresser", "Master Bedroom", "Furniture", 0
            ),
            (
                "Walk-in Closet System", "Modern Black Closet with Oak Shelves and Hanging Rods", "California Closets",
                "Custom",
                Decimal(3500.00), "wardrobe", "Master Bedroom", "Furniture", 0
            ),
            (
                "Modern Dining Chairs", "Set of 2 Metal Frame Chairs with Canvas Seats", "CB2", "Rouka",
                Decimal(398.00), "dining-chairs", "Living Room", "Furniture", 0
            ),
            (
                "Library Bookcase", "Floor-to-Ceiling Wooden Bookshelf Filled with Books", "Restoration Hardware",
                "Library",
                Decimal(2995.00), "bookcase", "Home Office", "Furniture", 0
            ),
            (
                "Entryway Console", "Cherry Wood Console Table with Three Drawers", "Thomasville", "Bridges",
                Decimal(799.99), "console-table", "Living Room", "Furniture", 0
            ),

            // Home Decor
            (
                "Baroque Mirror", "Ornate Round Wall Mirror with Decorative Frame", "Howard Elliott", "Glendale",
                Decimal(449.99), "mirror-wall", "Living Room", "Decorative", 0
            ),
            (
                "Chinese Vases", "Pair of Blue and White Porcelain Vases with Peony Design", "Oriental Furniture",
                "Ming",
                Decimal(599.99), "vase-ceramic", "Living Room", "Decorative", 0
            ),
            (
                "Landscape Painting", "Autumn Lake Scene in Ornate Gold Frame", "Local Artist", "Birch Lake",
                Decimal(350.00), "picture-frame", "Living Room", "Art", 0
            ),
            (
                "Throw Blanket", "Gray and White Floral Pattern Fringed Throw", "Anthropologie", "Woven",
                Decimal(128.00), "throw-blanket", "Living Room", "Decorative", 0
            ),
            (
                "Decorative Pillows", "Set of 4 Teal and Orange Paisley Throw Pillows", "World Market", "Boho",
                Decimal(89.99), "decorative-pillows", "Living Room", "Decorative", 0
            ),
            (
                "Candle Holder", "Gold Multi-Tier Tealight Candle Holder", "West Elm", "Sculptural",
                Decimal(79.99), "candle-holder", "Living Room", "Decorative", 0
            ),
            (
                "Calathea Plant", "Orbifolia Prayer Plant in Terracotta Pot", "The Sill", "Live Plant",
                Decimal(65.00), "plant-indoor", "Living Room", "Decorative", 0
            ),

            // Bedroom Items
            (
                "Platform Bed", "Upholstered King Bed with Tan Linen Frame", "Article", "Tessu",
                Decimal(1599.00), "mattress", "Master Bedroom", "Furniture", 0
            ),
            (
                "Duvet Set", "Peach Linen Duvet Cover and Pillow Shams", "Brooklinen", "Luxe",
                Decimal(299.99), "bedding-set", "Master Bedroom", "Decorative", 0
            ),
            (
                "Ceramic Table Lamp", "Gray Ceramic Base with Linen Drum Shade", "Pottery Barn", "Pratt",
                Decimal(199.99), "lamp-bedside", "Master Bedroom", "Furniture", 0
            ),

            // Bathroom
            (
                "Spa Towel Set", "White Cotton Bath Towels with Blue Toiletry Bottle", "Frontgate", "Resort",
                Decimal(149.99), "towel-set", "Master Bedroom", "Bathroom", 0
            ),

            // Tools & Garage
            (
                "Portable Toolbox", "Black Plastic Tool Box with Orange Handle Tools", "DeWalt", "TSTAK",
                Decimal(79.99), "toolbox", "Garage", "Tools", 0
            ),
            (
                "Step Ladder", "Aluminum Folding Step Ladder", "Werner", "3-Step",
                Decimal(89.99), "ladder", "Garage", "Tools", 0
            ),
            (
                "Riding Lawn Mower", "Black Lawn Tractor with 42-inch Deck", "Yard Machines", "420cc",
                Decimal(1499.99), "lawn-mower", "Garage", "Tools", 0
            ),
            (
                "Cordless Vacuum", "Rose Gold Stick Vacuum with Wall Mount", "Staubheld", "V12",
                Decimal(299.99), "vacuum-cleaner", "Basement", "Furniture", 0
            ),

            // ============================================================
            // Beach House items (homeIndex: 1)
            // ============================================================

            // Beach Living Room
            (
                "Beach Sofa", "Coastal 3-Seater Sectional", "Pottery Barn", "York Slope", Decimal(3499.99),
                "sofa", "Beach Living Room", "Furniture", 1
            ),
            (
                "Beach TV", "55-inch 4K Smart TV", "Samsung", "Frame TV", Decimal(1299.99), "smart-tv",
                "Beach Living Room", "Electronics", 1
            ),
            (
                "Beach Coffee Table", "Driftwood Coffee Table", "West Elm", "Anton", Decimal(599.99),
                "dining-table", "Beach Living Room", "Furniture", 1
            ),
            (
                "Surfboard", "Longboard Surfboard", "Wavestorm", "Classic", Decimal(199.99),
                "bicycle", "Beach Living Room", "Sports", 1
            ),

            // Beach Bedroom
            (
                "Beach Bed Frame", "Canopy Bed Frame", "CB2", "Montevideo", Decimal(1899.99), "bed-frame",
                "Beach Bedroom", "Furniture", 1
            ),
            (
                "Beach Nightstand", "Rattan Nightstand Set", "Serena & Lily", "Balboa", Decimal(498.00),
                "tv-stand", "Beach Bedroom", "Furniture", 1
            ),

            // Beach Kitchen
            (
                "Beach Blender", "Personal Blender", "Ninja", "Nutri Pro", Decimal(79.99), "blender",
                "Beach Kitchen", "Kitchen", 1
            ),
            (
                "Beach Coffee Maker", "Single Serve Coffee", "Keurig", "K-Elite", Decimal(149.99),
                "coffee-maker", "Beach Kitchen", "Kitchen", 1
            ),

            // Deck
            (
                "Beach Grill", "Portable Gas Grill", "Weber", "Q2200", Decimal(299.99), "grill",
                "Deck", "Furniture", 1
            ),
            (
                "Beach Chairs", "Adirondack Chair Set", "Polywood", "Classic", Decimal(598.00),
                "patio-set", "Deck", "Furniture", 1
            ),
            (
                "Beach Umbrella", "Cantilever Patio Umbrella", "Treasure Garden", "AKZ", Decimal(699.99),
                "fire-pit", "Deck", "Furniture", 1
            ),
            (
                "Kayak", "Sit-On-Top Kayak", "Perception", "Pescador 12", Decimal(699.99),
                "bicycle", "Deck", "Sports", 1
            ),
        ]

}

// MARK: - Deterministic UUIDs for production default seed data

/// Fixed UUIDs for the default home, rooms, and labels created on first launch.
///
/// **CloudKit Sync Rationale**: When a user reinstalls or sets up a new device,
/// CloudKit will deliver previously-synced default records. If the app also seeds
/// new defaults with random UUIDs, duplicates appear. Fixed IDs let the local
/// insert and the synced record share the same primary key, merging cleanly.
///
/// The `AAAAAAAA` prefix distinguishes production defaults from the debug-only
/// `SeedID` enum in `TestSeedDatabase.swift` (which uses `00000000`).
/// Second UUID group encodes entity type: 0001 = home, 0002 = room, 0003 = label.
enum DefaultSeedID {

    // MARK: - Home

    static let home = UUID(uuidString: "AAAAAAAA-0001-0000-0000-000000000001")!

    // MARK: - Rooms (12, ordered to match TestData.defaultRooms)

    static let roomIDs: [UUID] = [
        UUID(uuidString: "AAAAAAAA-0002-0000-0000-000000000001")!,  // Living Room
        UUID(uuidString: "AAAAAAAA-0002-0000-0000-000000000002")!,  // Kitchen
        UUID(uuidString: "AAAAAAAA-0002-0000-0000-000000000003")!,  // Master Bedroom
        UUID(uuidString: "AAAAAAAA-0002-0000-0000-000000000004")!,  // Bedroom
        UUID(uuidString: "AAAAAAAA-0002-0000-0000-000000000005")!,  // Bathroom
        UUID(uuidString: "AAAAAAAA-0002-0000-0000-000000000006")!,  // Home Office
        UUID(uuidString: "AAAAAAAA-0002-0000-0000-000000000007")!,  // Garage
        UUID(uuidString: "AAAAAAAA-0002-0000-0000-000000000008")!,  // Basement
        UUID(uuidString: "AAAAAAAA-0002-0000-0000-000000000009")!,  // Attic
        UUID(uuidString: "AAAAAAAA-0002-0000-0000-00000000000A")!,  // Dining Room
        UUID(uuidString: "AAAAAAAA-0002-0000-0000-00000000000B")!,  // Laundry Room
        UUID(uuidString: "AAAAAAAA-0002-0000-0000-00000000000C")!,  // Closet
    ]

    // MARK: - Labels (20, ordered to match TestData.labels)

    static let labelIDs: [UUID] = [
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000001")!,  // Electronics
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000002")!,  // Furniture
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000003")!,  // Kitchen
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000004")!,  // Books
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000005")!,  // Art
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000006")!,  // Tools
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000007")!,  // Sports
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000008")!,  // Clothing
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000009")!,  // Jewelry
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-00000000000A")!,  // Documents
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-00000000000B")!,  // Collectibles
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-00000000000C")!,  // Seasonal
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-00000000000D")!,  // Bathroom
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-00000000000E")!,  // Toys
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-00000000000F")!,  // Gardening
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000010")!,  // Technology
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000011")!,  // Memorabilia
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000012")!,  // Pet Supplies
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000013")!,  // Media
        UUID(uuidString: "AAAAAAAA-0003-0000-0000-000000000014")!,  // Decorative
    ]
}
