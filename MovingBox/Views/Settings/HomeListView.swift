//
//  HomeListView.swift
//  MovingBox
//
//  Created by Claude on 12/20/25.
//

import Dependencies
import SQLiteData
import SwiftUI

struct HomeListView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager

    @FetchAll(SQLiteHome.order(by: \.name), animation: .default)
    private var homes: [SQLiteHome]

    @State private var showingCreateSheet = false

    var body: some View {
        List {
            if homes.isEmpty {
                ContentUnavailableView(
                    "No Homes",
                    systemImage: "house",
                    description: Text("Add a home to organize your inventory.")
                )
            } else {
                ForEach(homes) { home in
                    NavigationLink {
                        HomeDetailSettingsView(homeID: home.id)
                    } label: {
                        homeRow(home: home)
                    }
                }
            }
        }
        .navigationTitle("Homes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("Add Home", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                HomeDetailSettingsView(homeID: nil, presentedInSheet: true)
            }
        }
    }

    @ViewBuilder
    private func homeRow(home: SQLiteHome) -> some View {
        HStack(spacing: 12) {
            homeThumbnail(home: home)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(home.displayName)
                        .font(.headline)

                    if home.isPrimary {
                        Text("PRIMARY")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(.rect(cornerRadius: 4))
                    }
                }

                if !home.address1.isEmpty {
                    Text(formatAddress(home))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func homeThumbnail(home: SQLiteHome) -> some View {
        HomeThumbnailView(home: home)
    }

    private struct HomeThumbnailView: View {
        @Dependency(\.defaultDatabase) var database
        let home: SQLiteHome
        @State private var thumbnail: UIImage?

        var body: some View {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    Image(systemName: "house.fill")
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(home.color)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
            .task(id: home.id) {
                if let photo = try? await database.read({ db in
                    try SQLiteHomePhoto.primaryPhoto(for: home.id, in: db)
                }) {
                    thumbnail = await OptimizedImageManager.shared.thumbnailImage(
                        from: photo.data, photoID: photo.id.uuidString)
                }
            }
        }
    }

    @ViewBuilder
    private func homeIconPlaceholder(home: SQLiteHome) -> some View {
        Image(systemName: "house.fill")
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(home.color)
            .clipShape(.rect(cornerRadius: 8))
    }

    private func formatAddress(_ home: SQLiteHome) -> String {
        var components: [String] = []

        if !home.address1.isEmpty {
            components.append(home.address1)
        }

        var cityStateZip: [String] = []
        if !home.city.isEmpty {
            cityStateZip.append(home.city)
        }
        if !home.state.isEmpty {
            cityStateZip.append(home.state)
        }
        if !home.zip.isEmpty {
            cityStateZip.append(home.zip)
        }

        if !cityStateZip.isEmpty {
            components.append(cityStateZip.joined(separator: ", "))
        }

        return components.joined(separator: "\n")
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    NavigationStack {
        HomeListView()
            .environmentObject(Router())
            .environmentObject(SettingsManager())
    }
}
