import SwiftUI
import PhotosUI

struct PhotoPickerView<T: PhotoManageable>: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var model: T
    @Binding var loadedImage: UIImage?
    @Binding var isLoading: Bool
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoSourceAlert = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
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
            Button("Choose from Library") {
                showPhotoPicker = true
            }
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
            Task {
                if let photo = newValue {
                    await loadPhoto(from: photo)
                    selectedPhoto = nil
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(
                showingImageAnalysis: .constant(false),
                analyzingImage: .constant(nil)
            ) { image, _, completion async -> Void in
                await handleNewImage(image)
                await completion()
            }
        }
    }
    
    private func handleNewImage(_ image: UIImage) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let id = UUID().uuidString
            let imageURL = try await OptimizedImageManager.shared.saveImage(image, id: id)
            model.imageURL = imageURL
            loadedImage = image
            try? modelContext.save()
        } catch {
            print("Failed to save image: \(error)")
        }
    }
    
    private func loadPhoto(from item: PhotosPickerItem) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await handleNewImage(uiImage)
            }
        } catch {
            print("Failed to load photo: \(error)")
        }
    }
}
