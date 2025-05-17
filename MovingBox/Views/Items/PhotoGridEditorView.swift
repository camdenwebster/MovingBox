import SwiftUI
import PhotosUI

struct PhotoGridEditorView<T: PhotoManageable>: View {
    @Binding var model: T
    @Binding var loadedImages: [UIImage]
    @Binding var isLoading: Bool
    @State private var showPhotoLimitAlert = false
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let maxPhotos = 10
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(loadedImages.indices, id: \.self) { index in
                imageCell(for: index)
            }
            
            if loadedImages.count < maxPhotos {
                PhotoPickerView(
                    model: $model,
                    loadedImages: $loadedImages,
                    isLoading: $isLoading
                ) { showPicker in
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
    
    private func imageCell(for index: Int) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                Image(uiImage: loadedImages[index])
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(model.primaryImageIndex == index ? Color.accentColor : Color.secondary.opacity(0.3), 
                                   lineWidth: model.primaryImageIndex == index ? 2 : 1)
                    )
                
                HStack(spacing: 4) {
                    if index > 0 {
                        moveButton(direction: .left, for: index)
                    }
                    deleteButton(for: index)
                    if index < loadedImages.count - 1 {
                        moveButton(direction: .right, for: index)
                    }
                }
                .padding(4)
            }
            .onTapGesture {
                model.primaryImageIndex = index
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private enum MoveDirection {
        case left, right
    }
    
    private func moveButton(direction: MoveDirection, for index: Int) -> some View {
        Button {
            let newIndex = direction == .left ? index - 1 : index + 1
            moveImage(from: index, to: newIndex)
        } label: {
            Image(systemName: direction == .left ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
                .foregroundStyle(.white, .blue)
                .background(Circle().fill(.black.opacity(0.5)))
        }
    }
    
    private func deleteButton(for index: Int) -> some View {
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
        }
    }
    
    private func moveImage(from source: Int, to destination: Int) {
        guard source >= 0, source < loadedImages.count,
              destination >= 0, destination < loadedImages.count else {
            return
        }
        
        withAnimation(.spring(duration: 0.3)) {
            let image = loadedImages.remove(at: source)
            let url = model.imageURLs.remove(at: source)
            
            loadedImages.insert(image, at: destination)
            model.imageURLs.insert(url, at: destination)
            
            if model.primaryImageIndex == source {
                model.primaryImageIndex = destination
            } else if model.primaryImageIndex == destination {
                model.primaryImageIndex = source
            }
        }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
