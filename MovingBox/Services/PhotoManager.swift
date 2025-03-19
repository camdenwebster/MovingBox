import SwiftUI
import PhotosUI
import SwiftData

class PhotoManager {
    static func loadPhoto(from item: PhotosPickerItem?, quality: CGFloat = 0.5) async throws -> Data? {
        guard let imageData = try await item?.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: imageData),
              let optimizedImage = ImageEncoder(image: uiImage).optimizeImage(),
              let compressedData = optimizedImage.jpegData(compressionQuality: quality) else {
            return nil
        }
        return compressedData
    }
    
    @MainActor
    static func loadAndSavePhoto(from item: PhotosPickerItem?, to model: Any, quality: CGFloat = 0.5) async {
        do {
            if let data = try await loadPhoto(from: item, quality: quality) {
                switch model {
                case let inventoryItem as InventoryItem:
                    inventoryItem.data = data
                case let location as InventoryLocation:
                    location.data = data
                case let home as Home:
                    home.data = data
                default:
                    print("Unsupported model type for photo saving")
                }
            }
        } catch {
            print("Error loading photo: \(error)")
        }
    }
}
