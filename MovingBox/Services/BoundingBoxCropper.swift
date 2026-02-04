//
//  BoundingBoxCropper.swift
//  MovingBox
//
//  Created by Claude Code on 2/3/26.
//

import UIKit

enum BoundingBoxCropper {

    /// Crop image using [ymin, xmin, ymax, xmax] normalized 0-1000 coordinates
    static func crop(image: UIImage, boundingBox: [Int], paddingFraction: CGFloat = 0.05) async -> UIImage? {
        guard boundingBox.count >= 4 else { return nil }

        let ymin = boundingBox[0]
        let xmin = boundingBox[1]
        let ymax = boundingBox[2]
        let xmax = boundingBox[3]

        // Validate box has positive dimensions
        guard xmax > xmin, ymax > ymin else { return nil }

        guard let cgImage = image.cgImage else { return nil }

        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)

        // Convert from 0-1000 normalized coordinates to pixel coordinates
        let rawX = (CGFloat(xmin) / 1000.0) * pixelWidth
        let rawY = (CGFloat(ymin) / 1000.0) * pixelHeight
        let rawW = (CGFloat(xmax - xmin) / 1000.0) * pixelWidth
        let rawH = (CGFloat(ymax - ymin) / 1000.0) * pixelHeight

        // Apply padding for aesthetic breathing room
        let padX = rawW * paddingFraction
        let padY = rawH * paddingFraction

        // Clamp to image bounds
        let x = max(0, rawX - padX)
        let y = max(0, rawY - padY)
        let w = min(pixelWidth - x, rawW + padX * 2)
        let h = min(pixelHeight - y, rawH + padY * 2)

        guard w > 0, h > 0 else { return nil }

        let cropRect = CGRect(x: x, y: y, width: w, height: h)

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

        // Preserve orientation from source image
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Crop all detections for an item, returns (primary, secondaries)
    /// The first detection is treated as the primary (best/clearest view).
    static func cropDetections(
        for item: DetectedInventoryItem,
        from sourceImages: [UIImage]
    ) async -> (primary: UIImage?, secondary: [UIImage]) {
        guard let detections = item.detections, !detections.isEmpty else {
            return (nil, [])
        }

        var primary: UIImage?
        var secondaries: [UIImage] = []

        for (index, detection) in detections.enumerated() {
            guard detection.sourceImageIndex >= 0,
                detection.sourceImageIndex < sourceImages.count
            else { continue }

            let sourceImage = sourceImages[detection.sourceImageIndex]
            guard let cropped = await crop(image: sourceImage, boundingBox: detection.boundingBox) else { continue }

            if index == 0 {
                primary = cropped
            } else {
                secondaries.append(cropped)
            }
        }

        return (primary, secondaries)
    }
}
