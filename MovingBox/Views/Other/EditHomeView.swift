//
//  EditHomeView.swift
//  MovingBox
//
//  Created by Camden Webster on 3/20/25.
//

import SwiftData
import SwiftUI
import PhotosUI

private struct CurrencyField: View {
    let title: String
    @Binding var value: Decimal
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isEnabled {
                TextField("Amount", value: $value, format: .currency(code: "USD"))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            } else {
                Text(value, format: .currency(code: "USD"))
                    .foregroundColor(.secondary)
            }
        }
    }
}

@MainActor
struct EditHomeView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @Query(sort: [SortDescriptor(\Home.purchaseDate)]) private var homes: [Home]
    @State private var isEditing = false
    @State private var showPhotoSourceAlert = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var tempUIImage: UIImage?
    @State private var loadedImage: UIImage?
    @State private var loadingError: Error?
    @State private var isLoading = false
    
    // Consolidate home-related properties into a temporary home
    @State private var tempHome = Home()
    // Consolidate insurance-related properties
    @State private var tempPolicy = InsurancePolicy()
    
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
                if let uiImage = tempUIImage ?? loadedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: UIScreen.main.bounds.width - 32)
                        .frame(height: UIScreen.main.bounds.height / 3)
                        .clipped()
                        .listRowInsets(EdgeInsets())
                        .overlay(alignment: .bottomTrailing) {
                            if isEditingEnabled {
                                photoButton
                            }
                        }
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.height / 3)
                } else {
                    if isEditingEnabled {
                        AddPhotoButton(action: {
                            showPhotoSourceAlert = true
                        })
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.height / 3)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            
            if isEditingEnabled || !tempHome.name.isEmpty {
                Section("Home Nickname") {
                    TextField("Enter a nickname", text: $tempHome.name)
                        .disabled(!isEditingEnabled)
                        .foregroundColor(isEditingEnabled ? .primary : .secondary)
                }
            }
            
            Section("Home Address") {
                TextField("Street Address", text: $tempHome.address1)
                    .textContentType(.streetAddressLine1)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                
                TextField("Apt, Suite, Unit", text: $tempHome.address2)
                    .textContentType(.streetAddressLine2)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                
                TextField("City", text: $tempHome.city)
                    .textContentType(.addressCity)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                
                TextField("State/Province", text: $tempHome.state)
                    .textContentType(.addressState)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                
                TextField("ZIP/Postal Code", text: $tempHome.zip)
                    .textContentType(.postalCode)
                    .keyboardType(.numberPad)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
                
                if isEditingEnabled {
                    Picker("Country", selection: $tempHome.country) {
                        ForEach(Locale.Region.isoRegions.map({ $0.identifier }).sorted(), id: \.self) { code in
                            Text(countryName(for: code))
                                .tag(code)
                        }
                    }
                } else {
                    HStack {
                        Text("Country")
                        Spacer()
                        Text(countryName(for: tempHome.country))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Insurance Policy") {
                FormTextFieldRow(label: "Insurance Provider", text: $tempPolicy.providerName, isEditing: $isEditing, placeholder: "Name")
                FormTextFieldRow(label: "Policy Number", text: $tempPolicy.policyNumber, isEditing: $isEditing, placeholder: "Number")
                
                if isEditingEnabled {
                    DatePicker("Start Date", selection: $tempPolicy.startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $tempPolicy.endDate, in: tempPolicy.startDate..., displayedComponents: .date)
                } else {
                    HStack {
                        Text("Start Date")
                        Spacer()
                        Text(tempPolicy.startDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("End Date")
                        Spacer()
                        Text(tempPolicy.endDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Coverage Details") {
                CurrencyField(
                    title: "Deductible",
                    value: $tempPolicy.deductibleAmount,
                    isEnabled: isEditingEnabled
                )
                
                CurrencyField(
                    title: "Dwelling Coverage",
                    value: $tempPolicy.dwellingCoverageAmount,
                    isEnabled: isEditingEnabled
                )
                
                CurrencyField(
                    title: "Personal Property",
                    value: $tempPolicy.personalPropertyCoverageAmount,
                    isEnabled: isEditingEnabled
                )
                
                CurrencyField(
                    title: "Loss of Use",
                    value: $tempPolicy.lossOfUseCoverageAmount,
                    isEnabled: isEditingEnabled
                )
                
                CurrencyField(
                    title: "Liability",
                    value: $tempPolicy.liabilityCoverageAmount,
                    isEnabled: isEditingEnabled
                )
                
                CurrencyField(
                    title: "Medical Payments",
                    value: $tempPolicy.medicalPaymentsCoverageAmount,
                    isEnabled: isEditingEnabled
                )
            }
        }
        .task(id: activeHome?.imageURL) {
            guard let home = activeHome else { return }
            isLoading = true
            defer { isLoading = false }
            
            do {
                loadedImage = try await home.photo
            } catch {
                loadingError = error
                print("Failed to load image: \(error)")
            }
        }
        .navigationTitle(isNewHome ? "New Home" : "\(activeHome?.name ?? "") Details")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto, loadPhoto)
        .sheet(isPresented: $showCamera) {
            CameraView(
                showingImageAnalysis: .constant(false),
                analyzingImage: .constant(nil)
            ) { image, _, completion async -> Void in
                let id = UUID().uuidString
                if let imageURL = try? await OptimizedImageManager.shared.saveImage(image, id: id) {
                    if let home = activeHome {
                        home.imageURL = imageURL
                        try? modelContext.save()
                    } else {
                        tempUIImage = image
                    }
                }
                await completion()
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
            Button("Take Photo") {
                showCamera = true
            }
            Button("Choose from Library") {
                showPhotoPicker = true
            }
            if tempUIImage != nil || loadedImage != nil {
                Button("Remove Photo", role: .destructive) {
                    if let home = activeHome {
                        home.imageURL = nil
                        loadedImage = nil
                    } else {
                        tempUIImage = nil
                    }
                }
            }
        }
        .onAppear {
            if let existingHome = activeHome {
                // Initialize editing fields with existing values
                tempHome = existingHome
                if let policy = existingHome.insurancePolicy {
                    tempPolicy = policy
                }
            } else {
                // Set default country for new home
                tempHome.country = Locale.current.region?.identifier ?? "US"
            }
        }
        .toolbar {
            if !isNewHome {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        if let home = activeHome {
                            // Copy all properties from tempHome to the actual home
                            home.name = tempHome.name
                            home.address1 = tempHome.address1
                            home.address2 = tempHome.address2
                            home.city = tempHome.city
                            home.state = tempHome.state
                            home.zip = tempHome.zip
                            home.country = tempHome.country
                            
                            // Update or create insurance policy
                            if home.insurancePolicy == nil {
                                tempPolicy.insuredHome = home
                                home.insurancePolicy = tempPolicy
                            }
                        }
                        isEditing = false
                    } else {
                        isEditing = true
                    }
                }
            } else {
                Button("Save") {
                    Task {
                        // Copy properties from tempHome
                        tempHome.purchaseDate = Date()
                        
                        if let uiImage = tempUIImage {
                            let id = UUID().uuidString
                            if let imageURL = try? await OptimizedImageManager.shared.saveImage(uiImage, id: id) {
                                tempHome.imageURL = imageURL
                            }
                        }
                        
                        // Create insurance policy if provider name or policy number is filled
                        if !tempPolicy.providerName.isEmpty || !tempPolicy.policyNumber.isEmpty {
                            tempPolicy.insuredHome = tempHome
                            tempHome.insurancePolicy = tempPolicy
                        }
                        
                        modelContext.insert(tempHome)
                        TelemetryManager.shared.trackLocationCreated(name: tempHome.address1)
                        print("EditHomeView: Created new home - \(tempHome.name)")
                        router.navigateBack()
                    }
                }
                .disabled(tempHome.address1.isEmpty)
            }
        }
    }
    
    private var photoButton: some View {
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
        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
            Button("Take Photo") {
                showCamera = true
            }
            Button("Choose from Library") {
                showPhotoPicker = true
            }
            if tempUIImage != nil || loadedImage != nil {
                Button("Remove Photo", role: .destructive) {
                    if let home = activeHome {
                        home.imageURL = nil
                        loadedImage = nil
                    } else {
                        tempUIImage = nil
                    }
                }
            }
        }
    }
    
    private func loadPhoto() {
        Task {
            if let data = try? await selectedPhoto?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                isLoading = true
                defer { isLoading = false }
                
                let id = UUID().uuidString
                if let imageURL = try? await OptimizedImageManager.shared.saveImage(uiImage, id: id) {
                    if let home = activeHome {
                        home.imageURL = imageURL
                    } else {
                        tempUIImage = uiImage
                    }
                    try? modelContext.save()
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
