import SwiftUI
import PhotosUI
import SwiftData

struct NewItemPhotoPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router

    let location: InventoryLocation?

    // State variables for PhotoPickerView
    @State private var loadedImages: [UIImage] = []
    @State private var isLoading = false

    // Dummy PhotoManageable for PhotoPickerView
    // Since we are creating a *new* item, there isn't a persistent model yet.
    // We use a temporary instance that PhotoPickerView can bind to for image handling.
    @State private var tempItem = InventoryItem()

    var body: some View {
        VStack {
            Text("Add photos for your new item")
                .font(.headline)
                .padding()

            PhotoPickerView(
                model: $tempItem, // Bind to the temporary item
                loadedImages: $loadedImages,
                isLoading: $isLoading,
                showRemoveButton: false // Don't show remove button here, only done/cancel
            ) { showPicker in
                VStack {
                    if loadedImages.isEmpty {
                        // Initial state: Add photo button
                        AddPhotoButton {
                            showPicker.wrappedValue = true
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.secondary)
                        .padding()
                    } else {
                        // After photos are added: Photo grid editor
                         PhotoGridEditorView(
                            model: $tempItem,
                            loadedImages: $loadedImages,
                            isLoading: $isLoading
                        )
                    }
                }
            }

            if !loadedImages.isEmpty {
                Button("Continue") {
                    // TODO: Navigate to ItemCreationFlowView with the selected photos
                    // This requires modifying ItemCreationFlowView to accept an array of images.
                    print("Continue with \(loadedImages.count) photos")
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .navigationTitle("Add Photos")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NewItemPhotoPickerView(location: nil)
        .modelContainer(try! ModelContainer(for: InventoryLocation.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        .environmentObject(Router())
}