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
    @State private var sortOrder = [SortDescriptor(\InventoryLocation.name)]
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    @Query private var items: [InventoryItem]
    @Query private var homes: [Home]
    private var home: Home { homes.first ?? Home() }
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var router: Router
    
    // ADD: New state properties after existing @State properties
    @State private var showPhotoSourceAlert = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    
    private var totalReplacementCost: Decimal {
        items.reduce(0, { $0 + $1.price })
    }

    // Keep columns for stats cards only
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
                            Rectangle()
                                .fill(Color.clear)
                                .overlay(
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                )
                                .clipped()
                                .frame(maxWidth: .infinity)
                                .frame(height: UIScreen.main.bounds.height / 3)
                                .ignoresSafeArea(edges: .top)
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
                    } else {
                        // CHANGE: Replace PhotosPicker with Button
                        Button {
                            showPhotoSourceAlert = true
                        } label: {
                            VStack {
                                Image(systemName: "photo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 150, maxHeight: 150)
                                    .foregroundStyle(.secondary)
                                Text("Add a photo of your home")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .foregroundStyle(.secondary)
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
                                        .frame(width: 160)
                                        .background(RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal)
                    }
                    .scrollTargetBehavior(.viewAligned)
                }
                .padding(.horizontal)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemGroupedBackground))
        .onChange(of: selectedPhoto, loadPhoto)
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
            CameraView { image, needsAIAnalysis, completion in
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    home.data = imageData
                }
                completion()
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
    }
    
    private func loadPhoto() {
        Task {
            await PhotoManager.loadAndSavePhoto(from: selectedPhoto, to: home)
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
