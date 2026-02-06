import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

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

    /// Returns either black or white color based on the luminance of the background color
    /// for optimal text readability following WCAG guidelines
    func idealTextColor() -> Color {
        // Convert SwiftUI Color to UIColor to extract RGB components
        let uiColor = UIColor(self)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        // Extract RGBA components
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Calculate relative luminance using WCAG formula
        // First linearize the RGB values
        let linearRed = linearizeColorComponent(red)
        let linearGreen = linearizeColorComponent(green)
        let linearBlue = linearizeColorComponent(blue)

        // Calculate luminance
        let luminance = 0.2126 * linearRed + 0.7152 * linearGreen + 0.0722 * linearBlue

        // Return black text for bright backgrounds, white text for dark backgrounds
        // Threshold of 0.5 works well for most cases
        return luminance > 0.5 ? .black : .white
    }

    /// Linearize a color component according to sRGB specification
    private func linearizeColorComponent(_ component: CGFloat) -> CGFloat {
        if component <= 0.03928 {
            return component / 12.92
        } else {
            return pow((component + 0.055) / 1.055, 2.4)
        }
    }
}
