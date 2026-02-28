import Dependencies
import SQLiteData
import SwiftUI

struct HorizontalPhotoScrollView: View {
    @Dependency(\.defaultDatabase) var database
    let itemID: UUID
    let isEditing: Bool
    let onAddPhoto: () -> Void
    let onDeletePhoto: (UUID) -> Void
    let showOnlyThumbnails: Bool
    let onThumbnailTap: ((Int) -> Void)?

    @State private var photos: [SQLiteInventoryItemPhoto] = []
    @State private var loadedImages: [UUID: UIImage] = [:]
    @State private var isLoadingImages = false
    @State private var selectedImageIndex: Int = 0

    init(
        itemID: UUID,
        isEditing: Bool,
        onAddPhoto: @escaping () -> Void,
        onDeletePhoto: @escaping (UUID) -> Void,
        showOnlyThumbnails: Bool = false,
        onThumbnailTap: ((Int) -> Void)? = nil
    ) {
        self.itemID = itemID
        self.isEditing = isEditing
        self.onAddPhoto = onAddPhoto
        self.onDeletePhoto = onDeletePhoto
        self.showOnlyThumbnails = showOnlyThumbnails
        self.onThumbnailTap = onThumbnailTap
    }

    // Image dimensions
    private let primaryImageHeight: CGFloat = 300
    private let thumbnailSize: CGFloat = 80

    private var orderedImages: [(id: UUID, image: UIImage)] {
        photos.compactMap { photo in
            guard let image = loadedImages[photo.id] else { return nil }
            return (id: photo.id, image: image)
        }
    }

    var body: some View {
        Group {
            if showOnlyThumbnails {
                thumbnailOnlyMode
            } else if !orderedImages.isEmpty {
                fullPhotoMode
            } else if isEditing {
                emptyEditMode
            }
        }
        .task(id: itemID) {
            await loadPhotos()
        }
    }

    private var thumbnailOnlyMode: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(orderedImages.enumerated()), id: \.element.id) { index, entry in
                    ThumbnailView(
                        image: entry.image,
                        isSelected: index == selectedImageIndex,
                        isPrimary: index == 0,
                        isEditing: isEditing,
                        onTap: {
                            selectedImageIndex = index
                            onThumbnailTap?(index)
                        },
                        onDelete: {
                            onDeletePhoto(entry.id)
                        }
                    )
                }

                if isEditing {
                    AddPhotoThumbnailButton(onTap: onAddPhoto)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: thumbnailSize + 20)
    }

    private var fullPhotoMode: some View {
        VStack {
            if selectedImageIndex < orderedImages.count {
                Image(uiImage: orderedImages[selectedImageIndex].image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: primaryImageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: UIConstants.cornerRadius))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(orderedImages.enumerated()), id: \.element.id) { index, entry in
                        ThumbnailView(
                            image: entry.image,
                            isSelected: index == selectedImageIndex,
                            isPrimary: index == 0,
                            isEditing: isEditing,
                            onTap: {
                                selectedImageIndex = index
                            },
                            onDelete: {
                                onDeletePhoto(entry.id)
                            }
                        )
                    }

                    if isEditing {
                        AddPhotoThumbnailButton(onTap: onAddPhoto)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: thumbnailSize + 20)
        }
    }

    private var emptyEditMode: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                .fill(Color.gray.opacity(0.1))
                .frame(height: primaryImageHeight)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No photos yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                )

            HStack {
                AddPhotoThumbnailButton(onTap: onAddPhoto)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: thumbnailSize + 20)
        }
    }

    private func loadPhotos() async {
        isLoadingImages = true
        defer { isLoadingImages = false }

        guard
            let fetchedPhotos = try? await database.read({ db in
                try SQLiteInventoryItemPhoto.photos(for: itemID, in: db)
            })
        else { return }

        photos = fetchedPhotos

        var images: [UUID: UIImage] = [:]
        for photo in fetchedPhotos {
            if let image = UIImage(data: photo.data) {
                images[photo.id] = image
            }
        }
        loadedImages = images
        selectedImageIndex = 0
    }
}

struct ThumbnailView: View {
    let image: UIImage
    let isSelected: Bool
    let isPrimary: Bool
    let isEditing: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    private let imageSize: CGFloat = 80

    var body: some View {
        ZStack {
            Button(action: onTap) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
            }
            .buttonStyle(.plain)

            if isEditing {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                                .background(.white, in: Circle())
                        }
                    }
                    Spacer()
                }
                .padding(4)
            }
        }
    }

    private var strokeColor: Color {
        if isSelected {
            return .blue
        } else if isPrimary {
            return .blue.opacity(0.6)
        } else {
            return .gray.opacity(0.3)
        }
    }

    private var strokeWidth: CGFloat {
        isSelected ? 3 : (isPrimary ? 2 : 1)
    }
}

struct AddPhotoThumbnailButton: View {
    let onTap: () -> Void

    private let imageSize: CGFloat = 80

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .frame(width: imageSize, height: imageSize)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("Add")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add-photo-thumbnail-button")
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    HorizontalPhotoScrollView(
        itemID: UUID(),
        isEditing: true,
        onAddPhoto: {},
        onDeletePhoto: { _ in }
    )
}
