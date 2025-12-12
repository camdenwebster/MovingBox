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
import RevenueCatUI

@MainActor
struct DashboardView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Home.purchaseDate) private var homes: [Home]
    @Query private var items: [InventoryItem]
    @Query(sort: [SortDescriptor(\InventoryItem.createdAt, order: .reverse)]) private var recentItems: [InventoryItem]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared
    
    @State private var loadedImage: UIImage?
    @State private var loadingError: Error?
    @State private var isLoading = false
    @State private var homeInstance = Home()
    @State private var cachedImageURL: URL?
    @State private var offset: CGFloat = 0
    @State private var headerContentHeight: CGFloat = 0
    @State private var loadingStartDate: Date? = nil
    @State private var showingPaywall = false
    @State private var showItemCreationFlow = false
    @State private var selectedPrototype: CameraPrototype? = nil

    enum CameraPrototype: String, Identifiable {
        case minimalist
        case iOSNative
        case cardBased

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .minimalist: return "Minimalist Pro"
            case .iOSNative: return "iOS Native"
            case .cardBased: return "Card-Based"
            }
        }

        var iconName: String {
            switch self {
            case .minimalist: return "camera.macro"
            case .iOSNative: return "camera"
            case .cardBased: return "camera.filters"
            }
        }

        var description: String {
            switch self {
            case .minimalist: return "Clean & minimal"
            case .iOSNative: return "Familiar iOS design"
            case .cardBased: return "Modern cards"
            }
        }
    }

    private var home: Home? {
        return homes.last
    }
    
    private var totalReplacementCost: Decimal {
        items.reduce(0, { $0 + ($1.price * Decimal($1.quantityInt)) })
    }
    
    private var topRecentItems: [InventoryItem] {
        Array(recentItems.prefix(3))
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
                            DashboardSectionLabel(text: "All Inventory")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("dashboard-all-inventory-button")
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            StatCard(label: "Number of Items", value: "\(items.count)")
                            StatCard(label: "Total Value", value: CurrencyFormatter.format(totalReplacementCost))
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 24)
                    
                    // MARK: - Recently Added Items
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recently Added")
                            .sectionHeaderStyle()
                            .padding(.horizontal)
                        
                        if topRecentItems.isEmpty {
                            ContentUnavailableView {
                                Label("No Items Yet", systemImage: "tray")
                            } description: {
                                Text("Add your first item to see it here")
                            } actions: {
                                Button("Add Item") {
                                    createFromPhoto()
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("dashboard-empty-state-add-item-button")
                            }
                            .frame(height: 120)
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(topRecentItems, id: \.persistentModelID) { item in
                                    Button {
                                        router.navigate(to: .inventoryDetailView(item: item, showSparklesButton: true))
                                    } label: {
                                        HStack {
                                            InventoryItemRow(item: item)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.tertiary)
                                                .font(.footnote)
                                                .fontWeight(.medium)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("dashboard-recent-item-\(item.persistentModelID)")
                                    
                                    if item.persistentModelID != topRecentItems.last?.persistentModelID {
                                        Divider()
                                            .padding(.leading, 92)
                                    }
                                }
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                Button {
                                    router.navigate(to: .inventoryListView(location: nil))
                                } label: {
                                    HStack {
                                        Text("View All Items")
                                            
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                            .font(.footnote)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("dashboard-view-all-items-button")
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: UIConstants.cornerRadius))
                            .padding(.horizontal)
                            
                        }
                    }
                    .padding(.top, 24)
                    .scrollDisabled(true)

                    // MARK: - Camera Prototypes (iOS 26 Design System)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Camera Prototypes")
                            .sectionHeaderStyle()
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            Button(action: { selectedPrototype = .minimalist }) {
                                VStack(spacing: 8) {
                                    Image(systemName: CameraPrototype.minimalist.iconName)
                                        .font(.system(size: 24))
                                    Text(CameraPrototype.minimalist.displayName)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(CameraPrototype.minimalist.description)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 90)
                                .foregroundColor(.white)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
                            }

                            Button(action: { selectedPrototype = .iOSNative }) {
                                VStack(spacing: 8) {
                                    Image(systemName: CameraPrototype.iOSNative.iconName)
                                        .font(.system(size: 24))
                                    Text(CameraPrototype.iOSNative.displayName)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(CameraPrototype.iOSNative.description)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 90)
                                .foregroundColor(.white)
                                .background(
                                    LinearGradient(
                                        colors: [Color.purple, Color.purple.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: .purple.opacity(0.3), radius: 4, y: 2)
                            }

                            Button(action: { selectedPrototype = .cardBased }) {
                                VStack(spacing: 8) {
                                    Image(systemName: CameraPrototype.cardBased.iconName)
                                        .font(.system(size: 24))
                                    Text(CameraPrototype.cardBased.displayName)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(CameraPrototype.cardBased.description)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 90)
                                .foregroundColor(.white)
                                .background(
                                    LinearGradient(
                                        colors: [Color.orange, Color.orange.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: .orange.opacity(0.3), radius: 4, y: 2)
                            }
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
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    router.navigate(to: .settingsView)
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("dashboard-settings-button")
            }
            // Search field and spacers
            if #available(iOS 26.0, *) {
                ToolbarSpacer(placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(placement: .bottomBar)
            } else {
                // For iOS < 26, add spacer to push + button to trailing edge
                ToolbarItem(placement: .bottomBar) {
                    Spacer()
                }
            }
            // Add new item button
            ToolbarItem(placement: .bottomBar) {
                Button(action: createFromPhoto) {
                    Label("Add from Photo", systemImage: "plus")
                }
                .accessibilityIdentifier("createFromCamera")
                .buttonStyle(.borderedProminent)
                
                .backport.glassEffect(in: Circle())
            }
        }
        .sheet(isPresented: $showingPaywall, content: paywallSheet)
        .sheet(isPresented: $showItemCreationFlow) {
            // Present camera directly with default single-item mode
            // User can switch modes via segmented control in camera
            EnhancedItemCreationFlowView(
                captureMode: .singleItem,
                location: nil
            ) {
                // Optional callback when item creation is complete
                dismiss()
            }
        }
        .sheet(item: $selectedPrototype) { prototype in
            prototypeView(for: prototype)
        }
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
    
    private func createFromPhoto() {
        let aiItemsCount = items.filter({ $0.hasUsedAI }).count
        print("📱 DashboardView.createFromPhoto - Total items: \(items.count), AI items: \(aiItemsCount), isPro: \(settings.isPro)")
        
        if settings.shouldShowPaywallForAiScan(currentCount: aiItemsCount) {
            print("📱 DashboardView.createFromPhoto - Should show paywall, setting showingPaywall = true")
            showingPaywall = true
        } else {
            print("📱 DashboardView.createFromPhoto - Should show creation flow, setting showItemCreationFlow = true")
            showItemCreationFlow = true
        }
    }
    
    @ViewBuilder
    private func paywallSheet() -> some View {
        revenueCatManager.presentPaywall(
            isPresented: $showingPaywall,
            onCompletion: {
                settings.isPro = true
                showItemCreationFlow = true
            },
            onDismiss: nil
        )
    }

    @ViewBuilder
    private func prototypeView(for prototype: CameraPrototype) -> some View {
        switch prototype {
        case .minimalist:
            CameraPrototype1_Minimalist()
        case .iOSNative:
            CameraPrototype2_iOSNative()
        case .cardBased:
            CameraPrototype3_CardBased()
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
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("statCardLabel")
            Text(value)
                .font(.title2)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("statCardValue")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
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
