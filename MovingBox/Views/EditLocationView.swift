//
//  EditLocationView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import SwiftData
import SwiftUI
import PhotosUI

struct EditLocationView: View {
    @EnvironmentObject var router: Router
    @Bindable var location: InventoryLocation
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    @State private var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        Form {
            Section {
                if let uiImage = location.photo {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Select Image", systemImage: "photo")
                }
            }
            Section("Location Name") {
                TextField("Attic, Basement, Kitchen, Office, etc.", text: $location.name)
            }
            Section("Location Description") {
                TextField("Enter a Description", text: $location.desc)
            }
//            Section("Parent") {
//                Picker("Parent Location", selection: $location.parentLocation) {
//                    Text("None")
//                        .tag(Optional<InventoryLocation>.none)
//                    
//                    if locations.isEmpty == false {
//                        Divider()
//                        ForEach(locations) { location in
//                            Text(location.name)
//                                .tag(Optional(location))
//                        }
//                    }
//                }
//            }
        }
        .navigationTitle("Edit Location")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto, loadPhoto)
    }
    
    func loadPhoto() {
        Task { @MainActor in
            location.data = try await selectedPhoto?.loadTransferable(type: Data.self)
        }
    }
    
}

#Preview {
    do {
        let previewer = try Previewer()
        
        return EditLocationView(location: previewer.location)
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
