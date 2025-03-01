//
//  ImageEncoder.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import Foundation
import SwiftUI

struct ImageEncoder {
    var image: UIImage
    
    // Added helper function to resize image
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        // Use the smaller ratio to ensure image fits within bounds
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
        
        return resizedImage
    }
    
    func encodeImageToBase64() -> String? {
        // Set the target size based on isHighDetail setting
        let isHighDetail = UserDefaults.standard.bool(forKey: "isHighDetail")
        let targetSize = isHighDetail ?
            CGSize(width: 2048, height: 2048) :
            CGSize(width: 512, height: 512)
        
        let resizedImage = resizeImage(image: image, targetSize: targetSize)
        print("Resized image to \(resizedImage.size.width)x \(resizedImage.size.height)")
        guard let imageData = resizedImage.pngData() else {
            return nil
        }
        
        let base64String = imageData.base64EncodedString(options: .lineLength64Characters)
        
        return base64String
    }
}

extension ImageEncoder {
    func optimizeImage(maxDimension: CGFloat = 1024, compressionQuality: CGFloat = 0.5) -> UIImage? {
        // Calculate scaling factor
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        
        // Calculate new size
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
