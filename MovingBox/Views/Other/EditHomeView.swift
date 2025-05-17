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
    @Query(sort: [SortDescriptor(\InsurancePolicy.startDate)]) private var policies: [InsurancePolicy]
    @State private var isEditing = false
    @State private var loadedImages: [UIImage] = []
    @State private var loadingError: Error?
    @State private var isLoading = false
    
    @State private var tempHome = Home()
    @State private var tempPolicy = InsurancePolicy()
    
    private var isNewHome: Bool {
        homes.isEmpty
    }
    
    private var isEditingEnabled: Bool {
        isNewHome || isEditing
    }
    
    private var activeHome: Home? {
        homes.last
    }
    
    private func countryName(for code: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forIdentifier: code) ?? code
    }
    
    func saveHome() async throws {
        if isNewHome {
            let home = try await DefaultDataManager.getOrCreateHome(modelContext: modelContext)
            
            home.name = tempHome.name
            home.address1 = tempHome.address1
            home.address2 = tempHome.address2
            home.city = tempHome.city
            home.state = tempHome.state
            home.zip = tempHome.zip
            home.country = tempHome.country
            home.purchaseDate = Date()
            home.imageURLs = tempHome.imageURLs
            
            if !tempPolicy.providerName.isEmpty || !tempPolicy.policyNumber.isEmpty {
                modelContext.insert(tempPolicy)
            }
            
            TelemetryManager.shared.trackLocationCreated(name: home.address1)
            print("EditHomeView: Updated home - \(home.name)")
        }
        
        try modelContext.save()
        router.navigateBack()
    }
    
    private func findPolicy(for home: Home) -> InsurancePolicy? {
        // Just return the first policy - since we only have one home and one policy
        return policies.first
    }
    
    var body: some View {
        Form {
            Section {
                if !loadedImages.isEmpty {
                    if isEditingEnabled {
                        PhotoGridEditorView<Home>(
                            model: Binding(
                                get: { activeHome ?? tempHome },
                                set: { tempHome = $0 }
                            ),
                            loadedImages: $loadedImages,
                            isLoading: $isLoading
                        )
                        .listRowInsets(EdgeInsets())
                    } else {
                        PhotoCarouselView(
                            images: loadedImages,
                            currentIndex: Binding(
                                get: { activeHome?.primaryImageIndex ?? tempHome.primaryImageIndex },
                                set: { newIndex in 
                                    if let home = activeHome {
                                        home.primaryImageIndex = newIndex
                                    } else {
                                        tempHome.primaryImageIndex = newIndex
                                    }
                                }
                            )
                        )
                        .frame(height: UIScreen.main.bounds.height / 3)
                        .listRowInsets(EdgeInsets())
                    }
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.height / 3)
                } else if isEditingEnabled {
                    PhotoPickerView(
                        model: Binding(
                            get: { activeHome ?? tempHome },
                            set: { tempHome = $0 }
                        ),
                        loadedImages: $loadedImages,
                        isLoading: $isLoading
                    ) { showPhotoSourceAlert in
                        AddPhotoButton {
                            showPhotoSourceAlert.wrappedValue = true
                        }
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
        .task(id: activeHome?.imageURLs) {
            guard let home = activeHome else { return }
            isLoading = true
            defer { isLoading = false }
            
            loadedImages = []
            for url in home.imageURLs {
                do {
                    if let image = try await OptimizedImageManager.shared.loadImage(url: url) {
                        loadedImages.append(image)
                    }
                } catch {
                    loadingError = error
                    print("Failed to load image: \(error)")
                }
                
                // For backward compatibility
                if loadedImages.isEmpty, let photo = try? await home.photo {
                    loadedImages = [photo]
                }
            }
        }
        .onAppear {
            if let existingHome = activeHome {
                tempHome = existingHome
                if let policy = findPolicy(for: existingHome) {
                    tempPolicy = policy
                }
            } else {
                tempHome.country = Locale.current.region?.identifier ?? "US"
            }
        }
        .toolbar {
            if !isNewHome {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        if let home = activeHome {
                            home.name = tempHome.name
                            home.address1 = tempHome.address1
                            home.address2 = tempHome.address2
                            home.city = tempHome.city
                            home.state = tempHome.state
                            home.zip = tempHome.zip
                            home.country = tempHome.country
                            
                            if !tempPolicy.providerName.isEmpty || !tempPolicy.policyNumber.isEmpty {
                                modelContext.insert(tempPolicy)
                                try? modelContext.save()
                            }
                            isEditing = false
                        }
                    } else {
                        isEditing = true
                    }
                }
                .font(isEditing ? .body.bold() : .body)
            } else {
                Button("Save") {
                    Task {
                        do {
                            try await saveHome()
                        } catch {
                            print("❌ Error saving home: \(error)")
                        }
                    }
                }
                .disabled(tempHome.address1.isEmpty)
                .bold()
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
