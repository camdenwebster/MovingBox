//
//  CameraPrototype3_CardBased.swift
//  MovingBox
//
//  Card-Based Modern Design Prototype
//  Philosophy: Contemporary, card-based UI with dynamic animations and depth
//
//  Key Features:
//  - Floating card-style control panels with Liquid Glass .regular
//  - Stacked card layout for different control groups
//  - Spring animations for card transitions
//  - Rounded corners and shadows for depth
//  - Compact, grouped controls in floating panels
//  - Modern glassmorphism aesthetic throughout controls only
//

import SwiftUI

struct CameraPrototype3_CardBased: View {
    @State private var flashMode: FlashMode = .off
    @State private var captureMode: CaptureMode = .singleItem
    @State private var photoCount = 0
    @State private var selectedZoomLevel = 1 // 0=0.5x, 1=1x, 2=2x
    @State private var showingModeCard = true
    @State private var showingPhotoGallery = false
    @Namespace private var animation

    private let zoomLevels: [(label: String, value: CGFloat)] = [
        ("0.5×", 0.5),
        ("1×", 1.0),
        ("2×", 2.0)
    ]

    // Flash mode enum
    private enum FlashMode: String, CaseIterable {
        case auto = "Auto"
        case on = "On"
        case off = "Off"

        var iconName: String {
            switch self {
            case .auto: return "bolt.badge.automatic"
            case .on: return "bolt.fill"
            case .off: return "bolt.slash.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            // CONTENT LAYER: Full-bleed camera preview
            cameraPreviewLayer

            // FUNCTIONAL LAYER: Floating card controls
            VStack(spacing: 0) {
                topControlCards
                Spacer()
                bottomCaptureCard
            }

            // Side camera options card
            sideOptionsCard

            // Photo gallery cards
            if showingPhotoGallery && photoCount > 0 {
                photoGalleryCards
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    // MARK: - Content Layer

    private var cameraPreviewLayer: some View {
        GeometryReader { geometry in
            Image("tablet", bundle: .main)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(zoomLevels[selectedZoomLevel].value)
                .clipped()
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedZoomLevel)
        }
    }

    // MARK: - Functional Layer - Top Cards

    private var topControlCards: some View {
        VStack(spacing: 12) {
            // Top action bar card
            HStack {
                // Close button card
                Button(action: { print("Close tapped") }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .accessibilityLabel("Close camera")

                Spacer()

                // Settings cluster card
                HStack(spacing: 0) {
                    // Flash toggle
                    Button(action: toggleFlash) {
                        VStack(spacing: 2) {
                            Image(systemName: flashMode.iconName)
                                .font(.system(size: 16, weight: .medium))
                            Text(flashMode.rawValue)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(.primary)
                        .frame(width: 50, height: 44)
                    }
                    .accessibilityLabel("Flash \(flashMode.rawValue)")

                    Divider()
                        .frame(height: 30)

                    // Flip camera
                    Button(action: { print("Flip camera") }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 50, height: 44)
                    }
                    .accessibilityLabel("Flip camera")
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            // Mode selector card (collapsible)
            if showingModeCard {
                HStack(spacing: 8) {
                    ForEach([CaptureMode.singleItem, CaptureMode.multiItem], id: \.self) { mode in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                captureMode = mode
                            }
                            print("Capture mode: \(mode.displayName)")
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: mode.iconName)
                                    .font(.system(size: 14))
                                Text(mode.displayName)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(captureMode == mode ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                if captureMode == mode {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.tint)
                                }
                            }
                        }
                    }
                }
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .padding(.horizontal, 40)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Functional Layer - Bottom Capture Card

    private var bottomCaptureCard: some View {
        VStack(spacing: 16) {
            // Photo counter card
            if photoCount > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 14))
                    Text("\(photoCount) of 5 photos")
                        .font(.system(size: 14, weight: .medium))

                    Spacer()

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showingPhotoGallery.toggle()
                        }
                    }) {
                        Image(systemName: showingPhotoGallery ? "chevron.down" : "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .padding(.horizontal, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Main capture controls card
            HStack(spacing: 24) {
                // Photo library button
                Button(action: { print("Photo library") }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                            .frame(width: 50, height: 50)
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

                        if photoCount > 0 {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.blue.gradient)
                                .frame(width: 46, height: 46)
                            Text("\(photoCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 22))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .accessibilityLabel("Photo library")

                // Shutter button
                Button(action: capturePhoto) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 76, height: 76)
                            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)

                        Circle()
                            .strokeBorder(.white.opacity(0.3), lineWidth: 3)
                            .frame(width: 88, height: 88)

                        // Progress indicator
                        if photoCount > 0 && photoCount < 5 {
                            Circle()
                                .trim(from: 0, to: CGFloat(photoCount) / 5.0)
                                .stroke(Color.accentColor, lineWidth: 4)
                                .frame(width: 88, height: 88)
                                .rotationEffect(.degrees(-90))
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 4)
                        }
                    }
                }
                .accessibilityLabel("Take photo")

                // Retake button (when photos exist)
                if photoCount > 0 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            photoCount = 0
                            showingPhotoGallery = false
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 50, height: 50)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Retake photos")
                } else {
                    Color.clear
                        .frame(width: 50, height: 50)
                }
            }
            .padding(.bottom, 50)
        }
    }

    // MARK: - Side Options Card

    private var sideOptionsCard: some View {
        VStack(spacing: 10) {
            ForEach(0..<zoomLevels.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedZoomLevel = index
                    }
                    print("Zoom: \(zoomLevels[index].label)")
                }) {
                    Text(zoomLevels[index].label)
                        .font(.system(size: 13, weight: selectedZoomLevel == index ? .bold : .medium))
                        .foregroundStyle(selectedZoomLevel == index ? .white : .primary)
                        .frame(width: 44, height: 44)
                        .background {
                            if selectedZoomLevel == index {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.accentColor)
                                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                            } else {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.regularMaterial)
                                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                            }
                        }
                }
                .accessibilityLabel("Zoom \(zoomLevels[index].label)")
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 220)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    // MARK: - Photo Gallery Cards

    private var photoGalleryCards: some View {
        VStack {
            Spacer()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<photoCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.blue.gradient)
                            .frame(width: 100, height: 120)
                            .overlay(
                                VStack {
                                    Spacer()
                                    Text("Photo \(index + 1)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white)
                                        .padding(.bottom, 8)
                                }
                            )
                            .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 140)
            .padding(.bottom, 180)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func toggleFlash() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let allCases = FlashMode.allCases
            if let currentIndex = allCases.firstIndex(of: flashMode) {
                let nextIndex = (currentIndex + 1) % allCases.count
                flashMode = allCases[nextIndex]
            }
        }
        print("Flash mode: \(flashMode.rawValue)")

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    private func capturePhoto() {
        print("Photo captured")
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            photoCount = min(photoCount + 1, 5)
        }

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

// MARK: - Previews

#Preview("Card-Based Camera - Light") {
    CameraPrototype3_CardBased()
        .preferredColorScheme(.light)
}

#Preview("Card-Based Camera - Dark") {
    CameraPrototype3_CardBased()
        .preferredColorScheme(.dark)
}

#Preview("Card-Based Camera - With Photos") {
    struct PreviewWrapper: View {
        @State private var photoCount = 3
        var body: some View {
            CameraPrototype3_CardBased()
        }
    }
    return PreviewWrapper()
}
