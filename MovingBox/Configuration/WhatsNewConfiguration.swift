import SwiftUI
import WhatsNewKit

extension WhatsNew {
    static var version2_1_0: WhatsNew {
        WhatsNew(
            version: "2.1.0",
            title: "What's New",
            features: [
                WhatsNew.Feature(
                    image: .init(
                        systemName: "photo.stack.fill",
                        foregroundColor: .blue
                    ),
                    title: "Multi-Item Analysis",
                    subtitle: "Add multiple items from a single photo with our new intelligent analysis flow"
                ),
                WhatsNew.Feature(
                    image: .init(
                        systemName: "arrow.up.arrow.down.circle.fill",
                        foregroundColor: .green
                    ),
                    title: "Enhanced Import & Export",
                    subtitle: "Improved capabilities for importing and exporting your inventory data"
                ),
                WhatsNew.Feature(
                    image: .init(
                        systemName: "arrow.up.arrow.down.circle.fill",
                        foregroundColor: .orange
                    ),
                    title: "Better Sorting",
                    subtitle: "New sorting options to organize your inventory exactly how you want"
                ),
                WhatsNew.Feature(
                    image: .init(
                        systemName: "macbook.and.ipad",
                        foregroundColor: .purple
                    ),
                    title: "iPad & Mac Experience",
                    subtitle: "Optimized interface for larger screens with improved navigation and layout"
                ),
            ],
            primaryAction: WhatsNew.PrimaryAction(
                title: "Continue",
                backgroundColor: .accentColor,
                foregroundColor: .white,
                hapticFeedback: .notification(.success)
            )
        )
    }

    static var current: WhatsNew {
        version2_1_0
    }
}

extension WhatsNewEnvironment {
    static func forMovingBox(versionStore: WhatsNewVersionStore = UserDefaultsWhatsNewVersionStore())
        -> WhatsNewEnvironment
    {
        WhatsNewEnvironment(
            versionStore: versionStore,
            whatsNewCollection: [
                .version2_1_0
            ]
        )
    }
}
