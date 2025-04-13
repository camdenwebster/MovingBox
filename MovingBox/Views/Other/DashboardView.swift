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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var router: Router
    
    @State private var loadedImage: UIImage?
    @State private var loadingError: Error?
    @State private var isLoading = false
    
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
                        .overlay(alignment: .bottomTrailing) {
                            PhotoPickerView(
                                model: Binding(
                                    get: { home ?? Home() },
                                    set: { if home == nil { modelContext.insert($0) }}
                                ),
                                loadedImage: $loadedImage,
                                isLoading: $isLoading
                            )
                        }
                        .ignoresSafeArea(edges: .horizontal)
                    } else if isLoading {
                        ProgressView()
                            .frame(height: 100)
                    } else {
                        VStack {
                            Spacer()
                                .frame(height: 100)
                            PhotoPickerView(
                                model: Binding(
                                    get: { home ?? Home() },
                                    set: { if home == nil { modelContext.insert($0) }}
                                ),
                                loadedImage: $loadedImage,
                                isLoading: $isLoading
                            ) { isPresented in
                                AddPhotoButton {
                                    isPresented.wrappedValue = true
                                }
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                }
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
                loadedImage = try await home.photo
            } catch {
                loadingError = error
                print("Failed to load image: \(error)")
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
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
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
