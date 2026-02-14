import PhotosUI
import SwiftUI

struct PhotoPickerView: View {
    @Binding var loadedImage: UIImage?
    @Binding var isLoading: Bool
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoSourceAlert = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var cameraImage: UIImage? = nil
    let showRemoveButton: Bool
    private let contentProvider: ((Binding<Bool>) -> AnyView)?

    init(
        loadedImage: Binding<UIImage?>,
        isLoading: Binding<Bool>,
        showRemoveButton: Bool = true
    ) {
        self._loadedImage = loadedImage
        self._isLoading = isLoading
        self.showRemoveButton = showRemoveButton
        self.contentProvider = nil
    }

    init(
        loadedImage: Binding<UIImage?>,
        isLoading: Binding<Bool>,
        showRemoveButton: Bool = true,
        @ViewBuilder content: @escaping (Binding<Bool>) -> some View
    ) {
        self._loadedImage = loadedImage
        self._isLoading = isLoading
        self.showRemoveButton = showRemoveButton
        self.contentProvider = { AnyView(content($0)) }
    }

    var body: some View {
        Group {
            if let provider = contentProvider {
                provider($showPhotoSourceAlert)
            } else {
                Button {
                    showPhotoSourceAlert = true
                } label: {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(.black.opacity(0.6)))
                        .padding(8)
                }
            }
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
            Button("Take Photo") {
                showCamera = true
            }
            .accessibilityIdentifier("takePhoto")

            Button("Choose from Library") {
                showPhotoPicker = true
            }
            .accessibilityIdentifier("chooseFromLibrary")

            if showRemoveButton && loadedImage != nil {
                Button("Remove Photo", role: .destructive) {
                    loadedImage = nil
                }
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhoto,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhoto) { _, newValue in
            if let photo = newValue {
                Task {
                    await loadPhoto(from: photo)
                    selectedPhoto = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            SimpleCameraView(capturedImage: $cameraImage)
        }
        .onChange(of: cameraImage) { _, newImage in
            if let image = newImage {
                Task {
                    await MainActor.run {
                        isLoading = true
                    }

                    let optimized = await OptimizedImageManager.shared.optimizeImage(image)
                    await MainActor.run {
                        loadedImage = optimized
                    }

                    await MainActor.run {
                        isLoading = false
                        cameraImage = nil
                        showCamera = false
                    }
                }
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem) async {
        await MainActor.run {
            isLoading = true
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        do {
            let data = try await item.loadTransferable(type: Data.self)

            guard let data = data, let uiImage = UIImage(data: data) else {
                await MainActor.run {
                    print("Failed to create UIImage from photo data")
                }
                return
            }

            let optimized = await OptimizedImageManager.shared.optimizeImage(uiImage)
            await MainActor.run {
                loadedImage = optimized
            }

        } catch {
            await MainActor.run {
                print("Failed to load photo: \(error)")
            }
        }
    }
}
