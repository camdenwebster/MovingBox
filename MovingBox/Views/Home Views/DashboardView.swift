//
//  DashboardView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import PhotosUI
import RevenueCatUI
import SwiftData
import SwiftUI
import SwiftUIBackports
import WhatsNewKit

@MainActor
struct DashboardView: View {
    let specificHome: Home?

    @Environment(\.modelContext) var modelContext
    @Query(sort: \Home.purchaseDate) private var homes: [Home]
    @Query private var allItems: [InventoryItem]
    @Query(sort: [SortDescriptor(\InventoryItem.createdAt, order: .reverse)]) private var allRecentItems:
        [InventoryItem]
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
    @State private var loadingStartDate: Date? = nil
    @State private var showingPaywall = false
    @State private var showItemCreationFlow = false

    // MARK: - Initializer

    init(home: Home? = nil) {
        self.specificHome = home
    }

    // MARK: - Computed Properties

    private var displayHome: Home? {
        specificHome ?? homes.first { $0.isPrimary } ?? homes.last
    }

    private var home: Home? {
        return displayHome
    }

    private var items: [InventoryItem] {
        guard let displayHome = displayHome else {
            return allItems
        }
        return allItems.filter { $0.effectiveHome?.id == displayHome.id }
    }

    private var recentItems: [InventoryItem] {
        guard let displayHome = displayHome else {
            return allRecentItems
        }
        return allRecentItems.filter { $0.effectiveHome?.id == displayHome.id }
    }

    private var totalReplacementCost: Decimal {
        items.reduce(0, { $0 + ($1.price * Decimal($1.quantityInt)) })
    }

    private var topRecentItems: [InventoryItem] {
        Array(recentItems.prefix(3))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible()),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
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
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .modifier(BackgroundExtensionModifier())
                    .overlay(alignment: .bottom) {
                        headerContentView
                    }
                }
                .flexibleHeaderContent()

                // MARK: - Inventory Statistics
                VStack(alignment: .leading, spacing: 16) {
                    Button {
                        router.navigate(to: .inventoryListView(location: nil, showAllHomes: false))
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
                                .accessibilityIdentifier("dashboard-recent-item-\(item.id)")

                                if item.id != topRecentItems.last?.id {
                                    Divider()
                                        .padding(.leading, 92)
                                }
                            }

                            Divider()
                                .padding(.leading, 16)

                            Button {
                                router.navigate(to: .inventoryListView(location: nil, showAllHomes: false))
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

                // MARK: - Location Statistics
                LocationStatisticsView()
                    .padding(.top, 24)

                // MARK: - Label Statistics
                LabelStatisticsView()
                    .padding(.top, 24)
                    .padding(.bottom, 24)
            }

        }
        .flexibleHeaderScrollView()
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
        .fullScreenCover(isPresented: $showItemCreationFlow) {
            // Present camera directly with default single-item mode
            // User can switch modes via segmented control in camera
            EnhancedItemCreationFlowView(
                captureMode: .singleItem,
                location: nil
            )
            .tint(.green)
        }
        .whatsNewSheet()
        .onAppear {
            // Sync activeHomeId with the home being displayed
            // This ensures items created from this dashboard are assigned to the correct home
            if let displayHome = displayHome {
                let homeIdString = displayHome.id.uuidString
                if settings.activeHomeId != homeIdString {
                    print("🏠 DashboardView - Syncing activeHomeId to: \(displayHome.displayName) (\(homeIdString))")
                    settings.activeHomeId = homeIdString
                }
            }
        }
        .task(id: home?.imageURL) {
            guard let home = home,
                let imageURL = home.imageURL,
                !isLoading
            else { return }

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
            HStack {
                Text((home?.displayName.isEmpty == false ? home?.displayName : nil) ?? "Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal)

                Spacer()

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
            //            .padding(.bottom)
        }
        .background(alignment: .bottom) {
            LinearGradient(
                gradient: Gradient(colors: [.black.opacity(0.6), .clear]),
                startPoint: .bottom,
                endPoint: .center
            )
            .frame(height: 150)
        }
    }

    private func createFromPhoto() {
        let aiItemsCount = items.filter({ $0.hasUsedAI }).count
        print(
            "📱 DashboardView.createFromPhoto - Total items: \(items.count), AI items: \(aiItemsCount), isPro: \(settings.isPro)"
        )

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
        .background(
            RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
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
