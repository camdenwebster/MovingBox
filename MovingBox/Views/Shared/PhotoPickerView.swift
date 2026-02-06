import PhotosUI
import SwiftUI

struct PhotoPickerView<T: PhotoManageable>: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var model: T
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
        model: Binding<T>,
        loadedImage: Binding<UIImage?>,
        isLoading: Binding<Bool>,
        showRemoveButton: Bool = true
    ) {
        self._model = model
        self._loadedImage = loadedImage
        self._isLoading = isLoading
        self.showRemoveButton = showRemoveButton
        self.contentProvider = nil
    }

    init(
        model: Binding<T>,
        loadedImage: Binding<UIImage?>,
        isLoading: Binding<Bool>,
        showRemoveButton: Bool = true,
        @ViewBuilder content: @escaping (Binding<Bool>) -> some View
    ) {
        self._model = model
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
                        .foregroundColor(.white)
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

            if showRemoveButton && (model.imageURL != nil) {
                Button("Remove Photo", role: .destructive) {
                    model.imageURL = nil
                    loadedImage = nil
                    try? modelContext.save()
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
        #if os(iOS)
            .movingBoxFullScreenCoverCompat(isPresented: $showCamera) {
                SimpleCameraView(capturedImage: $cameraImage)
            }
        #else
            .sheet(isPresented: $showCamera) {
                SimpleCameraView(capturedImage: $cameraImage)
            }
        #endif
        .onChange(of: cameraImage) { _, newImage in
            if let image = newImage {
                Task {
                    await MainActor.run {
                        isLoading = true
                    }

                    await handleNewImage(image)

                    await MainActor.run {
                        isLoading = false
                        cameraImage = nil
                        showCamera = false
                    }
                }
            }
        }
    }

    private func handleNewImage(_ image: UIImage) async {
        do {
            let id = UUID().uuidString
            let imageURL = try await OptimizedImageManager.shared.saveImage(image, id: id)

            await MainActor.run {
                // Update the loaded image first to ensure immediate UI feedback
                loadedImage = image
                // Then update the model
                model.imageURL = imageURL
                try? modelContext.save()
            }
        } catch {
            await MainActor.run {
                print("Failed to save image: \(error)")
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
            // Load the photo data (this may take time for iCloud downloads)
            let data = try await item.loadTransferable(type: Data.self)

            guard let data = data, let uiImage = UIImage(data: data) else {
                await MainActor.run {
                    print("Failed to create UIImage from photo data")
                }
                return
            }

            // Process the image
            await handleNewImage(uiImage)

        } catch {
            await MainActor.run {
                print("Failed to load photo: \(error)")
            }
        }
    }
}
