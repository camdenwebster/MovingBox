//
//  SplashView.swift
//  MovingBox
//
//  Created by Camden Webster on 3/7/25.
//

import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ModelContainerManager.self) private var containerManager

    private let bottomStatusHeight: CGFloat = 140

    private var backgroundImage: String {
        colorScheme == .dark ? "background-dark" : "background-light"
    }

    private var textColor: Color {
        colorScheme == .dark ? .splashTextDark : .splashTextLight
    }

    var body: some View {
        ZStack {
            Image(backgroundImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                if let appIcon = Bundle.main.icon {
                    Image(uiImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                VStack {
                    Text("MovingBox")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                    Text("Home inventory, simplified")
                        .fontWeight(.light)
                        .foregroundColor(textColor)
                }

                Spacer()

                // Migration and CloudKit Sync Progress
                Group {
                    if containerManager.isLoading || containerManager.isCloudKitSyncing {
                        VStack(spacing: 12) {

                            if containerManager.isLoading {
                                Text("Migration in progress, please do not close the app")
                                    .font(.caption)
                                    .foregroundColor(textColor.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            } else if containerManager.isCloudKitSyncing {
                                Text(containerManager.cloudKitSyncMessage)
                                    .font(.caption)
                                    .foregroundColor(textColor.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                    .scaleEffect(1.2)
                            }
                        }
                        .onAppear {
                            print(
                                "🔄 SplashView - Progress UI appeared (isLoading = \(containerManager.isLoading), isCloudKitSyncing = \(containerManager.isCloudKitSyncing))"
                            )
                        }
                        .onDisappear {
                            print("🔄 SplashView - Progress UI disappeared")
                        }
                    } else {
                        Color.clear
                            .onAppear {
                                print(
                                    "🔄 SplashView - No progress UI shown (isLoading = \(containerManager.isLoading), isCloudKitSyncing = \(containerManager.isCloudKitSyncing))"
                                )
                            }
                    }
                }
                .frame(height: bottomStatusHeight)
            }
        }
    }
}

extension Bundle {
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let lastIcon = iconFiles.last
        {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

#Preview {
    SplashView()
        .environment(ModelContainerManager.shared)
}
