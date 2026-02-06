//
//  UIConstants.swift
//  MovingBox
//
//  Created by AI Assistant on 8/19/25.
//

import Foundation
import SwiftUI

struct UIConstants {
    /// Standard corner radius for UI elements
    /// iOS 26+ uses larger corner radius (25) for modern design
    /// Earlier iOS versions use traditional corner radius (12)
    static var cornerRadius: CGFloat {
        if #available(iOS 26, macOS 26, *) {
            return 24
        } else {
            return 12
        }
    }

    /// Section header text style for custom form sections
    /// Returns a view modifier that applies the appropriate iOS 18-style section header formatting
    static func sectionHeaderStyle() -> some View {
        EmptyView()
            .modifier(SectionHeaderModifier())
    }
}

struct SectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            // iOS 26+ uses updated typography matching the new design
            // Larger, more readable font with better contrast
            content
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            // iOS 18-25 maintains the traditional form section header style
            content
                .font(.subheadline)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0)
        }
    }
}

extension Text {
    /// Applies iOS version-appropriate section header formatting
    /// iOS 18-25: Traditional section header with secondary color
    /// iOS 26+: Enhanced section header with improved typography and accessibility
    func sectionHeaderStyle() -> some View {
        self.modifier(SectionHeaderModifier())
    }
}
