//
//  PlatformImage.swift
//  MovingBoxAIAnalysis
//

import CoreGraphics

#if canImport(UIKit)
    import UIKit
    public typealias AIImage = UIImage
#elseif canImport(AppKit)
    import AppKit
    public typealias AIImage = NSImage
#else
    #error("MovingBoxAIAnalysis requires UIKit or AppKit")
#endif
