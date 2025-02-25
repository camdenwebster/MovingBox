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
        // First resize the image to fit within 2048x2048
        let maxSize = CGSize(width: 2048, height: 2048)
        let resizedImage = resizeImage(image: image, targetSize: maxSize)
        
        guard let imageData = resizedImage.pngData() else {
            return nil
        }
        
        let base64String = imageData.base64EncodedString(options: .lineLength64Characters)
        
        return base64String
    }
}
