import SwiftUI

extension Color {
    static let customPrimary = Color(hex: 0x4EB86F)
    static let customDanger = Color(hex: 0xDA2F4F)
    static let onboardingBackgroundLight = Color(hex: 0xFBF1E5)
    static let splashTextLight = Color(hex: 0x333333)
    static let splashTextDark = Color(hex: 0xF2F2F2)

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}
