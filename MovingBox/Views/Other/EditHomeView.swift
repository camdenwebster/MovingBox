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
    @Query(sort: [SortDescriptor(\Home.purchaseDate)]) private var homes: [Home]
    @State private var homeNickName = ""
    @State private var homeAddress1 = ""
    @State private var homeAddress2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var isEditing = false
    @State private var showPhotoSourceAlert = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var tempUIImage: UIImage?
    @State private var country = Locale.current.region?.identifier ?? "US"
    private let countries = Locale.Region.isoRegions.map({ $0.identifier }).sorted()
    
    // Computed properties
    private var isNewHome: Bool {
        homes.isEmpty
    }
    
    private var isEditingEnabled: Bool {
        isNewHome || isEditing
    }
    
    private var activeHome: Home? {
        homes.first
    }
    
    private func countryName(for code: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forIdentifier: code) ?? code
    }
    
    var body: some View {
        Form {
            Section {
                if let uiImage = tempUIImage ?? activeHome?.photo {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: UIScreen.main.bounds.width - 32)
                        .frame(height: UIScreen.main.bounds.height / 3)
                        .clipped()
                        .listRowInsets(EdgeInsets())
                        .overlay(alignment: .bottomTrailing) {
                            if isEditingEnabled {
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
                } else {
                    if isEditingEnabled {
                        AddPhotoButton(action: {
                            showPhotoSourceAlert = true
                        })
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.height / 3)
                        .foregroundStyle(.secondary)
                        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
                            Button("Take Photo") {
                                showCamera = true
                            }
                            Button("Choose from Library") {
                                showPhotoPicker = true
                            }
                            if tempUIImage != nil || activeHome?.photo != nil {
                                Button("Remove Photo", role: .destructive) {
                                    if let home = activeHome {
                                        home.data = nil
                                    } else {
                                        tempUIImage = nil
                                    }
                                }
                            }
                        }
                        
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
                TextField("Street Address", text: $homeAddress1)
                    .textContentType(.streetAddressLine1)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                
                TextField("Apt, Suite, Unit", text: $homeAddress2)
                    .textContentType(.streetAddressLine2)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                
                TextField("City", text: $city)
                    .textContentType(.addressCity)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                
                TextField("State/Province", text: $state)
                    .textContentType(.addressState)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                
                TextField("ZIP/Postal Code", text: $zip)
                    .textContentType(.postalCode)
                    .keyboardType(.numberPad)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                
                if isEditingEnabled {
                    Picker("Country", selection: $country) {
                        ForEach(countries, id: \.self) { code in
                            Text(countryName(for: code))
                                .tag(code)
                        }
                    }
                } else {
                    HStack {
                        Text("Country")
                        Spacer()
                        Text(countryName(for: country))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(isNewHome ? "New Home" : "\(activeHome?.name ?? "") Details")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto, loadPhoto)
        .sheet(isPresented: $showCamera) {
            CameraView(
                showingImageAnalysis: .constant(false),
                analyzingImage: .constant(nil)
            ) { image, _, completion in
                if let home = activeHome {
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        home.data = imageData
                    }
                } else {
                    tempUIImage = image
                }
                completion()
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onAppear {
            if let existingHome = activeHome {
                // Initialize editing fields with existing values
                homeNickName = existingHome.name
                homeAddress1 = existingHome.address1
                homeAddress2 = existingHome.address2
                city = existingHome.city
                state = existingHome.state
                zip = existingHome.zip
                country = existingHome.country.isEmpty ? Locale.current.region?.identifier ?? "US" : existingHome.country
            }
        }
        .toolbar {
            if !isNewHome {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        if let home = activeHome {
                            home.name = homeNickName
                            home.address1 = homeAddress1
                            home.address2 = homeAddress2
                            home.city = city
                            home.state = state
                            home.zip = zip
                            home.country = country
                        }
                        isEditing = false
                    } else {
                        isEditing = true
                    }
                }
            } else {
                Button("Save") {
                    let newHome = Home(
                        name: homeNickName,
                        address1: homeAddress1,
                        address2: homeAddress2,
                        city: city,
                        state: state,
                        zip: zip,
                        country: country
                    )
                    
                    if let imageData = tempUIImage?.jpegData(compressionQuality: 0.8) {
                        newHome.data = imageData
                    }
                    
                    modelContext.insert(newHome)
                    TelemetryManager.shared.trackLocationCreated(name: newHome.address1)
                    print("EditHomeView: Created new home - \(newHome.name)")
                    router.navigateBack()
                }
                .disabled(homeAddress1.isEmpty)
            }
        }
    }
    
    private func loadPhoto() {
        Task {
            if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        if let home = activeHome {
                            home.data = data
                        } else {
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
//        return EditHomeView()
//            .modelContainer(previewer.container)
//    } catch {
//        return Text("Failed to create preview: \(error.localizedDescription)")
//    }
//}
