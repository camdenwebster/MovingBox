//
//  ImageEncoder.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import Foundation
import SwiftUI
import UIKit

class ImageEncoder {
    let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    func optimizeImage() -> UIImage? {
        // Maximum dimension we'll allow
        let maxDimension: CGFloat = 512

        let originalWidth = image.size.width
        let originalHeight = image.size.height

        // Calculate scale factor to reduce image size while maintaining aspect ratio
        let scaleFactor = min(maxDimension / originalWidth, maxDimension / originalHeight, 1.0)

        let newWidth = originalWidth * scaleFactor
        let newHeight = originalHeight * scaleFactor

        let size = CGSize(width: newWidth, height: newHeight)

        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage
    }

    func encodeImageToBase64() -> String? {
        guard let optimizedImage = optimizeImage() else { return nil }

        // Reduce JPEG compression quality to minimize payload size
        guard let imageData = optimizedImage.jpegData(compressionQuality: 0.5) else { return nil }

        return imageData.base64EncodedString()
    }
}
