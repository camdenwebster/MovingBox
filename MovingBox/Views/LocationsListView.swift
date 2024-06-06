//
//  LocationsListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import SwiftUI
import SwiftData

struct LocationsListView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @State private var path = NavigationPath()
    @State private var sortOrder = [SortDescriptor(\InventoryLocation.name)]
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    
    var body: some View {
        List(locations) { location in
            NavigationLink(location.name, value: location)
        }
        .navigationDestination(for: InventoryLocation.self) { location in
            InventoryListView(location: location)
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button("Add Item", systemImage: "plus", action: addLocation)
        }
    }
    
    func addLocation() {
        let location = InventoryLocation(id: UUID().uuidString, name: "", desc: "")
        modelContext.insert(location)
        router.navigate(to: .editLocationView(location: location))
    }
    
}

//#Preview {
//    do {
//        let previewer = try Previewer()
//        return LocationsListView()
//            .modelContainer(previewer.container)
//    } catch {
//        return Text("Failed to create preview: \(error.localizedDescription)")
//    }
//}
