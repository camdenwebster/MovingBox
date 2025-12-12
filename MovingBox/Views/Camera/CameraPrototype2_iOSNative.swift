//
//  CameraPrototype2_iOSNative.swift
//  MovingBox
//
//  iOS Camera App Inspired Design Prototype
//  Philosophy: Familiar, Apple-native experience matching system Camera.app patterns
//
//  Key Features:
//  - Standard iOS Camera.app layout and control placement
//  - Horizontal mode selector above shutter (scrollable pills)
//  - Vertical zoom control on right side
//  - Top bar with standard iOS controls using Liquid Glass .regular
//  - Bottom controls with Liquid Glass .regular background
//  - Prominent shutter button with ring indicator
//

import SwiftUI

struct CameraPrototype2_iOSNative: View {
    @State private var flashMode: FlashMode = .off
    @State private var captureMode: CaptureMode = .singleItem
    @State private var photoCount = 0
    @State private var selectedZoomLevel: ZoomLevel = .oneX
    @State private var showingPhotoPicker = false
    @State private var showingFlashOptions = false

    // Enum for zoom levels
    private enum ZoomLevel: String, CaseIterable, Identifiable {
        case halfX = "0.5"
        case oneX = "1"
        case twoX = "2"

        var id: String { rawValue }

        var displayText: String { "\(rawValue)×" }
        var value: CGFloat {
            switch self {
            case .halfX: return 0.5
            case .oneX: return 1.0
            case .twoX: return 2.0
            }
        }
    }

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
            // CONTENT LAYER: Camera preview
            cameraPreviewLayer

            // FUNCTIONAL LAYER: Controls
            VStack(spacing: 0) {
                topBar
                Spacer()

                // Zoom controls floating above bottom bar
                zoomControlHorizontal
                    .padding(.bottom, 20)

                bottomControlArea
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden(false)
    }

    // MARK: - Content Layer

    private var cameraPreviewLayer: some View {
        GeometryReader { geometry in
            Image("tablet", bundle: .main)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(selectedZoomLevel.value)
                .clipped()
                .brightness(0.1) // Slightly brighten the preview
        }
    }

    // MARK: - Functional Layer - Top Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            // Close button
            Button(action: { print("Close tapped") }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("Close camera")

            Spacer()

            // Flash button
            Button(action: toggleFlash) {
                Image(systemName: flashMode.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("Flash \(flashMode.rawValue)")

            // Flip camera button
            Button(action: { print("Flip camera tapped") }) {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("Flip camera")
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
    }

    // MARK: - Functional Layer - Bottom Controls

    private var bottomControlArea: some View {
        VStack(spacing: 0) {
            // Photo counter (when photos captured)
            if photoCount > 0 {
                Text("\(photoCount) of 5")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.bottom, 12)
            }

            // Shutter and controls row
            HStack(spacing: 0) {
                // Thumbnail preview (left)
                Button(action: { showingPhotoPicker = true }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 50, height: 50)

                        if photoCount > 0 {
                            // Show mock thumbnail
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.blue.gradient)
                                .frame(width: 46, height: 46)
                            Text("\(photoCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .accessibilityLabel("Photo library")

                Spacer()

                // Shutter button (center)
                shutterButton

                Spacer()

                // Flip camera button (right)
                Button(action: { print("Flip camera tapped") }) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                }
                .accessibilityLabel("Flip camera")
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Mode selector below shutter (like VIDEO/PHOTO in native camera)
            modeSelector
                .padding(.bottom, 40)
        }
        .background(
            Rectangle()
                .fill(.black)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach([CaptureMode.singleItem, CaptureMode.multiItem], id: \.self) { mode in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        captureMode = mode
                    }
                    print("Capture mode: \(mode.displayName)")
                }) {
                    Text(mode.displayName.uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(captureMode == mode ? .yellow : .white.opacity(0.7))
                        .frame(minWidth: 80)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
    }

    private var shutterButton: some View {
        Button(action: capturePhoto) {
            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 76, height: 76)

                // Inner circle
                Circle()
                    .fill(.white)
                    .frame(width: 64, height: 64)

                // Optional: progress ring for multi-photo mode
                if photoCount > 0 && photoCount < 5 {
                    Circle()
                        .trim(from: 0, to: CGFloat(photoCount) / 5.0)
                        .stroke(.tint, lineWidth: 4)
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .accessibilityLabel("Take photo")
    }

    // MARK: - Zoom Control (Horizontal - iOS Native Style)

    private var zoomControlHorizontal: some View {
        HStack(spacing: 12) {
            ForEach(ZoomLevel.allCases, id: \.self) { level in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedZoomLevel = level
                    }
                    print("Zoom: \(level.displayText)")
                }) {
                    ZStack {
                        if selectedZoomLevel == level {
                            Circle()
                                .fill(.white.opacity(0.3))
                                .frame(width: 50, height: 50)
                        }

                        Text(level.displayText)
                            .font(.system(size: 16, weight: selectedZoomLevel == level ? .bold : .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .accessibilityLabel("\(level.displayText) zoom")
            }
        }
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
    }

    private func capturePhoto() {
        print("Photo captured")
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            photoCount = min(photoCount + 1, 5)
        }

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.impactOccurred()
    }
}

// MARK: - Previews

#Preview("iOS Native Camera - Light") {
    CameraPrototype2_iOSNative()
        .preferredColorScheme(.light)
}

#Preview("iOS Native Camera - Dark") {
    CameraPrototype2_iOSNative()
        .preferredColorScheme(.dark)
}

#Preview("iOS Native Camera - With Photos") {
    CameraPrototype2_iOSNative()
        .onAppear {
            // Simulate having taken some photos
        }
}
