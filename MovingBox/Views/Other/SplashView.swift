//
//  SplashView.swift
//  MovingBox
//
//  Created by Camden Webster on 3/7/25.
//

import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var containerManager: ModelContainerManager
    
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
                
                // Migration Progress (only show when loading)
                if containerManager.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .green))
                            .scaleEffect(1.2)
                        
                        Text("Migration in progress, please do not close the app")
                            .font(.caption)
                            .foregroundColor(textColor.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    .onAppear {
                        print("🔄 SplashView - Migration UI appeared (isLoading = \(containerManager.isLoading))")
                    }
                    .onDisappear {
                        print("🔄 SplashView - Migration UI disappeared")
                    }
                } else {
                    // Debug when not loading
                    Text("")
                        .onAppear {
                            print("🔄 SplashView - No migration UI shown (isLoading = \(containerManager.isLoading))")
                        }
                }
            }
        }
    }
}

extension Bundle {
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

#Preview {
    SplashView()
        .environmentObject(ModelContainerManager.shared)
}
