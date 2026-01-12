//
//  ShareSheet.swift
//  MovingBox
//
//  Created by Camden Webster on 5/1/25.
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        print("📤 ShareSheet: Creating UIActivityViewController")
        print("   Activity items count: \(activityItems.count)")
        for (index, item) in activityItems.enumerated() {
            if let url = item as? URL {
                print("   Item \(index): URL - \(url.path)")
                print("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
                if FileManager.default.fileExists(atPath: url.path) {
                    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                    let size = attributes?[.size] as? Int64 ?? 0
                    print("   File size: \(size) bytes")
                }
            } else {
                print("   Item \(index): \(type(of: item))")
            }
        }

        let vc = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil)
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
