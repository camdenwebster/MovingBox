//
//  CameraPrototype1_Minimalist.swift
//  MovingBox
//
//  Minimalist "Pro Camera" Design Prototype
//  Philosophy: Clean, distraction-free interface inspired by professional camera apps
//
//  Key Features:
//  - Minimal on-screen controls (most hidden until tapped)
//  - Full-screen camera preview with edge-to-edge content
//  - Floating control panels with Liquid Glass .clear variant
//  - Bottom sheet for settings (slides up on demand)
//  - Gesture-driven interactions (tap to reveal controls)
//  - Monochromatic iconography with high contrast
//

import SwiftUI

struct CameraPrototype1_Minimalist: View {
    @State private var showingControls = true
    @State private var showingSettings = false
    @State private var flashMode: FlashMode = .off
    @State private var captureMode: CaptureMode = .singleItem
    @State private var photoCount = 0
    @State private var zoomLevel: CGFloat = 1.0
    @State private var selectedZoomIndex = 1 // 0=0.5x, 1=1x, 2=2x

    private let zoomLevels: [CGFloat] = [0.5, 1.0, 2.0]

    // Enum for flash mode
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
            // CONTENT LAYER: Full-screen camera preview
            cameraPreviewLayer

            // FUNCTIONAL LAYER: Floating controls with Liquid Glass
            if showingControls {
                VStack {
                    topBarControls
                    Spacer()
                    bottomControls
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Settings bottom sheet
            if showingSettings {
                settingsSheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showingControls.toggle()
            }
        }
    }

    // MARK: - Content Layer

    private var cameraPreviewLayer: some View {
        GeometryReader { geometry in
            ZStack {
                // Static preview image
                Image("tablet", bundle: .main)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .scaleEffect(zoomLevel)

                // Subtle grid overlay (only visible when controls showing)
                if showingControls {
                    GridOverlay()
                        .opacity(0.2)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Functional Layer - Top Controls

    private var topBarControls: some View {
        HStack(spacing: 16) {
            // Close button
            Button(action: { print("Close tapped") }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            // Flash toggle
            Button(action: toggleFlash) {
                Label(flashMode.rawValue, systemImage: flashMode.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            // Settings button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingSettings.toggle()
                }
            }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    // MARK: - Functional Layer - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 24) {
            // Zoom control (minimal discrete buttons)
            HStack(spacing: 20) {
                ForEach(0..<zoomLevels.count, id: \.self) { index in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedZoomIndex = index
                            zoomLevel = zoomLevels[index]
                        }
                        print("Zoom changed to \(zoomLevels[index])x")
                    }) {
                        Text("\(zoomLevels[index], specifier: "%.1f")x")
                            .font(.system(size: 14, weight: selectedZoomIndex == index ? .semibold : .regular))
                            .foregroundStyle(selectedZoomIndex == index ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if selectedZoomIndex == index {
                                    Capsule().fill(.ultraThinMaterial)
                                }
                            }
                    }
                }
            }

            // Shutter button with minimal design
            VStack(spacing: 12) {
                Button(action: capturePhoto) {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 3)
                            .frame(width: 70, height: 70)

                        Circle()
                            .fill(.white)
                            .frame(width: 60, height: 60)
                    }
                }

                // Subtle photo counter
                if photoCount > 0 {
                    Text("\(photoCount) photo\(photoCount == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(.bottom, 50)
    }

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Drag handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)

                // Settings content
                VStack(alignment: .leading, spacing: 20) {
                    Text("Camera Settings")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)

                    // Capture mode
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Capture Mode")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: 12) {
                            ForEach([CaptureMode.singleItem, CaptureMode.multiItem], id: \.self) { mode in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        captureMode = mode
                                    }
                                    print("Capture mode: \(mode.displayName)")
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: mode.iconName)
                                            .font(.system(size: 20))
                                        Text(mode.displayName)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(captureMode == mode ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(captureMode == mode ? .white.opacity(0.2) : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(.white.opacity(captureMode == mode ? 0.4 : 0.2), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }

                    // Flash mode
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Flash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: 12) {
                            ForEach(FlashMode.allCases, id: \.self) { mode in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        flashMode = mode
                                    }
                                    print("Flash mode: \(mode.rawValue)")
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: mode.iconName)
                                            .font(.system(size: 18))
                                        Text(mode.rawValue)
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundStyle(flashMode == mode ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(flashMode == mode ? .white.opacity(0.2) : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(.ultraThinMaterial) // Standard material in content layer
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .background(
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingSettings = false
                    }
                }
        )
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
            photoCount += 1
        }

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

// MARK: - Supporting Views

/// Subtle grid overlay for composition assistance
struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Vertical lines (rule of thirds)
                let third = geometry.size.width / 3
                path.move(to: CGPoint(x: third, y: 0))
                path.addLine(to: CGPoint(x: third, y: geometry.size.height))
                path.move(to: CGPoint(x: third * 2, y: 0))
                path.addLine(to: CGPoint(x: third * 2, y: geometry.size.height))

                // Horizontal lines (rule of thirds)
                let thirdHeight = geometry.size.height / 3
                path.move(to: CGPoint(x: 0, y: thirdHeight))
                path.addLine(to: CGPoint(x: geometry.size.width, y: thirdHeight))
                path.move(to: CGPoint(x: 0, y: thirdHeight * 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: thirdHeight * 2))
            }
            .stroke(.white, lineWidth: 0.5)
        }
    }
}

// MARK: - Previews

#Preview("Minimalist Camera - Light") {
    CameraPrototype1_Minimalist()
        .preferredColorScheme(.light)
}

#Preview("Minimalist Camera - Dark") {
    CameraPrototype1_Minimalist()
        .preferredColorScheme(.dark)
}

#Preview("Minimalist Camera - Settings Open") {
    CameraPrototype1_Minimalist()
        .onAppear {
            // Simulate settings being open
        }
}
