#if DEBUG
    import Foundation
    import SQLiteData
    import UIKit

    // MARK: - Deterministic UUIDs for seed data

    /// Fixed UUIDs for test seed data, enabling deterministic cross-references.
    enum SeedID {
        // Homes
        static let mainHome = UUID(uuidString: "00000000-0001-0000-0000-000000000001")!
        static let beachHome = UUID(uuidString: "00000000-0001-0000-0000-000000000002")!

        // Locations — Main House
        static let livingRoom = UUID(uuidString: "00000000-0002-0000-0000-000000000001")!
        static let masterBedroom = UUID(uuidString: "00000000-0002-0000-0000-000000000002")!
        static let kitchen = UUID(uuidString: "00000000-0002-0000-0000-000000000003")!
        static let homeOffice = UUID(uuidString: "00000000-0002-0000-0000-000000000004")!
        static let garage = UUID(uuidString: "00000000-0002-0000-0000-000000000005")!
        static let basement = UUID(uuidString: "00000000-0002-0000-0000-000000000006")!

        // Locations — Beach House
        static let beachLivingRoom = UUID(uuidString: "00000000-0002-0000-0000-000000000007")!
        static let beachBedroom = UUID(uuidString: "00000000-0002-0000-0000-000000000008")!
        static let beachKitchen = UUID(uuidString: "00000000-0002-0000-0000-000000000009")!
        static let deck = UUID(uuidString: "00000000-0002-0000-0000-00000000000A")!

        // Labels
        static let electronics = UUID(uuidString: "00000000-0003-0000-0000-000000000001")!
        static let furniture = UUID(uuidString: "00000000-0003-0000-0000-000000000002")!
        static let kitchenLabel = UUID(uuidString: "00000000-0003-0000-0000-000000000003")!
        static let books = UUID(uuidString: "00000000-0003-0000-0000-000000000004")!
        static let art = UUID(uuidString: "00000000-0003-0000-0000-000000000005")!
        static let tools = UUID(uuidString: "00000000-0003-0000-0000-000000000006")!
        static let sports = UUID(uuidString: "00000000-0003-0000-0000-000000000007")!
        static let clothing = UUID(uuidString: "00000000-0003-0000-0000-000000000008")!
        static let jewelry = UUID(uuidString: "00000000-0003-0000-0000-000000000009")!
        static let documents = UUID(uuidString: "00000000-0003-0000-0000-00000000000A")!
        static let collectibles = UUID(uuidString: "00000000-0003-0000-0000-00000000000B")!
        static let seasonal = UUID(uuidString: "00000000-0003-0000-0000-00000000000C")!
        static let bathroom = UUID(uuidString: "00000000-0003-0000-0000-00000000000D")!
        static let toys = UUID(uuidString: "00000000-0003-0000-0000-00000000000E")!
        static let gardening = UUID(uuidString: "00000000-0003-0000-0000-00000000000F")!
        static let technology = UUID(uuidString: "00000000-0003-0000-0000-000000000010")!
        static let memorabilia = UUID(uuidString: "00000000-0003-0000-0000-000000000011")!
        static let petSupplies = UUID(uuidString: "00000000-0003-0000-0000-000000000012")!
        static let media = UUID(uuidString: "00000000-0003-0000-0000-000000000013")!
        static let decorative = UUID(uuidString: "00000000-0003-0000-0000-000000000014")!

        // Items — sequential UUIDs for all 68 items
        static func item(_ n: Int) -> UUID {
            UUID(uuidString: String(format: "00000000-0004-0000-0000-%012X", n))!
        }

        // Item-Label joins — sequential UUIDs
        static func itemLabel(_ n: Int) -> UUID {
            UUID(uuidString: String(format: "00000000-0005-0000-0000-%012X", n))!
        }

        // Item Photos — sequential UUIDs
        static func itemPhoto(_ n: Int) -> UUID {
            UUID(uuidString: String(format: "00000000-0006-0000-0000-%012X", n))!
        }
    }

    // MARK: - Seed database factory

    /// Creates an in-memory database pre-populated with test data.
    /// Called from `prepareDependencies` in `init()` so data is available
    /// before any `@FetchAll` observer subscribes.
    func makeSeededTestDatabase() throws -> DatabaseQueue {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let db = try DatabaseQueue(configuration: configuration)

        var migrator = DatabaseMigrator()
        registerMigrations(&migrator)
        try migrator.migrate(db)

        try db.write { db in
            try db.seed {
                // ─────────────────────────────────────────────
                // MARK: Homes
                // ─────────────────────────────────────────────
                SQLiteHome(
                    id: SeedID.mainHome, name: "Main House",
                    address1: "123 Main Street", city: "Portland", state: "OR",
                    isPrimary: true
                )
                SQLiteHome(
                    id: SeedID.beachHome, name: "Beach House",
                    address1: "456 Ocean Drive", city: "Malibu", state: "CA"
                )

                // ─────────────────────────────────────────────
                // MARK: Labels (20)
                // ─────────────────────────────────────────────
                SQLiteInventoryLabel(
                    id: SeedID.electronics, name: "Electronics",
                    desc: "Computers, phones, and gadgets",
                    color: UIColor(red: 0.95, green: 0.61, blue: 0.61, alpha: 1.0), emoji: "📱"
                )
                SQLiteInventoryLabel(
                    id: SeedID.furniture, name: "Furniture",
                    desc: "Chairs, tables, and storage",
                    color: UIColor(red: 0.82, green: 0.71, blue: 0.55, alpha: 1.0), emoji: "🪑"
                )
                SQLiteInventoryLabel(
                    id: SeedID.kitchenLabel, name: "Kitchen",
                    desc: "Appliances and cookware",
                    color: UIColor(red: 0.73, green: 0.87, blue: 0.68, alpha: 1.0), emoji: "🍳"
                )
                SQLiteInventoryLabel(
                    id: SeedID.books, name: "Books",
                    desc: "Books and magazines",
                    color: UIColor(red: 0.67, green: 0.84, blue: 0.90, alpha: 1.0), emoji: "📚"
                )
                SQLiteInventoryLabel(
                    id: SeedID.art, name: "Art",
                    desc: "Paintings and decorative items",
                    color: UIColor(red: 0.85, green: 0.75, blue: 0.86, alpha: 1.0), emoji: "🎨"
                )
                SQLiteInventoryLabel(
                    id: SeedID.tools, name: "Tools",
                    desc: "Hand tools and power tools",
                    color: UIColor(red: 0.80, green: 0.80, blue: 0.83, alpha: 1.0), emoji: "🔧"
                )
                SQLiteInventoryLabel(
                    id: SeedID.sports, name: "Sports",
                    desc: "Exercise and sports equipment",
                    color: UIColor(red: 0.96, green: 0.76, blue: 0.56, alpha: 1.0), emoji: "🏀"
                )
                SQLiteInventoryLabel(
                    id: SeedID.clothing, name: "Clothing",
                    desc: "Clothes and accessories",
                    color: UIColor(red: 0.69, green: 0.88, blue: 0.90, alpha: 1.0), emoji: "👕"
                )
                SQLiteInventoryLabel(
                    id: SeedID.jewelry, name: "Jewelry",
                    desc: "Watches, necklaces, and rings",
                    color: UIColor(red: 0.90, green: 0.85, blue: 0.60, alpha: 1.0), emoji: "💍"
                )
                SQLiteInventoryLabel(
                    id: SeedID.documents, name: "Documents",
                    desc: "Important papers and files",
                    color: UIColor(red: 0.87, green: 0.87, blue: 0.87, alpha: 1.0), emoji: "📄"
                )
                SQLiteInventoryLabel(
                    id: SeedID.collectibles, name: "Collectibles",
                    desc: "Figurines, stamps, and memorabilia",
                    color: UIColor(red: 0.78, green: 0.70, blue: 0.84, alpha: 1.0), emoji: "🏆"
                )
                SQLiteInventoryLabel(
                    id: SeedID.seasonal, name: "Seasonal",
                    desc: "Holiday decorations and items",
                    color: UIColor(red: 0.92, green: 0.70, blue: 0.70, alpha: 1.0), emoji: "🎄"
                )
                SQLiteInventoryLabel(
                    id: SeedID.bathroom, name: "Bathroom",
                    desc: "Towels, toiletries, and accessories",
                    color: UIColor(red: 0.65, green: 0.85, blue: 0.85, alpha: 1.0), emoji: "🚿"
                )
                SQLiteInventoryLabel(
                    id: SeedID.toys, name: "Toys",
                    desc: "Children's toys and games",
                    color: UIColor(red: 0.94, green: 0.82, blue: 0.65, alpha: 1.0), emoji: "🧸"
                )
                SQLiteInventoryLabel(
                    id: SeedID.gardening, name: "Gardening",
                    desc: "Plants, pots, and garden tools",
                    color: UIColor(red: 0.60, green: 0.80, blue: 0.60, alpha: 1.0), emoji: "🌱"
                )
                SQLiteInventoryLabel(
                    id: SeedID.technology, name: "Technology",
                    desc: "Chargers, cables, and accessories",
                    color: UIColor(red: 0.75, green: 0.75, blue: 0.95, alpha: 1.0), emoji: "💻"
                )
                SQLiteInventoryLabel(
                    id: SeedID.memorabilia, name: "Memorabilia",
                    desc: "Personal mementos and keepsakes",
                    color: UIColor(red: 0.85, green: 0.80, blue: 0.70, alpha: 1.0), emoji: "🎞️"
                )
                SQLiteInventoryLabel(
                    id: SeedID.petSupplies, name: "Pet Supplies",
                    desc: "Pet food, toys, and accessories",
                    color: UIColor(red: 0.80, green: 0.90, blue: 0.75, alpha: 1.0), emoji: "🐾"
                )
                SQLiteInventoryLabel(
                    id: SeedID.media, name: "Media",
                    desc: "DVDs, CDs, and physical media",
                    color: UIColor(red: 0.70, green: 0.65, blue: 0.75, alpha: 1.0), emoji: "💿"
                )
                SQLiteInventoryLabel(
                    id: SeedID.decorative, name: "Decorative",
                    desc: "Home decor and ornamental items",
                    color: UIColor(red: 0.90, green: 0.80, blue: 0.90, alpha: 1.0), emoji: "🏺"
                )

                // ─────────────────────────────────────────────
                // MARK: Locations (10)
                // ─────────────────────────────────────────────

                // Main House
                SQLiteInventoryLocation(
                    id: SeedID.livingRoom, name: "Living Room",
                    desc: "Main living area with fireplace",
                    sfSymbolName: "sofa.fill", homeID: SeedID.mainHome
                )
                SQLiteInventoryLocation(
                    id: SeedID.masterBedroom, name: "Master Bedroom",
                    desc: "Primary bedroom suite",
                    sfSymbolName: "bed.double.fill", homeID: SeedID.mainHome
                )
                SQLiteInventoryLocation(
                    id: SeedID.kitchen, name: "Kitchen",
                    desc: "Modern kitchen with island",
                    sfSymbolName: "fork.knife", homeID: SeedID.mainHome
                )
                SQLiteInventoryLocation(
                    id: SeedID.homeOffice, name: "Home Office",
                    desc: "Work from home setup",
                    sfSymbolName: "desktopcomputer", homeID: SeedID.mainHome
                )
                SQLiteInventoryLocation(
                    id: SeedID.garage, name: "Garage",
                    desc: "Two-car garage with storage",
                    sfSymbolName: "door.garage.closed", homeID: SeedID.mainHome
                )
                SQLiteInventoryLocation(
                    id: SeedID.basement, name: "Basement",
                    desc: "Finished basement with storage",
                    sfSymbolName: "building.columns.fill", homeID: SeedID.mainHome
                )

                // Beach House
                SQLiteInventoryLocation(
                    id: SeedID.beachLivingRoom, name: "Beach Living Room",
                    desc: "Open concept living with ocean views",
                    sfSymbolName: "sofa.fill", homeID: SeedID.beachHome
                )
                SQLiteInventoryLocation(
                    id: SeedID.beachBedroom, name: "Beach Bedroom",
                    desc: "Master suite with balcony",
                    sfSymbolName: "bed.double.fill", homeID: SeedID.beachHome
                )
                SQLiteInventoryLocation(
                    id: SeedID.beachKitchen, name: "Beach Kitchen",
                    desc: "Coastal kitchen with breakfast bar",
                    sfSymbolName: "fork.knife", homeID: SeedID.beachHome
                )
                SQLiteInventoryLocation(
                    id: SeedID.deck, name: "Deck",
                    desc: "Outdoor entertaining space",
                    sfSymbolName: "sun.max.fill", homeID: SeedID.beachHome
                )

                // ─────────────────────────────────────────────
                // MARK: Items — Main House (56)
                // ─────────────────────────────────────────────

                // Home Office
                SQLiteInventoryItem(
                    id: SeedID.item(1), title: "MacBook Pro", desc: "16-inch 2023 Model",
                    model: "MacBook Pro M2", make: "Apple", price: 2499.99,
                    hasUsedAI: true, createdAt: date(-1),
                    condition: "New", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(2), title: "Desk Chair", desc: "Ergonomic Office Chair",
                    model: "Aeron", make: "Herman Miller", price: 1095.00,
                    hasUsedAI: true, createdAt: date(-2),
                    condition: "Like New", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(3), title: "iMac Desktop",
                    desc: "27-inch Retina 5K Display with Magic Keyboard and Mouse",
                    model: "iMac M3", make: "Apple", price: 1999.99,
                    hasUsedAI: true, createdAt: date(-3),
                    condition: "New", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(4), title: "Monitor", desc: "27-inch 4K Display",
                    model: "27UK850-W", make: "LG", price: 449.99,
                    hasUsedAI: true, createdAt: date(-4),
                    condition: "Good", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(5), title: "Printer", desc: "Color LaserJet",
                    model: "M479fdw", make: "HP", price: 449.99,
                    hasUsedAI: true, createdAt: date(-5),
                    condition: "Good", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(6), title: "Webcam", desc: "4K Webcam",
                    model: "Brio", make: "Logitech", price: 199.99,
                    hasUsedAI: true, createdAt: date(-6),
                    condition: "New", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(7), title: "Projector", desc: "4K Home Theater",
                    model: "5050UB", make: "Epson", price: 2999.99,
                    hasUsedAI: true, createdAt: date(-7),
                    condition: "New", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(8), title: "Filing Cabinet", desc: "3-Drawer Cabinet",
                    model: "H320", make: "HON", price: 299.99,
                    hasUsedAI: true, createdAt: date(-8),
                    condition: "Good", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(9), title: "Bookshelf", desc: "5-Tier Bookcase",
                    model: "Anderson", make: "Crate & Barrel", price: 499.99,
                    hasUsedAI: true, createdAt: date(-9),
                    condition: "Good", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(10), title: "Library Bookcase",
                    desc: "Floor-to-Ceiling Wooden Bookshelf Filled with Books",
                    model: "Library", make: "Restoration Hardware", price: 2995.00,
                    hasUsedAI: true, createdAt: date(-10),
                    condition: "Good", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(11), title: "Office Desk", desc: "L-Shaped Desk",
                    model: "Jarvis L", make: "Fully", price: 795.00,
                    hasUsedAI: true, createdAt: date(-11),
                    condition: "Like New", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(12), title: "Wireless Router", desc: "Mesh WiFi System",
                    model: "Nest WiFi", make: "Google", price: 349.99,
                    hasUsedAI: true, createdAt: date(-12),
                    condition: "Good", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(13), title: "WiFi 6 Router",
                    desc: "Dual-Band Wireless Router with External Antennas",
                    model: "Archer AX6000", make: "TP-Link", price: 249.99,
                    hasUsedAI: true, createdAt: date(-13),
                    condition: "New", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(14), title: "Smart Bulbs", desc: "Color Changing Set",
                    model: "Hue", make: "Philips", price: 199.99,
                    hasUsedAI: true, createdAt: date(-14),
                    condition: "New", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(15), title: "Weight Set", desc: "Adjustable Dumbbells",
                    model: "SelectTech 552", make: "Bowflex", price: 399.99,
                    hasUsedAI: true, createdAt: date(-15),
                    condition: "Good", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(16), title: "Over-Ear Headphones",
                    desc: "Wireless Noise-Canceling Headphones in White",
                    model: "WH-1000XM5", make: "Sony", price: 349.99,
                    hasUsedAI: true, createdAt: date(-16),
                    condition: "New", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(17), title: "Mirrorless Camera",
                    desc: "Full-Frame Mirrorless Camera Body",
                    model: "EOS R6", make: "Canon", price: 2499.99,
                    hasUsedAI: true, createdAt: date(-17),
                    condition: "Like New", locationID: SeedID.homeOffice, homeID: SeedID.mainHome
                )

                // Living Room
                SQLiteInventoryItem(
                    id: SeedID.item(18), title: "OLED TV", desc: "65-inch 4K Smart TV",
                    model: "OLED65C1", make: "LG", price: 1999.99,
                    hasUsedAI: true, createdAt: date(-18),
                    condition: "New", isFragile: true,
                    locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(19), title: "Gaming Console", desc: "Next-gen gaming system",
                    model: "PlayStation 5", make: "Sony", price: 499.99,
                    hasUsedAI: true, createdAt: date(-19),
                    condition: "New", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(20), title: "Smart Speaker", desc: "Voice-controlled speaker",
                    model: "Echo 4th Gen", make: "Amazon", price: 99.99,
                    hasUsedAI: true, createdAt: date(-20),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(21), title: "Sofa", desc: "3-Seater Leather Sofa",
                    model: "Hamilton", make: "West Elm", price: 2199.99,
                    hasUsedAI: true, createdAt: date(-21),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(22), title: "Dining Table", desc: "Solid Wood Dining Table",
                    model: "Banks", make: "Pottery Barn", price: 1899.99,
                    hasUsedAI: true, createdAt: date(-22),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(23), title: "Area Rug", desc: "8x10 Wool Rug",
                    model: "Persian", make: "Safavieh", price: 899.99,
                    hasUsedAI: true, createdAt: date(-23),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(24), title: "Floor Lamp", desc: "Modern Arc Lamp",
                    model: "Big Dipper", make: "CB2", price: 299.99,
                    hasUsedAI: true, createdAt: date(-24),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(25), title: "Smart TV", desc: "55-inch QLED",
                    model: "QN55Q80B", make: "Samsung", price: 997.99,
                    hasUsedAI: true, createdAt: date(-25),
                    condition: "New", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(26), title: "TV Stand", desc: "Media Console",
                    model: "Griffin", make: "Pottery Barn", price: 899.99,
                    hasUsedAI: true, createdAt: date(-26),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(27), title: "Velvet Armchair",
                    desc: "Classic Red Velvet Accent Chair with Gold Frame",
                    model: "Bacharach", make: "Jonathan Adler", price: 1895.00,
                    hasUsedAI: true, createdAt: date(-27),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(28), title: "Glass Coffee Table",
                    desc: "Brass and Glass Two-Tier Coffee Table",
                    model: "Couture", make: "Safavieh", price: 899.99,
                    hasUsedAI: true, createdAt: date(-28),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(29), title: "Chandelier", desc: "Crystal Chandelier",
                    model: "Clarissa", make: "Pottery Barn", price: 799.99,
                    hasUsedAI: true, createdAt: date(-29),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(30), title: "Table Lamp Set", desc: "Ceramic Table Lamps",
                    model: "Asymmetry", make: "West Elm", price: 299.99,
                    hasUsedAI: true, createdAt: date(-30),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(31), title: "Sound Bar", desc: "3.1 Channel",
                    model: "Arc", make: "Sonos", price: 899.99,
                    hasUsedAI: true, createdAt: date(-31),
                    condition: "New", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(32), title: "Tablet", desc: "11-inch Tablet",
                    model: "iPad Pro", make: "Apple", price: 799.99,
                    hasUsedAI: true, createdAt: date(-32),
                    condition: "New", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(33), title: "Record Player", desc: "Bluetooth Turntable",
                    model: "AT-LP120XBT", make: "Audio-Technica", price: 349.99,
                    hasUsedAI: true, createdAt: date(-33),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(34), title: "Board Game Collection",
                    desc: "Classic Board Games Set",
                    model: "Classics", make: "Various", price: 199.99,
                    hasUsedAI: true, createdAt: date(-34),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(35), title: "Canvas Print", desc: "Large Abstract Art",
                    model: "Summer Sky", make: "West Elm", price: 299.99,
                    hasUsedAI: true, createdAt: date(-35),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(36), title: "Digital Piano", desc: "88-Key Digital Piano",
                    model: "FP-90X", make: "Roland", price: 1899.99,
                    hasUsedAI: true, createdAt: date(-36),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(37), title: "Saxophone", desc: "Tenor sax by Jupiter",
                    model: "JTS700", make: "Jupiter", price: 1499.99,
                    hasUsedAI: true, createdAt: date(-37),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(38), title: "Drum Kit", desc: "5-Piece Acoustic Kit",
                    model: "Export", make: "Pearl", price: 699.99,
                    hasUsedAI: true, createdAt: date(-38),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(39), title: "iPad",
                    desc: "10.9-inch Space Gray with Apple Pencil",
                    model: "iPad 10th Gen", make: "Apple", price: 449.99,
                    hasUsedAI: true, createdAt: date(-39),
                    condition: "New", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(40), title: "Retro Gaming Console",
                    desc: "Classic 16-bit Console with Super Mario World",
                    model: "SNES", make: "Nintendo", price: 199.99,
                    hasUsedAI: true, createdAt: date(-40),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(41), title: "Modern Dining Chairs",
                    desc: "Set of 2 Metal Frame Chairs with Canvas Seats",
                    model: "Rouka", make: "CB2", price: 398.00,
                    hasUsedAI: true, createdAt: date(-41),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(42), title: "Entryway Console",
                    desc: "Cherry Wood Console Table with Three Drawers",
                    model: "Bridges", make: "Thomasville", price: 799.99,
                    hasUsedAI: true, createdAt: date(-42),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(43), title: "Baroque Mirror",
                    desc: "Ornate Round Wall Mirror with Decorative Frame",
                    model: "Glendale", make: "Howard Elliott", price: 449.99,
                    hasUsedAI: true, createdAt: date(-43),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(44), title: "Chinese Vases",
                    desc: "Pair of Blue and White Porcelain Vases with Peony Design",
                    model: "Ming", make: "Oriental Furniture", price: 599.99,
                    hasUsedAI: true, createdAt: date(-44),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(45), title: "Landscape Painting",
                    desc: "Autumn Lake Scene in Ornate Gold Frame",
                    model: "Birch Lake", make: "Local Artist", price: 350.00,
                    hasUsedAI: true, createdAt: date(-45),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(46), title: "Throw Blanket",
                    desc: "Gray and White Floral Pattern Fringed Throw",
                    model: "Woven", make: "Anthropologie", price: 128.00,
                    hasUsedAI: true, createdAt: date(-46),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(47), title: "Decorative Pillows",
                    desc: "Set of 4 Teal and Orange Paisley Throw Pillows",
                    model: "Boho", make: "World Market", price: 89.99,
                    hasUsedAI: true, createdAt: date(-47),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(48), title: "Candle Holder",
                    desc: "Gold Multi-Tier Tealight Candle Holder",
                    model: "Sculptural", make: "West Elm", price: 79.99,
                    hasUsedAI: true, createdAt: date(-48),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(49), title: "Calathea Plant",
                    desc: "Orbifolia Prayer Plant in Terracotta Pot",
                    model: "Live Plant", make: "The Sill", price: 65.00,
                    hasUsedAI: true, createdAt: date(-49),
                    condition: "Good", locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(50), title: "Guitar", desc: "Electric Guitar",
                    model: "ES-335", make: "Gibson", price: 1499.99,
                    hasUsedAI: true, createdAt: date(-50),
                    condition: "Good", isFragile: true,
                    locationID: SeedID.livingRoom, homeID: SeedID.mainHome
                )

                // Kitchen
                SQLiteInventoryItem(
                    id: SeedID.item(51), title: "Coffee Maker", desc: "Programmable 12-cup",
                    model: "DCC-3200", make: "Cuisinart", price: 99.99,
                    hasUsedAI: true, createdAt: date(-51),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(52), title: "Stand Mixer", desc: "Professional 5Qt Mixer",
                    model: "Pro 5", make: "KitchenAid", price: 399.99,
                    hasUsedAI: true, createdAt: date(-52),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(53), title: "Blender", desc: "High-Performance Blender",
                    model: "5200", make: "Vitamix", price: 449.99,
                    hasUsedAI: true, createdAt: date(-53),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(54), title: "Air Fryer", desc: "Digital Air Fryer",
                    model: "AF101", make: "Ninja", price: 119.99,
                    hasUsedAI: true, createdAt: date(-54),
                    condition: "New", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(55), title: "Espresso Machine", desc: "Semi-Automatic",
                    model: "Barista Express", make: "Breville", price: 699.99,
                    hasUsedAI: true, createdAt: date(-55),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(56), title: "Food Processor", desc: "14-Cup",
                    model: "DFP-14BCNY", make: "Cuisinart", price: 229.99,
                    hasUsedAI: true, createdAt: date(-56),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(57), title: "Wine Fridge", desc: "28 Bottle",
                    model: "Classic", make: "Wine Enthusiast", price: 399.99,
                    hasUsedAI: true, createdAt: date(-57),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(58), title: "Built-in Microwave",
                    desc: "Stainless Steel Over-the-Range Microwave",
                    model: "ME21M706BAS", make: "Samsung", price: 449.99,
                    hasUsedAI: true, createdAt: date(-58),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(59), title: "2-Slice Toaster",
                    desc: "Modern Black Toaster with Wide Slots",
                    model: "TSF01BLUS", make: "Smeg", price: 169.99,
                    hasUsedAI: true, createdAt: date(-59),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(60), title: "Knife Block Set",
                    desc: "5-Piece Stainless Steel Knives in Bamboo Magnetic Block",
                    model: "Classic", make: "Wüsthof", price: 599.99,
                    hasUsedAI: true, createdAt: date(-60),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(61), title: "Cookware Set",
                    desc: "10-Piece Stainless Steel with Glass Lids",
                    model: "D3", make: "All-Clad", price: 699.99,
                    hasUsedAI: true, createdAt: date(-61),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(62), title: "Bamboo Cutting Board",
                    desc: "Large Cutting Board with Juice Groove",
                    model: "Pro", make: "Totally Bamboo", price: 49.99,
                    hasUsedAI: true, createdAt: date(-62),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(63), title: "Tea Kettle",
                    desc: "Classic Red Stovetop Kettle",
                    model: "Classic", make: "Le Creuset", price: 99.99,
                    hasUsedAI: true, createdAt: date(-63),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(64), title: "Dishwasher", desc: "Stainless Steel",
                    model: "SHPM88Z75N", make: "Bosch", price: 1099.99,
                    hasUsedAI: true, createdAt: date(-64),
                    condition: "Good", locationID: SeedID.kitchen, homeID: SeedID.mainHome
                )

                // Master Bedroom
                SQLiteInventoryItem(
                    id: SeedID.item(65), title: "Bed Frame", desc: "King Size Platform Bed",
                    model: "Timber", make: "Article", price: 1299.99,
                    hasUsedAI: true, createdAt: date(-65),
                    condition: "Good", locationID: SeedID.masterBedroom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(66), title: "Closet System", desc: "Walk-in Closet Kit",
                    model: "Suite Symphony", make: "ClosetMaid", price: 499.99,
                    hasUsedAI: true, createdAt: date(-66),
                    condition: "Good", locationID: SeedID.masterBedroom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(67), title: "Bedside Table",
                    desc: "Modern Nightstand with Lamp and Storage",
                    model: "Mid-Century", make: "West Elm", price: 399.99,
                    hasUsedAI: true, createdAt: date(-67),
                    condition: "Good", locationID: SeedID.masterBedroom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(68), title: "Vanity Dresser",
                    desc: "Mahogany Dresser with Mirror and Louvered Doors",
                    model: "British Classics", make: "Ethan Allen", price: 2499.99,
                    hasUsedAI: true, createdAt: date(-68),
                    condition: "Good", locationID: SeedID.masterBedroom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(69), title: "Walk-in Closet System",
                    desc: "Modern Black Closet with Oak Shelves and Hanging Rods",
                    model: "Custom", make: "California Closets", price: 3500.00,
                    hasUsedAI: true, createdAt: date(-69),
                    condition: "Good", locationID: SeedID.masterBedroom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(70), title: "Platform Bed",
                    desc: "Upholstered King Bed with Tan Linen Frame",
                    model: "Tessu", make: "Article", price: 1599.00,
                    hasUsedAI: true, createdAt: date(-70),
                    condition: "Good", locationID: SeedID.masterBedroom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(71), title: "Ceramic Table Lamp",
                    desc: "Gray Ceramic Base with Linen Drum Shade",
                    model: "Pratt", make: "Pottery Barn", price: 199.99,
                    hasUsedAI: true, createdAt: date(-71),
                    condition: "Good", locationID: SeedID.masterBedroom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(72), title: "Apple Watch",
                    desc: "GPS + Cellular with Black Sport Band",
                    model: "Watch Series 9", make: "Apple", price: 499.99,
                    hasUsedAI: true, createdAt: date(-72),
                    condition: "New", locationID: SeedID.masterBedroom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(73), title: "Duvet Set",
                    desc: "Peach Linen Duvet Cover and Pillow Shams",
                    model: "Luxe", make: "Brooklinen", price: 299.99,
                    hasUsedAI: true, createdAt: date(-73),
                    condition: "New", locationID: SeedID.masterBedroom, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(74), title: "Spa Towel Set",
                    desc: "White Cotton Bath Towels with Blue Toiletry Bottle",
                    model: "Resort", make: "Frontgate", price: 149.99,
                    hasUsedAI: true, createdAt: date(-74),
                    condition: "Good", locationID: SeedID.masterBedroom, homeID: SeedID.mainHome
                )

                // Basement
                SQLiteInventoryItem(
                    id: SeedID.item(75), title: "Treadmill", desc: "Smart Treadmill",
                    model: "Tread+", make: "Peloton", price: 4295.00,
                    hasUsedAI: true, createdAt: date(-75),
                    condition: "Good", locationID: SeedID.basement, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(76), title: "Washer", desc: "Front Load Washer",
                    model: "WM4000HBA", make: "LG", price: 999.99,
                    hasUsedAI: true, createdAt: date(-76),
                    condition: "Good", locationID: SeedID.basement, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(77), title: "Dryer", desc: "Electric Dryer",
                    model: "DLEX4000B", make: "LG", price: 999.99,
                    hasUsedAI: true, createdAt: date(-77),
                    condition: "Good", locationID: SeedID.basement, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(78), title: "Cordless Vacuum",
                    desc: "Rose Gold Stick Vacuum with Wall Mount",
                    model: "V12", make: "Staubheld", price: 299.99,
                    hasUsedAI: true, createdAt: date(-78),
                    condition: "Good", locationID: SeedID.basement, homeID: SeedID.mainHome
                )

                // Garage
                SQLiteInventoryItem(
                    id: SeedID.item(79), title: "Power Drill", desc: "20V Cordless Drill",
                    model: "DCD777C2", make: "DeWalt", price: 159.99,
                    hasUsedAI: true, createdAt: date(-79),
                    condition: "Good", locationID: SeedID.garage, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(80), title: "Table Saw", desc: "10-inch Table Saw",
                    model: "4100XC-10", make: "Bosch", price: 599.99,
                    hasUsedAI: true, createdAt: date(-80),
                    condition: "Good", locationID: SeedID.garage, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(81), title: "Tool Chest", desc: "Heavy-Duty Tool Storage",
                    model: "H52CH6TR9", make: "Husky", price: 499.99,
                    hasUsedAI: true, createdAt: date(-81),
                    condition: "Good", locationID: SeedID.garage, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(82), title: "Grill", desc: "Gas Grill",
                    model: "Genesis II", make: "Weber", price: 999.99,
                    hasUsedAI: true, createdAt: date(-82),
                    condition: "Good", locationID: SeedID.garage, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(83), title: "Patio Set", desc: "4-Piece Furniture Set",
                    model: "Laguna", make: "Hampton Bay", price: 799.99,
                    hasUsedAI: true, createdAt: date(-83),
                    condition: "Good", locationID: SeedID.garage, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(84), title: "Fire Pit", desc: "Wood Burning",
                    model: "Bonfire", make: "Solo Stove", price: 399.99,
                    hasUsedAI: true, createdAt: date(-84),
                    condition: "Good", locationID: SeedID.garage, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(85), title: "Storage Bench", desc: "Entryway Bench",
                    model: "Carson", make: "Threshold", price: 199.99,
                    hasUsedAI: true, createdAt: date(-85),
                    condition: "Good", locationID: SeedID.garage, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(86), title: "Portable Toolbox",
                    desc: "Black Plastic Tool Box with Orange Handle Tools",
                    model: "TSTAK", make: "DeWalt", price: 79.99,
                    hasUsedAI: true, createdAt: date(-86),
                    condition: "Good", locationID: SeedID.garage, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(87), title: "Step Ladder",
                    desc: "Aluminum Folding Step Ladder",
                    model: "3-Step", make: "Werner", price: 89.99,
                    hasUsedAI: true, createdAt: date(-87),
                    condition: "Good", locationID: SeedID.garage, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(88), title: "Riding Lawn Mower",
                    desc: "Black Lawn Tractor with 42-inch Deck",
                    model: "420cc", make: "Yard Machines", price: 1499.99,
                    hasUsedAI: true, createdAt: date(-88),
                    condition: "Good", locationID: SeedID.garage, homeID: SeedID.mainHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(89), title: "Bicycle", desc: "Mountain Bike",
                    model: "Fuel EX 8", make: "Trek", price: 3299.99,
                    hasUsedAI: true, createdAt: date(-89),
                    condition: "Good", locationID: SeedID.garage, homeID: SeedID.mainHome
                )

                // ─────────────────────────────────────────────
                // MARK: Items — Beach House (12)
                // ─────────────────────────────────────────────

                SQLiteInventoryItem(
                    id: SeedID.item(90), title: "Beach Sofa",
                    desc: "Coastal 3-Seater Sectional",
                    model: "York Slope", make: "Pottery Barn", price: 3499.99,
                    hasUsedAI: true, createdAt: date(-90),
                    condition: "Good", locationID: SeedID.beachLivingRoom, homeID: SeedID.beachHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(91), title: "Beach TV", desc: "55-inch 4K Smart TV",
                    model: "Frame TV", make: "Samsung", price: 1299.99,
                    hasUsedAI: true, createdAt: date(-91),
                    condition: "New", locationID: SeedID.beachLivingRoom, homeID: SeedID.beachHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(92), title: "Beach Coffee Table",
                    desc: "Driftwood Coffee Table",
                    model: "Anton", make: "West Elm", price: 599.99,
                    hasUsedAI: true, createdAt: date(-92),
                    condition: "Good", locationID: SeedID.beachLivingRoom, homeID: SeedID.beachHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(93), title: "Surfboard", desc: "Longboard Surfboard",
                    model: "Classic", make: "Wavestorm", price: 199.99,
                    hasUsedAI: true, createdAt: date(-93),
                    condition: "Good", locationID: SeedID.beachLivingRoom, homeID: SeedID.beachHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(94), title: "Beach Bed Frame",
                    desc: "Canopy Bed Frame",
                    model: "Montevideo", make: "CB2", price: 1899.99,
                    hasUsedAI: true, createdAt: date(-94),
                    condition: "Good", locationID: SeedID.beachBedroom, homeID: SeedID.beachHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(95), title: "Beach Nightstand",
                    desc: "Rattan Nightstand Set",
                    model: "Balboa", make: "Serena & Lily", price: 498.00,
                    hasUsedAI: true, createdAt: date(-95),
                    condition: "Good", locationID: SeedID.beachBedroom, homeID: SeedID.beachHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(96), title: "Beach Blender",
                    desc: "Personal Blender",
                    model: "Nutri Pro", make: "Ninja", price: 79.99,
                    hasUsedAI: true, createdAt: date(-96),
                    condition: "Good", locationID: SeedID.beachKitchen, homeID: SeedID.beachHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(97), title: "Beach Coffee Maker",
                    desc: "Single Serve Coffee",
                    model: "K-Elite", make: "Keurig", price: 149.99,
                    hasUsedAI: true, createdAt: date(-97),
                    condition: "Good", locationID: SeedID.beachKitchen, homeID: SeedID.beachHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(98), title: "Beach Grill", desc: "Portable Gas Grill",
                    model: "Q2200", make: "Weber", price: 299.99,
                    hasUsedAI: true, createdAt: date(-98),
                    condition: "Good", locationID: SeedID.deck, homeID: SeedID.beachHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(99), title: "Beach Chairs",
                    desc: "Adirondack Chair Set",
                    model: "Classic", make: "Polywood", price: 598.00,
                    hasUsedAI: true, createdAt: date(-99),
                    condition: "Good", locationID: SeedID.deck, homeID: SeedID.beachHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(100), title: "Beach Umbrella",
                    desc: "Cantilever Patio Umbrella",
                    model: "AKZ", make: "Treasure Garden", price: 699.99,
                    hasUsedAI: true, createdAt: date(-100),
                    condition: "Good", locationID: SeedID.deck, homeID: SeedID.beachHome
                )
                SQLiteInventoryItem(
                    id: SeedID.item(101), title: "Kayak", desc: "Sit-On-Top Kayak",
                    model: "Pescador 12", make: "Perception", price: 699.99,
                    hasUsedAI: true, createdAt: date(-101),
                    condition: "Good", locationID: SeedID.deck, homeID: SeedID.beachHome
                )

                // ─────────────────────────────────────────────
                // MARK: Item-Label joins
                // ─────────────────────────────────────────────

                // Home Office items → labels
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(1), inventoryItemID: SeedID.item(1), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(2), inventoryItemID: SeedID.item(2), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(3), inventoryItemID: SeedID.item(3), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(4), inventoryItemID: SeedID.item(4), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(5), inventoryItemID: SeedID.item(5), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(6), inventoryItemID: SeedID.item(6), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(7), inventoryItemID: SeedID.item(7), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(8), inventoryItemID: SeedID.item(8), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(9), inventoryItemID: SeedID.item(9), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(10), inventoryItemID: SeedID.item(10), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(11), inventoryItemID: SeedID.item(11), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(12), inventoryItemID: SeedID.item(12), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(13), inventoryItemID: SeedID.item(13), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(14), inventoryItemID: SeedID.item(14), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(15), inventoryItemID: SeedID.item(15), inventoryLabelID: SeedID.sports)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(16), inventoryItemID: SeedID.item(16), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(17), inventoryItemID: SeedID.item(17), inventoryLabelID: SeedID.electronics)
                // Living Room items → labels
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(18), inventoryItemID: SeedID.item(18), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(19), inventoryItemID: SeedID.item(19), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(20), inventoryItemID: SeedID.item(20), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(21), inventoryItemID: SeedID.item(21), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(22), inventoryItemID: SeedID.item(22), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(23), inventoryItemID: SeedID.item(23), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(24), inventoryItemID: SeedID.item(24), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(25), inventoryItemID: SeedID.item(25), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(26), inventoryItemID: SeedID.item(26), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(27), inventoryItemID: SeedID.item(27), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(28), inventoryItemID: SeedID.item(28), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(29), inventoryItemID: SeedID.item(29), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(30), inventoryItemID: SeedID.item(30), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(31), inventoryItemID: SeedID.item(31), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(32), inventoryItemID: SeedID.item(32), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(33), inventoryItemID: SeedID.item(33), inventoryLabelID: SeedID.art)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(34), inventoryItemID: SeedID.item(34), inventoryLabelID: SeedID.art)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(35), inventoryItemID: SeedID.item(35), inventoryLabelID: SeedID.art)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(36), inventoryItemID: SeedID.item(36), inventoryLabelID: SeedID.collectibles)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(37), inventoryItemID: SeedID.item(37), inventoryLabelID: SeedID.collectibles)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(38), inventoryItemID: SeedID.item(38), inventoryLabelID: SeedID.collectibles)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(39), inventoryItemID: SeedID.item(39), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(40), inventoryItemID: SeedID.item(40), inventoryLabelID: SeedID.collectibles)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(41), inventoryItemID: SeedID.item(41), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(42), inventoryItemID: SeedID.item(42), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(43), inventoryItemID: SeedID.item(43), inventoryLabelID: SeedID.decorative)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(44), inventoryItemID: SeedID.item(44), inventoryLabelID: SeedID.decorative)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(45), inventoryItemID: SeedID.item(45), inventoryLabelID: SeedID.art)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(46), inventoryItemID: SeedID.item(46), inventoryLabelID: SeedID.decorative)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(47), inventoryItemID: SeedID.item(47), inventoryLabelID: SeedID.decorative)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(48), inventoryItemID: SeedID.item(48), inventoryLabelID: SeedID.decorative)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(49), inventoryItemID: SeedID.item(49), inventoryLabelID: SeedID.decorative)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(50), inventoryItemID: SeedID.item(50), inventoryLabelID: SeedID.collectibles)
                // Kitchen items → labels
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(51), inventoryItemID: SeedID.item(51), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(52), inventoryItemID: SeedID.item(52), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(53), inventoryItemID: SeedID.item(53), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(54), inventoryItemID: SeedID.item(54), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(55), inventoryItemID: SeedID.item(55), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(56), inventoryItemID: SeedID.item(56), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(57), inventoryItemID: SeedID.item(57), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(58), inventoryItemID: SeedID.item(58), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(59), inventoryItemID: SeedID.item(59), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(60), inventoryItemID: SeedID.item(60), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(61), inventoryItemID: SeedID.item(61), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(62), inventoryItemID: SeedID.item(62), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(63), inventoryItemID: SeedID.item(63), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(64), inventoryItemID: SeedID.item(64), inventoryLabelID: SeedID.kitchenLabel)
                // Master Bedroom items → labels
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(65), inventoryItemID: SeedID.item(65), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(66), inventoryItemID: SeedID.item(66), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(67), inventoryItemID: SeedID.item(67), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(68), inventoryItemID: SeedID.item(68), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(69), inventoryItemID: SeedID.item(69), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(70), inventoryItemID: SeedID.item(70), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(71), inventoryItemID: SeedID.item(71), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(72), inventoryItemID: SeedID.item(72), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(73), inventoryItemID: SeedID.item(73), inventoryLabelID: SeedID.decorative)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(74), inventoryItemID: SeedID.item(74), inventoryLabelID: SeedID.bathroom)
                // Basement items → labels
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(75), inventoryItemID: SeedID.item(75), inventoryLabelID: SeedID.sports)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(76), inventoryItemID: SeedID.item(76), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(77), inventoryItemID: SeedID.item(77), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(78), inventoryItemID: SeedID.item(78), inventoryLabelID: SeedID.furniture)
                // Garage items → labels
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(79), inventoryItemID: SeedID.item(79), inventoryLabelID: SeedID.tools)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(80), inventoryItemID: SeedID.item(80), inventoryLabelID: SeedID.tools)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(81), inventoryItemID: SeedID.item(81), inventoryLabelID: SeedID.tools)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(82), inventoryItemID: SeedID.item(82), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(83), inventoryItemID: SeedID.item(83), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(84), inventoryItemID: SeedID.item(84), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(85), inventoryItemID: SeedID.item(85), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(86), inventoryItemID: SeedID.item(86), inventoryLabelID: SeedID.tools)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(87), inventoryItemID: SeedID.item(87), inventoryLabelID: SeedID.tools)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(88), inventoryItemID: SeedID.item(88), inventoryLabelID: SeedID.tools)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(89), inventoryItemID: SeedID.item(89), inventoryLabelID: SeedID.sports)
                // Beach House items → labels
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(90), inventoryItemID: SeedID.item(90), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(91), inventoryItemID: SeedID.item(91), inventoryLabelID: SeedID.electronics)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(92), inventoryItemID: SeedID.item(92), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(93), inventoryItemID: SeedID.item(93), inventoryLabelID: SeedID.sports)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(94), inventoryItemID: SeedID.item(94), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(95), inventoryItemID: SeedID.item(95), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(96), inventoryItemID: SeedID.item(96), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(97), inventoryItemID: SeedID.item(97), inventoryLabelID: SeedID.kitchenLabel)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(98), inventoryItemID: SeedID.item(98), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(99), inventoryItemID: SeedID.item(99), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(100), inventoryItemID: SeedID.item(100), inventoryLabelID: SeedID.furniture)
                SQLiteInventoryItemLabel(
                    id: SeedID.itemLabel(101), inventoryItemID: SeedID.item(101), inventoryLabelID: SeedID.sports)

                // ─────────────────────────────────────────────
                // MARK: Item Photos
                // ─────────────────────────────────────────────

                // Map item indices to test asset names based on item titles
                let photoAssets: [Int: String] = [
                    1: "macbook",
                    2: "desk-chair",
                    3: "desktop-computer",
                    4: "monitor",
                    5: "printer",
                    6: "webcam",
                    7: "projector",
                    8: "filing-cabinet",
                    9: "bookshelf",
                    10: "bookcase",
                    11: "office-desk",
                    12: "wireless-router",
                    13: "router-wifi",
                    14: "smart-bulbs",
                    15: "weight-set",
                    16: "headphones",
                    17: "camera-dslr",
                    18: "tv",
                    19: "gaming-console",
                    20: "smart-speaker",
                    21: "sofa",
                    22: "dining-table",
                    23: "area-rug",
                    24: "floor-lamp",
                    25: "smart-tv",
                    26: "tv-stand",
                    27: "armchair",
                    28: "coffee-table",
                    29: "chandelier",
                    30: "table-lamps",
                    31: "sound-bar",
                    32: "tablet",
                    33: "record-player",
                    34: "board-games",
                    35: "canvas-print",
                    36: "digital-piano",
                    37: "sax",
                    38: "drum-kit",
                    39: "tablet",
                    40: "gaming-console",
                    41: "dining-chairs",
                    42: "console-table",
                    43: "mirror-wall",
                    44: "vase-ceramic",
                    45: "picture-frame",
                    46: "throw-blanket",
                    47: "decorative-pillows",
                    48: "candle-holder",
                    49: "plant-indoor",
                    50: "guitar",
                    51: "coffee-maker",
                    52: "stand-mixer",
                    53: "blender",
                    54: "air-fryer",
                    55: "espresso-machine",
                    56: "food-processor",
                    57: "wine-fridge",
                    58: "microwave",
                    59: "toaster",
                    60: "knife-set",
                    61: "pots-pans",
                    62: "cutting-board",
                    63: "kettle-electric",
                    64: "dishwasher",
                    65: "bed-frame",
                    66: "closet-system",
                    67: "nightstand",
                    68: "dresser",
                    69: "wardrobe",
                    70: "mattress",
                    71: "lamp-bedside",
                    72: "smart-watch",
                    73: "bedding-set",
                    74: "towel-set",
                    75: "treadmill",
                    76: "washer",
                    77: "dryer",
                    78: "vacuum-cleaner",
                    79: "power-drill",
                    80: "table-saw",
                    81: "tool-chest",
                    82: "grill",
                    83: "patio-set",
                    84: "fire-pit",
                    85: "storage-bench",
                    86: "toolbox",
                    87: "ladder",
                    88: "lawn-mower",
                    89: "bicycle",
                    90: "sofa",
                    91: "smart-tv",
                    92: "dining-table",
                    93: "bicycle",
                    94: "bed-frame",
                    95: "nightstand",
                    96: "blender",
                    97: "coffee-maker",
                    98: "grill",
                    99: "patio-set",
                    100: "fire-pit",
                    101: "bicycle",
                ]

                for (itemIndex, assetName) in photoAssets {
                    if let photoData = testImageData(for: assetName) {
                        SQLiteInventoryItemPhoto(
                            id: SeedID.itemPhoto(itemIndex),
                            inventoryItemID: SeedID.item(itemIndex),
                            data: photoData,
                            sortOrder: 0
                        )
                    }
                }
            }
        }

        return db
    }

    // MARK: - Helpers

    /// Returns a date offset by the given number of hours from a fixed reference date.
    /// Using a fixed reference ensures deterministic ordering of `createdAt` across runs.
    private func date(_ hoursOffset: Int) -> Date {
        // Fixed reference: 2025-01-15T12:00:00Z
        let reference = Date(timeIntervalSince1970: 1_736_942_400)
        return reference.addingTimeInterval(Double(hoursOffset) * 3600)
    }

    /// Creates image data from a test asset, or returns nil if not found
    private func testImageData(for imageName: String) -> Data? {
        guard let image = UIImage(named: imageName) else { return nil }
        return image.jpegData(compressionQuality: 0.8)
    }
#endif
