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

    
    func encodeImageToBase64() -> String? {
        guard let imageData = image.pngData() else {
            return nil
        }
        
        let base64String = imageData.base64EncodedString(options: .lineLength64Characters)
        
        return base64String
    }
}
