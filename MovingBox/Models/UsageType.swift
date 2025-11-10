import Foundation

/// Enum representing different ways users intend to use MovingBox
enum UsageType: String, CaseIterable, Codable {
    case protect = "protect"
    case organize = "organize"
    case move = "move"
    case exploring = "exploring"

    var title: String {
        switch self {
        case .protect:
            return "Protect my stuff"
        case .organize:
            return "Stay organized"
        case .move:
            return "Plan my move"
        case .exploring:
            return "Just exploring"
        }
    }

    var description: String {
        switch self {
        case .protect:
            return "Document valuables for insurance"
        case .organize:
            return "Know where everything is"
        case .move:
            return "Track items and boxes"
        case .exploring:
            return "Seeing what this can do"
        }
    }
}
