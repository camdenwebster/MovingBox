//
//  DashboardView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import Dependencies
import PhotosUI
import RevenueCatUI
import SQLiteData
import SwiftUI
import SwiftUIBackports
import WhatsNewKit

@MainActor
struct DashboardView: View {
    @Dependency(\.defaultDatabase) var database
    let specificHomeID: UUID?

    @FetchAll(SQLiteHome.order(by: \.purchaseDate), animation: .default)
    private var homes: [SQLiteHome]

    @FetchAll(SQLiteInventoryItem.all, animation: .default)
    private var allItems: [SQLiteInventoryItem]

    @FetchAll(SQLiteInventoryItemLabel.all, animation: .default)
    private var allItemLabels: [SQLiteInventoryItemLabel]

    @FetchAll(SQLiteInventoryLabel.all, animation: .default)
    private var allLabels: [SQLiteInventoryLabel]

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared

    @State private var loadedImage: UIImage?
    @State private var loadingError: Error?
    @State private var isLoading = false
    @State private var cachedImageURL: URL?
    @State private var loadingStartDate: Date? = nil
    @State private var showingPaywall = false
    @State private var showItemCreationFlow = false

    // MARK: - Initializer

    init(homeID: UUID? = nil) {
        self.specificHomeID = homeID
    }

    // MARK: - Computed Properties

    private var displayHome: SQLiteHome? {
        if let specificHomeID = specificHomeID {
            return homes.first { $0.id == specificHomeID }
        }
        return homes.first { $0.isPrimary } ?? homes.last
    }

    private var home: SQLiteHome? {
        return displayHome
    }

    private var items: [SQLiteInventoryItem] {
        guard let displayHome = displayHome else {
            return allItems
        }
        return allItems.filter { $0.homeID == displayHome.id }
    }

    private var recentItems: [SQLiteInventoryItem] {
        let homeFiltered: [SQLiteInventoryItem]
        if let displayHome = displayHome {
            homeFiltered = allItems.filter { $0.homeID == displayHome.id }
        } else {
            homeFiltered = allItems
        }
        return homeFiltered.sorted { $0.createdAt > $1.createdAt }
    }

    private var totalReplacementCost: Decimal {
        items.reduce(0, { $0 + ($1.price * Decimal($1.quantityInt)) })
    }

    private var topRecentItems: [SQLiteInventoryItem] {
        Array(recentItems.prefix(3))
    }

    // Lookup for item labels
    private var labelsByItemID: [UUID: [SQLiteInventoryLabel]] {
        let labelsById = Dictionary(uniqueKeysWithValues: allLabels.map { ($0.id, $0) })
        var result: [UUID: [SQLiteInventoryLabel]] = [:]
        for itemLabel in allItemLabels {
            if let label = labelsById[itemLabel.inventoryLabelID] {
                result[itemLabel.inventoryItemID, default: []].append(label)
            }
        }
        return result
    }

    // Lookup for home names
    private var homeNameByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: homes.map { ($0.id, $0.displayName) })
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
                        router.navigate(to: .inventoryListView(locationID: nil, showAllHomes: false))
                    } label: {
                        DashboardSectionLabel(text: "All Inventory")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("dashboard-all-inventory-button")

                    LazyVGrid(columns: columns, spacing: 16) {
                        StatCard(label: "Number of Items", value: "\(items.count)", identifier: "stat-items")
                        StatCard(
                            label: "Total Value", value: CurrencyFormatter.format(totalReplacementCost),
                            identifier: "stat-value")
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
                            ForEach(topRecentItems) { item in
                                Button {
                                    router.navigate(to: .inventoryDetailView(itemID: item.id, showSparklesButton: true))
                                } label: {
                                    HStack {
                                        InventoryItemRow(
                                            item: item,
                                            homeName: item.homeID.flatMap { homeNameByID[$0] },
                                            labels: labelsByItemID[item.id] ?? []
                                        )
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
                                router.navigate(to: .inventoryListView(locationID: nil, showAllHomes: false))
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
                locationID: nil
            )
            .tint(.green)
        }
        .whatsNewSheet()
        .onAppear {
            // Only sync activeHomeId when a specific home was explicitly passed to this view.
            // This prevents the default dashboard (showing primary home) from overwriting
            // the active home selection, which caused issues on iPhone navigation.
            if let specificHomeID = specificHomeID {
                let homeIdString = specificHomeID.uuidString
                if settings.activeHomeId != homeIdString {
                    let homeName = homes.first(where: { $0.id == specificHomeID })?.displayName ?? "Unknown"
                    print("🏠 DashboardView - Syncing activeHomeId to: \(homeName) (\(homeIdString))")
                    settings.activeHomeId = homeIdString
                }
            }
        }
        .task(id: home?.id) {
            guard let home = home, !isLoading else { return }

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

            if let photo = try? await database.read({ db in
                try SQLiteHomePhoto.primaryPhoto(for: home.id, in: db)
            }) {
                let image = UIImage(data: photo.data)
                await MainActor.run {
                    loadedImage = image
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

                // PhotoPickerView will be migrated separately
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
    var identifier: String = "stat"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("\(identifier)-label")
            Text(value)
                .font(.title2)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("\(identifier)-value")
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
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    DashboardView()
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
