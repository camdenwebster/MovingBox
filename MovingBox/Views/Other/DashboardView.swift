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
                .accessibilityIdentifier("statCardLabel")
            Text(value)
                .font(.title2)
                .fontWeight(.medium)
                .accessibilityIdentifier("statCardValue")
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
    @Query(sort: \Home.purchaseDate) private var homes: [Home]
    @Query(sort: [SortDescriptor(\InventoryLocation.name)]) var locations: [InventoryLocation]
    @Query(sort: [SortDescriptor(\InventoryLabel.name)]) var labels: [InventoryLabel]
    @Query private var items: [InventoryItem]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var router: Router
    
    @State private var loadedImage: UIImage?
    @State private var loadingError: Error?
    @State private var isLoading = false
    
    private var home: Home? {
        homes.last
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
                        GeometryReader { proxy in
                            let scrollY = proxy.frame(in: .global).minY
                            let headerHeight = UIScreen.main.bounds.height / 3
                            
                            ZStack(alignment: .bottom) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: proxy.size.width, height: headerHeight + (scrollY > 0 ? scrollY : 0))
                                    .clipped()
                                    .offset(y: scrollY > 0 ? -scrollY : 0)
                                
                                LinearGradient(
                                    gradient: Gradient(colors: [.black.opacity(0.6), .clear]),
                                    startPoint: .bottom,
                                    endPoint: .center
                                )
                                .frame(height: 100)
                                
                                VStack {
                                    Spacer()
                                    dashboardHeader
                                }
                                .frame(maxWidth: .infinity)
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
                        }
                        .frame(height: UIScreen.main.bounds.height / 3)
                    } else if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
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
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.height / 3)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Label Statistics")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: [locationRow], spacing: 16) {
                            ForEach(labels) { label in
                                LocationItemCard(label: label)
                                    .frame(width: 180)
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
            .frame(maxWidth: .infinity)
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
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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
