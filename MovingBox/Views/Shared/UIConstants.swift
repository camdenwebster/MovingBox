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
        if #available(iOS 26, *) {
            return 25
        } else {
            return 12
        }
    }
}
