import SwiftUI
import PhotosUI

struct PhotoGridEditorView: View {
    @Binding var model: PhotoManageable
    @Binding var loadedImages: [UIImage]
    @Binding var isLoading: Bool
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let maxPhotos = 10
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(loadedImages.indices, id: \.self) { index in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: loadedImages[index])
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    
                    Button {
                        loadedImages.remove(at: index)
                        model.imageURLs.remove(at: index)
                        if model.primaryImageIndex >= model.imageURLs.count {
                            model.primaryImageIndex = max(0, model.imageURLs.count - 1)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, Color.red)
                            .background(Circle().fill(.black.opacity(0.5)))
                            .padding(4)
                    }
                }
            }
            
            if loadedImages.count < maxPhotos {
                PhotoPickerView(model: $model, loadedImages: $loadedImages, isLoading: $isLoading) { showPicker in
                    Button {
                        showPicker.wrappedValue = true
                    } label: {
                        VStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                            Text("Add Photo")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}