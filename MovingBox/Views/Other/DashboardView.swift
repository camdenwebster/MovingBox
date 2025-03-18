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
            .fill(Color(.systemBackground))
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Group {
                        if let uiImage = home.photo {
                            ZStack(alignment: .bottomTrailing) {
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
                                
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    Image(systemName: "photo.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .font(.largeTitle)
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(.black.opacity(0.5)))
                                }
                                .padding(.bottom, 16)
                                .padding(.trailing, 16)
                            }
                        } else {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
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
                        Text("Home Statistics")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            StatCard(label: "Number of items", value: "\(items.count)")
                            StatCard(label: "Number of locations", value: "\(locations.count)")
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Inventory Statistics")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        StatCard(label: "Total replacement cost", value: "$0.00")
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Items per Location")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(locations) { location in
                                    LocationItemCard(location: location)
                                        .frame(width: UIScreen.main.bounds.width / 2 - 16)
                                        .background(RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemBackground))
                                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("\(home.address1 != "" ? home.address1 : "Dashboard")")
            .background(Color(.systemGroupedBackground))
        }
        .onChange(of: selectedPhoto, loadPhoto)
    }
    
    private func loadPhoto() {
        Task { @MainActor in
            home.data = try await selectedPhoto?.loadTransferable(type: Data.self)
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
