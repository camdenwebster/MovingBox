//
//  HomeListView.swift
//  MovingBox
//
//  Created by Claude on 12/20/25.
//

import SwiftData
import SwiftUI

struct HomeListView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @Query(sort: [SortDescriptor(\Home.name)]) private var homes: [Home]

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
                        HomeDetailSettingsView(home: home)
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
                HomeDetailSettingsView(home: nil, presentedInSheet: true)
            }
        }
    }

    @ViewBuilder
    private func homeRow(home: Home) -> some View {
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
    private func homeThumbnail(home: Home) -> some View {
        AsyncImage(url: home.thumbnailURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(.rect(cornerRadius: 8))
            default:
                Image(systemName: "house.fill")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(home.color)
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
    }

    private func formatAddress(_ home: Home) -> String {
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
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Home.self, configurations: config)

        let home1 = Home(name: "Main House", address1: "123 Main St", city: "San Francisco", state: "CA", zip: "94102")
        home1.isPrimary = true

        let home2 = Home(
            name: "Beach House", address1: "456 Ocean Ave", city: "Santa Monica", state: "CA", zip: "90401")

        container.mainContext.insert(home1)
        container.mainContext.insert(home2)

        return NavigationStack {
            HomeListView()
                .modelContainer(container)
                .environmentObject(Router())
                .environmentObject(SettingsManager())
        }
    } catch {
        return Text("Failed to set up preview: \(error.localizedDescription)")
            .foregroundStyle(.red)
    }
}
