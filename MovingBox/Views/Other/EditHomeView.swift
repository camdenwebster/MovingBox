//
//  EditHomeView.swift
//  MovingBox
//
//  Created by Camden Webster on 3/20/25.
//

import Dependencies
import PhotosUI
import SQLiteData
import SwiftUI

@MainActor
struct EditHomeView: View {
    @Dependency(\.defaultDatabase) var database
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router

    @FetchAll(SQLiteHome.order(by: \.purchaseDate), animation: .default)
    private var homes: [SQLiteHome]

    var homeID: UUID?
    var presentedInSheet: Bool
    var onDismiss: (() -> Void)?

    @State private var isEditing = false
    @State private var loadedImage: UIImage?
    @State private var loadingError: Error?
    @State private var isLoading = false
    @State private var cachedImageURL: URL?
    @State private var isDataLoaded = false

    // Form state
    @State private var name: String = ""
    @State private var address1: String = ""
    @State private var address2: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zip: String = ""
    @State private var country: String = ""
    @State private var imageURL: URL?

    // PhotoPickerView adapter — Home() used only as PhotoManageable bridge
    @State private var photoAdapter = Home()

    init(
        homeID: UUID? = nil,
        presentedInSheet: Bool = false,
        onDismiss: (() -> Void)? = nil
    ) {
        self.homeID = homeID
        self.presentedInSheet = presentedInSheet
        self.onDismiss = onDismiss
    }

    private var activeHome: SQLiteHome? {
        if let homeID {
            return homes.first { $0.id == homeID }
        }
        return homes.last
    }

    private var isNewHome: Bool {
        if presentedInSheet {
            return homeID == nil
        }
        return homes.isEmpty
    }

    private var isEditingEnabled: Bool {
        isNewHome || isEditing
    }

    private func countryName(for code: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forRegionCode: code) ?? code
    }

    var body: some View {
        Form {
            if isEditingEnabled || loadedImage != nil {
                Section {
                    if let uiImage = loadedImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                            .overlay(alignment: .bottomTrailing) {
                                if isEditingEnabled {
                                    PhotoPickerView(
                                        model: photoAdapterBinding,
                                        loadedImage: $loadedImage,
                                        isLoading: $isLoading
                                    )
                                }
                            }
                    } else if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                    } else if isEditingEnabled {
                        PhotoPickerView(
                            model: photoAdapterBinding,
                            loadedImage: $loadedImage,
                            isLoading: $isLoading
                        ) { isPresented in
                            AddPhotoButton {
                                isPresented.wrappedValue = true
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if isEditingEnabled || !name.isEmpty {
                Section("Home Nickname") {
                    TextField("Enter a nickname", text: $name)
                        .disabled(!isEditingEnabled)
                        .foregroundStyle(isEditingEnabled ? .primary : .secondary)
                }
            }

            Section("Home Address") {
                TextField("Street Address", text: $address1)
                    .textContentType(.streetAddressLine1)
                    .disabled(!isEditingEnabled)
                    .foregroundStyle(isEditingEnabled ? .primary : .secondary)

                TextField("Apt, Suite, Unit", text: $address2)
                    .textContentType(.streetAddressLine2)
                    .disabled(!isEditingEnabled)
                    .foregroundStyle(isEditingEnabled ? .primary : .secondary)

                TextField("City", text: $city)
                    .textContentType(.addressCity)
                    .disabled(!isEditingEnabled)
                    .foregroundStyle(isEditingEnabled ? .primary : .secondary)

                TextField("State/Province", text: $state)
                    .textContentType(.addressState)
                    .disabled(!isEditingEnabled)
                    .foregroundStyle(isEditingEnabled ? .primary : .secondary)

                TextField("ZIP/Postal Code", text: $zip)
                    .textContentType(.postalCode)
                    .keyboardType(.numberPad)
                    .disabled(!isEditingEnabled)
                    .foregroundStyle(isEditingEnabled ? .primary : .secondary)

                if isEditingEnabled {
                    Picker("Country", selection: $country) {
                        if let userCountry = Locale.current.region?.identifier {
                            Text(countryName(for: userCountry))
                                .tag(userCountry)

                            Divider()
                        }

                        ForEach(
                            Locale.Region.isoRegions.filter { $0.identifier != Locale.current.region?.identifier }
                                .sorted(by: { countryName(for: $0.identifier) < countryName(for: $1.identifier) }),
                            id: \.identifier
                        ) { region in
                            Text(countryName(for: region.identifier))
                                .tag(region.identifier)
                        }
                    }
                } else {
                    HStack {
                        Text("Country")
                        Spacer()
                        Text(countryName(for: country))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(isNewHome ? "New Home" : (activeHome?.displayName ?? "Home"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: imageURL) {
            guard let url = imageURL, !isLoading else { return }

            if cachedImageURL != url {
                loadedImage = nil
                cachedImageURL = url
            }

            guard loadedImage == nil else { return }

            isLoading = true
            defer { isLoading = false }

            do {
                let thumbnail = try await OptimizedImageManager.shared.loadThumbnail(for: url)
                loadedImage = thumbnail
            } catch {
                do {
                    let photo = try await OptimizedImageManager.shared.loadImage(url: url)
                    loadedImage = photo
                } catch {
                    loadingError = error
                    print("Failed to load image: \(error)")
                }
            }
        }
        .onAppear {
            guard !isDataLoaded else { return }
            if let existingHome = activeHome {
                loadFromHome(existingHome)
            } else {
                country = Locale.current.region?.identifier ?? "US"
            }
            if presentedInSheet {
                isEditing = true
            }
            isDataLoaded = true
        }
        .toolbar {
            if presentedInSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if !isNewHome {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveExistingHome()
                            isEditing = false
                            if presentedInSheet {
                                dismissView()
                            }
                        } else {
                            isEditing = true
                        }
                    }
                    .font(isEditing ? .body.bold() : .body)
                } else {
                    Button("Save") {
                        Task {
                            await createNewHome()
                        }
                    }
                    .disabled(address1.isEmpty)
                    .bold()
                }
            }
        }
    }

    // MARK: - Photo Adapter

    private var photoAdapterBinding: Binding<Home> {
        Binding(
            get: {
                photoAdapter.imageURL = imageURL
                return photoAdapter
            },
            set: { newValue in
                imageURL = newValue.imageURL
            }
        )
    }

    // MARK: - Data Operations

    private func loadFromHome(_ home: SQLiteHome) {
        name = home.name
        address1 = home.address1
        address2 = home.address2
        city = home.city
        state = home.state
        zip = home.zip
        country = home.country
        imageURL = home.imageURL
    }

    private func saveExistingHome() {
        guard let home = activeHome else { return }

        let saveName = name
        let saveAddr1 = address1
        let saveAddr2 = address2
        let saveCity = city
        let saveState = state
        let saveZip = zip
        let saveCountry = country
        let saveImageURL = imageURL

        do {
            try database.write { db in
                try SQLiteHome.find(home.id).update {
                    $0.name = saveName
                    $0.address1 = saveAddr1
                    $0.address2 = saveAddr2
                    $0.city = saveCity
                    $0.state = saveState
                    $0.zip = saveZip
                    $0.country = saveCountry
                    $0.imageURL = saveImageURL
                }.execute(db)
            }
        } catch {
            print("Failed to save home: \(error)")
        }
    }

    private func createNewHome() async {
        let newHomeID = UUID()
        let saveName = name
        let saveAddr1 = address1
        let saveAddr2 = address2
        let saveCity = city
        let saveState = state
        let saveZip = zip
        let saveCountry = country
        let saveImageURL = imageURL
        let shouldBePrimary = homes.isEmpty

        do {
            try await database.write { db in
                try SQLiteHome.insert {
                    SQLiteHome(
                        id: newHomeID,
                        name: saveName,
                        address1: saveAddr1,
                        address2: saveAddr2,
                        city: saveCity,
                        state: saveState,
                        zip: saveZip,
                        country: saveCountry,
                        imageURL: saveImageURL,
                        isPrimary: shouldBePrimary,
                        colorName: "green"
                    )
                }.execute(db)

                // Create default locations
                for roomData in TestData.defaultRooms {
                    try SQLiteInventoryLocation.insert {
                        SQLiteInventoryLocation(
                            id: UUID(),
                            name: roomData.name,
                            desc: roomData.desc,
                            sfSymbolName: roomData.sfSymbol,
                            homeID: newHomeID
                        )
                    }.execute(db)
                }
            }

            TelemetryManager.shared.trackLocationCreated(name: saveAddr1)
            dismissView()
        } catch {
            print("Error saving home: \(error)")
        }
    }

    private func dismissView() {
        if presentedInSheet {
            onDismiss?()
            dismiss()
        } else {
            router.navigateBack()
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    NavigationStack {
        EditHomeView()
            .environmentObject(Router())
    }
}
