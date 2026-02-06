//
//  ImageEncoder.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import Foundation

#if canImport(UIKit)
    import UIKit
    typealias PlatformImage = UIImage
#elseif canImport(AppKit)
    import AppKit
    typealias PlatformImage = NSImage
#endif

class ImageEncoder {
    let image: PlatformImage

    init(image: PlatformImage) {
        self.image = image
    }

    func optimizeImage() -> PlatformImage? {
        // Maximum dimension we'll allow
        let maxDimension: CGFloat = 512

        let originalWidth = image.size.width
        let originalHeight = image.size.height

        // Calculate scale factor to reduce image size while maintaining aspect ratio
        let scaleFactor = min(maxDimension / originalWidth, maxDimension / originalHeight, 1.0)

        let newWidth = originalWidth * scaleFactor
        let newHeight = originalHeight * scaleFactor

        let size = CGSize(width: newWidth, height: newHeight)

        #if canImport(UIKit)
            UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: size))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return resizedImage
        #elseif canImport(AppKit)
            let resizedImage = NSImage(size: size)
            resizedImage.lockFocus()
            image.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1.0
            )
            resizedImage.unlockFocus()
            return resizedImage
        #else
            return nil
        #endif
    }

    func encodeImageToBase64() -> String? {
        guard let optimizedImage = optimizeImage() else { return nil }

        // Reduce JPEG compression quality to minimize payload size
        #if canImport(UIKit)
            guard let imageData = optimizedImage.jpegData(compressionQuality: 0.5) else { return nil }
        #elseif canImport(AppKit)
            guard let tiffData = optimizedImage.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiffData),
                let imageData = bitmap.representation(
                    using: .jpeg,
                    properties: [.compressionFactor: 0.5]
                )
            else { return nil }
        #else
            return nil
        #endif

        return imageData.base64EncodedString()
    }
}
