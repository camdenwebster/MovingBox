//
//  ImageEncoder.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import Foundation
import SwiftUI

struct ImageEncoder {
    var image: Data

    
    func encodeImageToBase64() -> String? {
        guard let uiImage = UIImage(data: image) else {
            return nil
        }
        
        guard let imageData = uiImage.pngData() else {
            return nil
        }
        
        let base64String = imageData.base64EncodedString(options: .lineLength64Characters)
        
        return base64String
    }
}
