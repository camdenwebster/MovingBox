import Foundation

#if os(macOS)
    import AppKit
    import SwiftUI

    typealias UIImage = NSImage
    typealias UIColor = NSColor

    struct UIScreen {
        static var main: UIScreen {
            UIScreen(bounds: NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1280, height: 800))
        }

        let bounds: CGRect
    }

    enum UISceneActivationState {
        case foregroundActive
        case background
        case inactive
    }

    final class UIWindowScene {
        var activationState: UISceneActivationState = .foregroundActive
    }

    final class UIApplication {
        static let shared = UIApplication()
        static let openSettingsURLString = "x-apple.systempreferences:"
        static let didReceiveMemoryWarningNotification = Notification.Name(
            "UIApplicationDidReceiveMemoryWarningNotification")

        var connectedScenes: [UIWindowScene] { [UIWindowScene()] }

        func open(_ url: URL) {
            NSWorkspace.shared.open(url)
        }
    }

    enum UIImageOrientation: Int {
        case up = 0
        case down
        case left
        case right
        case upMirrored
        case downMirrored
        case leftMirrored
        case rightMirrored
    }

    extension NSColor {
        static var primary: NSColor { .labelColor }
        static var secondary: NSColor { .secondaryLabelColor }
        static var label: NSColor { .labelColor }
        static var secondaryLabel: NSColor { .secondaryLabelColor }
        static var separator: NSColor { .separatorColor }
        static var systemBackground: NSColor { .windowBackgroundColor }
        static var secondarySystemBackground: NSColor { .underPageBackgroundColor }
        static var tertiarySystemBackground: NSColor { .controlBackgroundColor }
        static var systemGroupedBackground: NSColor { .windowBackgroundColor }
        static var secondarySystemGroupedBackground: NSColor { .underPageBackgroundColor }
        static var systemGray4: NSColor { .systemGray.withAlphaComponent(0.65) }
        static var systemGray5: NSColor { .systemGray.withAlphaComponent(0.45) }
        static var systemGray6: NSColor { .systemGray.withAlphaComponent(0.3) }
        static var accentColor: NSColor { .controlAccentColor }
    }

    extension NSImage {
        convenience init?(named name: String) {
            self.init(named: NSImage.Name(name))
        }

        convenience init?(systemName name: String) {
            self.init(systemSymbolName: name, accessibilityDescription: nil)
        }

        var scale: CGFloat { 1.0 }

        var imageOrientation: UIImageOrientation { .up }

        var cgImage: CGImage? {
            var rect = CGRect(origin: .zero, size: size)
            return cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }

        convenience init(cgImage: CGImage, scale: CGFloat, orientation: UIImageOrientation) {
            self.init(cgImage: cgImage, size: .zero)
        }

        func jpegData(compressionQuality: CGFloat) -> Data? {
            guard let tiffData = tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiffData)
            else { return nil }

            return bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: compressionQuality]
            )
        }

        func pngData() -> Data? {
            guard let tiffData = tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiffData)
            else { return nil }

            return bitmap.representation(using: .png, properties: [:])
        }

        func draw(in rect: CGRect) {
            draw(in: rect, from: .zero, operation: .copy, fraction: 1.0)
        }

        func resized(to size: CGSize) -> NSImage? {
            let resizedImage = NSImage(size: size)
            resizedImage.lockFocus()
            draw(in: CGRect(origin: .zero, size: size))
            resizedImage.unlockFocus()
            return resizedImage
        }

        func byPreparingThumbnail(ofSize size: CGSize) async -> NSImage? {
            resized(to: size)
        }
    }

    extension Image {
        init(uiImage: UIImage) {
            self.init(nsImage: uiImage)
        }
    }

    extension Color {
        init(uiColor: UIColor) {
            self.init(nsColor: uiColor)
        }
    }
#endif
