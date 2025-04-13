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

@MainActor
struct DashboardView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: [SortDescriptor(\Home.purchaseDate)]) private var homes: [Home]
    @Query(sort: [SortDescriptor(\InventoryLocation.name)]) var locations: [InventoryLocation]
    @Query private var items: [InventoryItem]
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var router: Router
    
    @State private var showPhotoSourceAlert = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    
    @State private var loadedImage: UIImage?
    @State private var loadingError: Error?
    @State private var isLoading = false
    @State private var isShowingRemovePhotoButton = false
    
    private var home: Home? {
        homes.first
    }
    
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
                    if let uiImage = loadedImage {
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
                            
                            dashboardHeader
                        }
                        .ignoresSafeArea(edges: .horizontal)
                    } else if isLoading {
                        ProgressView()
                            .frame(height: 100)
                    } else {
                        VStack {
                            Spacer()
                                .frame(height: 100)
                            AddPhotoButton(action: {
                                showPhotoSourceAlert = true
                            })
                            .padding()
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
        .task(id: home?.imageURL) {
            guard let home = home else { return }
            isLoading = true
            defer { isLoading = false }
            
            do {
                if let imageURL = home.imageURL {
                    loadedImage = try await OptimizedImageManager.shared.loadImage(url: imageURL)
                    isShowingRemovePhotoButton = true
                } else {
                    loadedImage = nil
                    isShowingRemovePhotoButton = false
                }
            } catch {
                loadingError = error
                print("Failed to load image: \(error)")
            }
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
            Button("Take Photo") {
                showCamera = true
            }
            Button("Choose from Library") {
                showPhotoPicker = true
            }
            if isShowingRemovePhotoButton {
                Button("Remove Photo", role: .destructive) {
                    home?.imageURL = nil
                    loadedImage = nil
                    isShowingRemovePhotoButton = false
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .sheet(isPresented: $showCamera) {
            CameraView(
                showingImageAnalysis: .constant(false),
                analyzingImage: .constant(nil)
            ) { image, _, completion async -> Void in
                await handleNewImage(image)
                await completion()
            }
        }
        .onChange(of: selectedPhoto) { oldValue, newValue in
            Task {
                if let photo = newValue {
                    await loadPhoto(from: photo)
                    selectedPhoto = nil
                }
            }
        }
    }
    
    private var dashboardHeader: some View {
        HStack {
            Text(home?.name != "" ? home?.name ?? "Dashboard" : "Dashboard")
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
    
    private func handleNewImage(_ image: UIImage) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let id = UUID().uuidString
            let imageURL = try await OptimizedImageManager.shared.saveImage(image, id: id)
            if home == nil {
                let newHome = Home()
                modelContext.insert(newHome)
                newHome.imageURL = imageURL
            } else {
                home?.imageURL = imageURL
            }
            loadedImage = image
            isShowingRemovePhotoButton = true
            try? modelContext.save()
        } catch {
            loadingError = error
            print("Failed to save image: \(error)")
        }
    }
    
    private func loadPhoto(from item: PhotosPickerItem) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await handleNewImage(uiImage)
            }
        } catch {
            loadingError = error
            print("Failed to load photo: \(error)")
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
