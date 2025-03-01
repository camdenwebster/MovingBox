//
//  DashboardView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @State private var sortOrder = [SortDescriptor(\InventoryLocation.name)]
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    
    var body: some View {
        NavigationStack {
            List {
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
            .navigationTitle("Home Inventory")
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
