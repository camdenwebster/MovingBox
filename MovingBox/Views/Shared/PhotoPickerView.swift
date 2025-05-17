import SwiftUI
import PhotosUI

struct PhotoPickerView<T: PhotoManageable>: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var model: T
    @Binding var loadedImages: [UIImage]
    @Binding var isLoading: Bool
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showPhotoSourceAlert = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var tempCameraImages: [UIImage] = []
    @State private var showPhotoLimitAlert = false
    let showRemoveButton: Bool
    private let contentProvider: ((Binding<Bool>) -> AnyView)?
    private let maxPhotos = 10

    init(
        model: Binding<T>,
        loadedImages: Binding<[UIImage]>,
        isLoading: Binding<Bool>,
        showRemoveButton: Bool = true
    ) {
        self._model = model
        self._loadedImages = loadedImages
        self._isLoading = isLoading
        self.showRemoveButton = showRemoveButton
        self.contentProvider = nil
    }

    init(
        model: Binding<T>,
        loadedImages: Binding<[UIImage]>,
        isLoading: Binding<Bool>,
        showRemoveButton: Bool = true,
        @ViewBuilder content: @escaping (Binding<Bool>) -> some View
    ) {
        self._model = model
        self._loadedImages = loadedImages
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
                if loadedImages.count >= maxPhotos {
                    showPhotoLimitAlert = true
                } else {
                    tempCameraImages = []
                    showCamera = true
                }
            }
            .accessibilityIdentifier("takePhoto")
            Button("Choose from Library") {
                 if loadedImages.count >= maxPhotos {
                     showPhotoLimitAlert = true
                 } else {
                    showPhotoPicker = true
                 }
            }
            .accessibilityIdentifier("chooseFromLibrary")
            if showRemoveButton && (!model.imageURLs.isEmpty) {
                Button("Remove All Photos", role: .destructive) {
                    model.imageURLs = []
                    loadedImages = []
                    model.primaryImageIndex = 0
                    try? modelContext.save()
                }
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotos,
            maxSelectionCount: maxPhotos - loadedImages.count,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotos) { _, newValue in
            Task {
                await loadPhotos(from: newValue)
                selectedPhotos = [] 
            }
        }
        .sheet(isPresented: $showCamera) {
            SimpleCameraView(capturedImages: $tempCameraImages) {
                Task {
                    await handleNewImagesFromCamera(tempCameraImages)
                    tempCameraImages = [] 
                    showCamera = false 
                }
            }
        }
        .alert("Photo Limit Reached", isPresented: $showPhotoLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can add up to 10 photos per item.")
        }
    }

    private func handleNewImagesFromCamera(_ images: [UIImage]) async {
        isLoading = true
        defer { isLoading = false }

        for image in images {
            if loadedImages.count < maxPhotos {
                do {
                    let id = UUID().uuidString
                    if let imageURL = try await OptimizedImageManager.shared.saveImage(image, id: id) {
                        model.imageURLs.append(imageURL)
                        loadedImages.append(image)
                    }
                } catch {
                    print("Failed to save image from camera: \(error)")
                }
            } else {
                showPhotoLimitAlert = true
                break 
            }
        }
        try? modelContext.save()
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        isLoading = true
        defer { isLoading = false }

        for item in items {
             if loadedImages.count < maxPhotos {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                       let id = UUID().uuidString
                       if let imageURL = try await OptimizedImageManager.shared.saveImage(uiImage, id: id) {
                           model.imageURLs.append(imageURL)
                           loadedImages.append(uiImage)
                       }
                   }
               } catch {
                   print("Failed to load photo from library: \(error)")
               }
           } else {
               showPhotoLimitAlert = true
               break 
           }
        }
        try? modelContext.save()
    }
}
