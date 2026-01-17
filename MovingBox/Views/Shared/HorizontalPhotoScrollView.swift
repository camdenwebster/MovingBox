import SwiftUI

struct HorizontalPhotoScrollView: View {
    let item: InventoryItem
    let isEditing: Bool
    let onAddPhoto: () -> Void
    let onDeletePhoto: (String) -> Void
    let showOnlyThumbnails: Bool
    let onThumbnailTap: ((Int) -> Void)?

    @State private var loadedImages: [UIImage] = []
    @State private var primaryImage: UIImage?
    @State private var isLoadingImages = false
    @State private var selectedImageIndex: Int = 0

    init(
        item: InventoryItem,
        isEditing: Bool,
        onAddPhoto: @escaping () -> Void,
        onDeletePhoto: @escaping (String) -> Void,
        showOnlyThumbnails: Bool = false,
        onThumbnailTap: ((Int) -> Void)? = nil
    ) {
        self.item = item
        self.isEditing = isEditing
        self.onAddPhoto = onAddPhoto
        self.onDeletePhoto = onDeletePhoto
        self.showOnlyThumbnails = showOnlyThumbnails
        self.onThumbnailTap = onThumbnailTap
    }

    // Image dimensions
    private let primaryImageHeight: CGFloat = 300
    private let thumbnailSize: CGFloat = 80

    var allImages: [UIImage] {
        var images: [UIImage] = []
        if let primaryImage = primaryImage {
            images.append(primaryImage)
        }
        images.append(contentsOf: loadedImages)
        return images
    }

    var body: some View {
        Group {
            if showOnlyThumbnails {
                // Thumbnail-only mode
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // All image thumbnails
                        ForEach(Array(allImages.enumerated()), id: \.offset) { index, image in
                            ThumbnailView(
                                image: image,
                                isSelected: index == selectedImageIndex,
                                isPrimary: index == 0,
                                isEditing: isEditing,
                                onTap: {
                                    selectedImageIndex = index
                                    onThumbnailTap?(index)
                                },
                                onDelete: {
                                    if index == 0 {
                                        // Deleting primary image
                                        if let imageURL = item.imageURL {
                                            onDeletePhoto(imageURL.absoluteString)
                                        }
                                    } else {
                                        // Deleting secondary image
                                        let secondaryIndex = index - 1
                                        if secondaryIndex < item.secondaryPhotoURLs.count {
                                            let urlString = item.secondaryPhotoURLs[secondaryIndex]
                                            onDeletePhoto(urlString)
                                        }
                                    }
                                }
                            )
                        }

                        // Add photo button (only in editing mode)
                        if isEditing {
                            AddPhotoThumbnailButton(onTap: onAddPhoto)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: thumbnailSize + 20)
            } else if hasPhotos {
                // Primary image display
                if !allImages.isEmpty {
                    Image(uiImage: allImages[selectedImageIndex])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: primaryImageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cornerRadius))
                }

                // Thumbnail scroll view
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // All image thumbnails
                        ForEach(Array(allImages.enumerated()), id: \.offset) { index, image in
                            ThumbnailView(
                                image: image,
                                isSelected: index == selectedImageIndex,
                                isPrimary: index == 0,
                                isEditing: isEditing,
                                onTap: {
                                    selectedImageIndex = index
                                },
                                onDelete: {
                                    if index == 0 {
                                        // Deleting primary image
                                        if let imageURL = item.imageURL {
                                            onDeletePhoto(imageURL.absoluteString)
                                        }
                                    } else {
                                        // Deleting secondary image
                                        let secondaryIndex = index - 1
                                        if secondaryIndex < item.secondaryPhotoURLs.count {
                                            let urlString = item.secondaryPhotoURLs[secondaryIndex]
                                            onDeletePhoto(urlString)
                                        }
                                    }
                                }
                            )
                        }

                        // Add photo button (only in editing mode)
                        if isEditing {
                            AddPhotoThumbnailButton(onTap: onAddPhoto)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: thumbnailSize + 20)
            } else if isEditing {
                // Show add photo button when no photos exist
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
        }
        .onAppear {
            loadImages()
        }
        .onChange(of: item.imageURL) { _, _ in
            loadImages()
            selectedImageIndex = 0
        }
        .onChange(of: item.secondaryPhotoURLs) { _, _ in
            Task {
                await loadSecondaryImages()
            }
        }
    }

    private var hasPhotos: Bool {
        item.imageURL != nil || !item.secondaryPhotoURLs.isEmpty
    }

    private func loadImages() {
        Task {
            await MainActor.run {
                isLoadingImages = true
            }

            // Load primary image
            if let imageURL = item.imageURL {
                do {
                    let image = try await OptimizedImageManager.shared.loadImage(url: imageURL)
                    await MainActor.run {
                        primaryImage = image
                    }
                } catch {
                    print("Failed to load primary image: \(error)")
                }
            }

            // Load secondary images
            await loadSecondaryImages()

            await MainActor.run {
                isLoadingImages = false
            }
        }
    }

    private func loadSecondaryImages() async {
        if !item.secondaryPhotoURLs.isEmpty {
            do {
                let images = try await OptimizedImageManager.shared.loadSecondaryImages(
                    from: item.secondaryPhotoURLs)
                await MainActor.run {
                    loadedImages = images
                }
            } catch {
                print("Failed to load secondary images: \(error)")
            }
        } else {
            await MainActor.run {
                loadedImages = []
            }
        }
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

            // Delete button (only show in edit mode)
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
    // Create a sample item for preview
    let sampleItem = InventoryItem(
        title: "Sample Item",
        quantityString: "1",
        quantityInt: 1,
        desc: "Sample description",
        serial: "",
        model: "",
        make: "",
        location: nil,
        labels: [],
        price: Decimal.zero,
        insured: false,
        assetId: "",
        notes: "",
        showInvalidQuantityAlert: false
    )

    HorizontalPhotoScrollView(
        item: sampleItem,
        isEditing: true,
        onAddPhoto: {},
        onDeletePhoto: { _ in }
    )
}
