//
//  DashboardView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import SwiftUI
import SwiftData
import PhotosUI

struct StatCard: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemGroupedBackground))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1))
    }
}

struct DashboardView: View {
    @Environment(\.modelContext) var modelContext
    @State private var sortOrder = [SortDescriptor(\InventoryLocation.name)]
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    @Query private var items: [InventoryItem]
    @Query private var homes: [Home]
    private var home: Home {
        if let existingHome = homes.first {
            return existingHome
        }
        let newHome = Home()
        modelContext.insert(newHome)
        return newHome
    }
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var router: Router
    
    @State private var showPhotoSourceAlert = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    
    private var totalReplacementCost: Decimal {
        items.reduce(0, { $0 + $1.price })
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    private let locationRow = GridItem(.fixed(160))

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Group {
                    if let uiImage = home.photo {
                        ZStack(alignment: .bottom) {
                            GeometryReader { geometry in
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(width: UIScreen.main.bounds.width, height: max(UIScreen.main.bounds.height / 3, geometry.frame(in: .global).minY + UIScreen.main.bounds.height / 3))
                                    .clipped()
                                    .offset(y: -geometry.frame(in: .global).minY)
                            }
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .overlay(alignment: .bottom) {
                                LinearGradient(
                                    gradient: Gradient(colors: [.black.opacity(0.6), .clear]),
                                    startPoint: .bottom,
                                    endPoint: .center
                                )
                                .frame(height: 100)
                            }
                            
                            HStack {
                                Text(home.name != "" ? home.name : "Dashboard")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Spacer()
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
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                        .ignoresSafeArea(edges: .horizontal)
                    } else {
                        VStack {
                            Spacer()
                                .frame(height: 100)
                            AddPhotoButton(action: {
                                showPhotoSourceAlert = true
                            })                                    .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                }
                            
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Inventory Statistics")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        StatCard(label: "Number of Items", value: "\(items.count)")
                        StatCard(label: "Total Value", value: CurrencyFormatter.format(totalReplacementCost))
                    }
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Location Statistics")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: [locationRow], spacing: 16) {
                            ForEach(locations) { location in
                                NavigationLink(value: Router.Destination.inventoryListView(location: location)) {
                                    LocationItemCard(location: location)
                                        .frame(width: 180)
                                }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                    }
                    .scrollTargetBehavior(.viewAligned)
                }
                .padding(.horizontal)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemGroupedBackground))
        .onChange(of: selectedPhoto) { oldValue, newValue in
            Task {
                if let photo = newValue {
                    await loadPhoto(from: photo)
                    selectedPhoto = nil
                }
            }
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
            Button("Take Photo") {
                showCamera = true
            }
            Button("Choose from Library") {
                showPhotoPicker = true
            }
            if home.photo != nil {
                Button("Remove Photo", role: .destructive) {
                    home.data = nil
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(
                showingImageAnalysis: .constant(false),
                analyzingImage: .constant(nil)
            ) { image, _, completion in
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    home.data = imageData
                }
                completion()
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
    }
    
    private func loadPhoto(from item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            await MainActor.run {
                home.data = data
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return DashboardView()
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
