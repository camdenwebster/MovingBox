//
//  EditHomeView.swift
//  MovingBox
//
//  Created by Camden Webster on 3/20/25.
//

import SwiftData
import SwiftUI
import PhotosUI

struct EditHomeView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @State private var homeNickName = ""
    @State private var homeAddress1 = ""
    @State private var homeAddress2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var isEditing = false
    var home: Home?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var tempUIImage: UIImage?
    
    // Computed properties
    private var isNewHome: Bool {
        home == nil
    }
    
    private var isEditingEnabled: Bool {
        isNewHome || isEditing
    }
    
    var body: some View {
        Form {
            Section {
                if let uiImage = tempUIImage ?? home?.photo {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
                if isEditingEnabled {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Select Image", systemImage: "photo")
                    }
                }
            }
            if isEditingEnabled || !homeNickName.isEmpty {
                Section("Home Nickname") {
                    TextField("Enter a nickname", text: $homeNickName)
                        .disabled(!isEditingEnabled)
                        .foregroundColor(isEditingEnabled ? .primary : .secondary)
                }
            }
            Section("Home Address") {
                TextField("Address 1", text: $homeAddress1)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                TextField("Address 2", text: $homeAddress2)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                TextField("City", text: $city)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                TextField("State", text: $state)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                TextField("Zip Code", text: $zip)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
            }
        }
        .navigationTitle(isNewHome ? "New Home" : "\(home?.name ?? "") Details")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto, loadPhoto)
        .toolbar {
            if !isNewHome {
                // Edit/Save button for existing homes
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        // Save changes
                        home?.name = homeNickName
                        home?.address1 = homeAddress1
                        home?.address2 = homeAddress2
                        home?.city = city
                        home?.state = state
                        home?.zip = Int(zip) ?? 0
                        isEditing = false
                    } else {
                        isEditing = true
                    }
                }
            } else {
                // Save button for new homes
                Button("Save") {
                    let newHome = Home(name: homeNickName, address1: homeAddress1, address2: homeAddress2, city: city, state: state, zip: Int(zip) ?? 0)
                    if let imageData = tempUIImage?.jpegData(compressionQuality: 0.8) {
                        newHome.data = imageData
                    }
                    modelContext.insert(newHome)
                    TelemetryManager.shared.trackLocationCreated(name: newHome.address1)
                    print("EditHomeView: Created new home - \(newHome.name)")
                    router.path.removeLast()
                }
                .disabled(homeAddress1.isEmpty)
            }
        }
        .onAppear {
            if let existingHome = home {
                // Initialize editing fields with existing values
                homeNickName = existingHome.name
                homeAddress1 = existingHome.address1
                homeAddress2 = existingHome.address2
                city = existingHome.city
                state = existingHome.state
                zip = String(existingHome.zip)
            }
        }
    }
    
    private func loadPhoto() {
        Task {
            if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        if let home = home {
                            // Existing home
                            home.data = data
                        } else {
                            // New home
                            tempUIImage = uiImage
                        }
                    }
                }
            }
        }
    }
}

//#Preview {
//    do {
//        let previewer = try Previewer()
//        
//        return EditHomeView(home: previewer.home)
//            .modelContainer(previewer.container)
//    } catch {
//        return Text("Failed to create preview: \(error.localizedDescription)")
//    }
//}
