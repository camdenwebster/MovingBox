//
//  DashboardView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import SwiftUI
import SwiftData
import PhotosUI

struct DashboardView: View {
    @State private var sortOrder = [SortDescriptor(\InventoryLocation.name)]
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    @Query private var homes: [Home]
    private var home: Home { homes.first ?? Home() }

    @State private var selectedPhoto: PhotosPickerItem? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 0) {
                        if let uiImage = home.photo {
                            ZStack(alignment: .bottomTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: UIScreen.main.bounds.height / 3)
                                    .clipped()
                                
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    Image(systemName: "photo.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .font(.largeTitle)
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(.black.opacity(0.5)))
                                        .padding()
                                }
                            }
                            .listRowInsets(EdgeInsets())
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
                    .listRowInsets(EdgeInsets())
                }
                Section("Home Statistics") {
                    HStack {
                        Text("Number of items: ")
                        Spacer()
                        Text("0")
                    }
                    HStack {
                        Text("Number of locations:")
                        Spacer()
                        Text("0")
                    }
                }
                Section("Inventory Statistics") {
                    HStack {
                        Text("Total replacement cost")
                        Spacer()
                        Text("$0.00")
                    }
                }
                Section("Items per Location") {
                    ForEach(locations) { location in
                        LocationItemRow(location: location)
                    }
                }
            }
            .navigationTitle("Dashboard")
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
