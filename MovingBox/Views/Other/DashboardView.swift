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
    @State private var offset: CGFloat = 0
    @State private var headerContentHeight: CGFloat = 0
    @State private var loadingStartDate: Date? = nil
    
    private var home: Home? {
        return homes.last
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
        
        ZStack(alignment: .top) {
            Group {
                if isLoading {
                    ProgressView("Loading photo...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(uiImage: loadedImage ?? .craftsmanHome)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: UIScreen.main.bounds.width, height: headerHeight + max(0, -offset))
            .clipped()
            .transformEffect(.init(translationX: 0, y: -(max(0, offset))))
            .ignoresSafeArea(.all, edges: .top)
            
            ScrollView {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: headerHeight)
                        headerContentView
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            headerContentHeight = geo.size.height
                                        }
                                }
                            )
                            .offset(y: headerHeight - headerContentHeight)
                    }

                    // MARK: - Inventory Statistics
                    VStack(alignment: .leading, spacing: 16) {
                        Button {
                            router.navigate(to: .inventoryListView(location: nil))
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

                
            }
            .onScrollGeometryChange(for: CGFloat.self, of: { geo in
                return geo.contentOffset.y + geo.contentInsets.top
            }, action: { new, old in
                offset = new
            })
            .frame(maxWidth: .infinity)
        }
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
                loadingStartDate = Date()
            }
            
            defer {
                Task { @MainActor in
                    if let start = loadingStartDate {
                        let elapsed = Date().timeIntervalSince(start)
                        let minimumDuration: TimeInterval = 1.0
                        if elapsed < minimumDuration {
                            try? await Task.sleep(nanoseconds: UInt64((minimumDuration - elapsed) * 1_000_000_000))
                        }
                    }
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
    
    private var headerContentView: some View {
        VStack {
            Spacer()
            ZStack(alignment: .bottom) {
                LinearGradient(
                    gradient: Gradient(colors: [.black.opacity(0.6), .clear]),
                    startPoint: .bottom,
                    endPoint: .center
                )
                .frame(height: 100)

                VStack {
                    Spacer()
                    
                    // Home Text
                    HStack {
                        Text((home?.name.isEmpty == false ? home?.name : nil) ?? "Dashboard")                .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal)
                        
                        Spacer()
                        
                        // Photo picker
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
            }
        }
    }
}

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

#Preview {
    do {
        let previewer = try Previewer()
        return DashboardView()
            .modelContainer(previewer.container)
            .environmentObject(Router())
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}

