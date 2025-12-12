import SwiftUI
import PhotosUI
import UIKit

// MARK: - Prototype 1: Zone-Based Control Layout

struct ZoneBasedCameraPrototypeView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var selectedCaptureMode: CaptureMode = .singleItem
    @State private var capturedImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingPhotoPicker = false
    @State private var showingModeSwitchConfirmation = false
    @State private var pendingMode: CaptureMode?
    @State private var localZoomIndex: Int = 0
    let zoomLevels = [0.5, 1.0, 2.0, 5.0]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // TOP SETTINGS BAR
                HStack {
                    Button(action: {}) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)

                    Spacer()

                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14))
                        Text("Auto")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)

                    Spacer()

                    Button(action: {}) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .frame(width: 44, height: 44)
                }
                .frame(height: 60)
                .padding(.horizontal, 16)

                // CAMERA PREVIEW
                ZStack {
                    Image("blender", bundle: .main)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()

                    // Square guide
                    let squareSize: CGFloat = 280
                    Rectangle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        .frame(width: squareSize, height: squareSize)

                    // ZOOM CONTROLS (Floating over preview)
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            ForEach(Array(zoomLevels.enumerated()), id: \.offset) { index, zoom in
                                Button(action: { localZoomIndex = index }) {
                                    Text(zoom == 1.0 ? "1x" : String(format: "%.1fx", zoom))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(height: 32)
                                        .frame(maxWidth: .infinity)
                                        .background(localZoomIndex == index ? Color.yellow.opacity(0.9) : Color.black.opacity(0.4))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)
                        .padding(20)
                    }
                }

                // MODE SELECTION BAR
                Picker("Capture Mode", selection: $selectedCaptureMode) {
                    Text("Single Item").tag(CaptureMode.singleItem)
                    Text("Multi Item").tag(CaptureMode.multiItem)
                }
                .pickerStyle(.segmented)
                .padding(16)
                .background(Color.white.opacity(0.05))

                // THUMBNAILS (Single mode only)
                if selectedCaptureMode == .singleItem && !capturedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 70, height: 70)
                                        .cornerRadius(8)

                                    Button(action: { capturedImages.remove(at: index) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.red)
                                    }
                                    .offset(x: 8, y: -8)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .frame(height: 100)
                    .background(Color.white.opacity(0.05))
                }

                // CAPTURE ZONE
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("\(capturedImages.count)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text("of \(selectedCaptureMode == .singleItem ? (settings.isPro ? 5 : 1) : 1)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, alignment: .center)

                    Spacer()

                    // Shutter button
                    Button(action: { capturedImages.append(UIImage(named: "blender") ?? UIImage()) }) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 76, height: 76)
                            .overlay(
                                Circle()
                                    .stroke(Color.green.opacity(0.5), lineWidth: 4)
                                    .frame(width: 88, height: 88)
                            )
                    }

                    Spacer()

                    VStack(spacing: 8) {
                        Button(action: { showingPhotoPicker = true }) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(22)
                        }

                        if !capturedImages.isEmpty {
                            Button(action: { capturedImages.removeAll() }) {
                                Text("↻")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.red.opacity(0.3))
                                    .cornerRadius(22)
                            }
                        }
                    }
                }
                .frame(height: 120)
                .padding(20)
                .background(Color.black)
            }
        }
    }
}

// MARK: - Prototype 2: Floating Action Button (FAB) System

struct FABSystemCameraPrototypeView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var selectedCaptureMode: CaptureMode = .singleItem
    @State private var capturedImages: [UIImage] = []
    @State private var showSettings = false
    @State private var localZoomIndex: Int = 0
    @State private var showFullThumbnails = false
    let zoomLevels = [0.5, 1.0, 2.0, 5.0]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // MINIMAL HEADER
                HStack {
                    Button(action: {}) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 16)
                .background(Color.black.opacity(0.3))

                // CAMERA PREVIEW
                ZStack {
                    Image("blender", bundle: .main)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()

                    Rectangle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        .frame(width: 280, height: 280)

                    // RIGHT-EDGE FAB STACK
                    VStack(alignment: .trailing, spacing: 12) {
                        // Settings FAB
                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gear")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(22)
                        }

                        // Mode selector compact
                        HStack(spacing: 0) {
                            Button(action: { selectedCaptureMode = .singleItem }) {
                                Text("S")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(selectedCaptureMode == .singleItem ? Color.green : Color.white.opacity(0.2))
                                    .cornerRadius(6, corners: [.topLeft, .bottomLeft])
                            }
                            Button(action: { selectedCaptureMode = .multiItem }) {
                                Text("M")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(selectedCaptureMode == .multiItem ? Color.blue : Color.white.opacity(0.2))
                                    .cornerRadius(6, corners: [.topRight, .bottomRight])
                            }
                        }
                        .frame(width: 80)

                        Spacer()

                        // ZOOM STRIP
                        VStack(spacing: 8) {
                            ForEach(Array(zoomLevels.enumerated()), id: \.offset) { index, zoom in
                                Button(action: { localZoomIndex = index }) {
                                    Text(zoom == 1.0 ? "1x" : String(format: "%.1fx", zoom))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 32)
                                        .background(localZoomIndex == index ? Color.yellow.opacity(0.9) : Color.white.opacity(0.2))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                // THUMBNAILS (Collapsed, single mode only)
                if selectedCaptureMode == .singleItem && !capturedImages.isEmpty {
                    HStack(spacing: 8) {
                        Button(action: { showFullThumbnails.toggle() }) {
                            HStack(spacing: 4) {
                                ForEach(0..<min(3, capturedImages.count), id: \.self) { index in
                                    Image(uiImage: capturedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(6)
                                }
                                if capturedImages.count > 3 {
                                    Text("+\(capturedImages.count - 3)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.6))
                }

                // SHUTTER FAB (Right edge, bottom)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { capturedImages.append(UIImage(named: "blender") ?? UIImage()) }) {
                            Circle()
                                .fill(selectedCaptureMode == .singleItem ? Color.green : Color.blue)
                                .frame(width: 82, height: 82)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                                        .frame(width: 82, height: 82)
                                )
                        }
                        .padding(30)
                    }
                }
            }
        }
    }
}

// MARK: - Prototype 3: Two-Stage Interface

struct TwoStageCameraPrototypeView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var stage: CameraStage = .setup
    @State private var selectedCaptureMode: CaptureMode = .singleItem
    @State private var capturedImages: [UIImage] = []
    @State private var localZoomIndex: Int = 0
    let zoomLevels = [0.5, 1.0, 2.0, 5.0]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if stage == .setup {
                setupStage
            } else {
                captureStage
            }
        }
    }

    var setupStage: some View {
        VStack(spacing: 0) {
            // SETUP HEADER
            HStack {
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("Camera Setup")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { stage = .capture }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
            .frame(height: 50)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.05))

            Spacer()

            // MODE SELECTION CARDS
            VStack(spacing: 20) {
                Text("Choose Capture Mode")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    modeCard(
                        title: "SINGLE ITEM",
                        icon: "📸",
                        description: "Multiple photos of one item",
                        isSelected: selectedCaptureMode == .singleItem,
                        action: { selectedCaptureMode = .singleItem }
                    )

                    modeCard(
                        title: "MULTI ITEM",
                        icon: "📸📸",
                        description: "One photo of multiple items",
                        isSelected: selectedCaptureMode == .multiItem,
                        action: { selectedCaptureMode = .multiItem }
                    )
                }
            }
            .padding(20)

            Spacer()

            // SETTINGS PANEL
            VStack(spacing: 16) {
                Text("Camera Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Flash setting
                HStack {
                    Text("Flash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(["Auto", "On", "Off"], id: \.self) { mode in
                            Button(action: {}) {
                                Text(mode)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(height: 28)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }

                // Zoom setting
                HStack {
                    Text("Zoom")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(Array(zoomLevels.enumerated()), id: \.offset) { index, zoom in
                            Button(action: { localZoomIndex = index }) {
                                Text(zoom == 1.0 ? "1x" : String(format: "%.1fx", zoom))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(height: 28)
                                    .frame(maxWidth: .infinity)
                                    .background(localZoomIndex == index ? Color.yellow.opacity(0.7) : Color.white.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(20)
        }
    }

    var captureStage: some View {
        VStack(spacing: 0) {
            // CAPTURE HEADER (with back button)
            HStack {
                Button(action: { stage = .setup }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text(selectedCaptureMode == .singleItem ? "Single Item" : "Multi Item")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
            .frame(height: 50)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.05))

            // CAMERA PREVIEW
            ZStack {
                Image("blender", bundle: .main)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Rectangle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    .frame(width: 280, height: 280)
            }

            // THUMBNAILS (Single mode only)
            if selectedCaptureMode == .singleItem && !capturedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .cornerRadius(6)
                        }
                    }
                    .padding(12)
                }
                .frame(height: 80)
                .background(Color.white.opacity(0.05))
            }

            // SHUTTER AREA
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(capturedImages.count)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("of \(selectedCaptureMode == .singleItem ? (settings.isPro ? 5 : 1) : 1)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(width: 50)

                Spacer()

                Button(action: { capturedImages.append(UIImage(named: "blender") ?? UIImage()) }) {
                    Circle()
                        .fill(selectedCaptureMode == .singleItem ? Color.green : Color.blue)
                        .frame(width: 70, height: 70)
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(22)
                }
                .frame(width: 50)
            }
            .padding(20)
            .background(Color.black)
        }
    }

    func modeCard(title: String, icon: String, description: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 32))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: 2)
            )
        }
    }
}

enum CameraStage {
    case setup
    case capture
}

// MARK: - Helper Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    ZoneBasedCameraPrototypeView()
        .environmentObject(SettingsManager())
}
