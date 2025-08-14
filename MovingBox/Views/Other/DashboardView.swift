//
//  DashboardView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import SwiftUIBackports
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
    @Query private var items: [InventoryItem]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var router: Router
    
    @State private var loadedImage: UIImage?
    @State private var loadingError: Error?
    @State private var isLoading = false
    @State private var homeInstance = Home()
    @State private var cachedImageURL: URL?
    
    private var home: Home? {
        homes.last
    }
    
    private var totalReplacementCost: Decimal {
        items.reduce(0, { $0 + ($1.price * Decimal($1.quantityInt)) })
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible())
    ]
    
    let headerHeight = UIScreen.main.bounds.height / 3

    var body: some View {
        ScrollView {
            // MARK: - Sticky Header
            VStack(spacing: 0) {
                Group {
                    if let uiImage = loadedImage {
                        GeometryReader { proxy in
                            let scrollY = proxy.frame(in: .global).minY
                            
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
                                // MARK: - Photo picker
                                if !isLoading {
                                    PhotoPickerView(
                                        model: Binding(
                                            get: { home ?? homeInstance },
                                            set: { newValue in
                                                if let existingHome = home {
                                                    existingHome.imageURL = newValue.imageURL
                                                    try? modelContext.save()
                                                } else {
                                                    homeInstance = newValue
                                                    modelContext.insert(homeInstance)
                                                    try? modelContext.save()
                                                }
                                            }
                                        ),
                                        loadedImage: $loadedImage,
                                        isLoading: $isLoading
                                    )
                                }
                            }
                        }
                        .frame(height: UIScreen.main.bounds.height / 3)
                    } else if isLoading {
                        VStack {
                            ProgressView("Loading photo...")
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: headerHeight)
                        .background(Color(.systemGroupedBackground))
                    } else {
                        VStack {
                            Spacer()
                                .frame(height: 100)
                            PhotoPickerView(
                                model: Binding(
                                    get: { home ?? homeInstance },
                                    set: { newValue in
                                        if let existingHome = home {
                                            existingHome.imageURL = newValue.imageURL
                                            try? modelContext.save()
                                        } else {
                                            homeInstance = newValue
                                            modelContext.insert(homeInstance)
                                            try? modelContext.save()
                                        }
                                    }
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
                
                // MARK: - Inventory Statistics
                VStack(alignment: .leading, spacing: 16) {
                    Button {
                        router.selectedTab = .allItems
                    } label: {
                        DashboardSectionLabel(text: "Inventory")
                    }
                    .buttonStyle(.plain)
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        StatCard(label: "Number of Items", value: "\(items.count)")
                        StatCard(label: "Total Value", value: CurrencyFormatter.format(totalReplacementCost))
                        StatCard(label: "Total Value", value: CurrencyFormatter.format(totalReplacementCost))

                    }
                    .padding(.horizontal)
                }
                .padding(.top, 24)
                
                // MARK: - Location Statistics
                LocationStatisticsView()
                    .padding(.top, 24)
                
                // MARK: - Label Statistics
                LabelStatisticsView()
                    .padding(.top, 24)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .backport.scrollEdgeEffectStyle(.soft, for: .all)
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemGroupedBackground))
        .task(id: home?.imageURL) {
            guard let home = home, 
                  let imageURL = home.imageURL, 
                  !isLoading else { return }
            
            // If the imageURL changed, clear the cached image
            if cachedImageURL != imageURL {
                await MainActor.run {
                    loadedImage = nil
                    cachedImageURL = imageURL
                }
            }
            
            // Only load if we don't have a cached image for this URL
            guard loadedImage == nil else { return }
            
            await MainActor.run {
                isLoading = true
            }
            
            defer {
                Task { @MainActor in
                    isLoading = false
                }
            }
            
            do {
                let photo = try await home.photo
                await MainActor.run {
                    loadedImage = photo
                }
            } catch {
                await MainActor.run {
                    loadingError = error
                    print("Failed to load image: \(error)")
                }
            }
        }
    }
    
    private var dashboardHeader: some View {
        HStack {
            Text((home?.name.isEmpty == false ? home?.name : nil) ?? "Dashboard")                .font(.largeTitle)
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

