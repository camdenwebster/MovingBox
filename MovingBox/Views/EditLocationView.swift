//
//  EditLocationView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import SwiftData
import SwiftUI

struct EditLocationView: View {
    @Bindable var location: InventoryLocation
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    
    var body: some View {
        Form {
            Section("Location Name") {
                TextField("Attic, Basement, Kitchen, Office, etc.", text: $location.name)
            }
            Section("Location Description") {
                TextField("Enter a Description", text: $location.desc)
            }
//            Section("Parent") {
//                Picker("Parent Location", selection: $location.parentLocation) {
//                    Text("None")
//                        .tag(Optional<InventoryLocation>.none)
//                    
//                    if locations.isEmpty == false {
//                        Divider()
//                        ForEach(locations) { location in
//                            Text(location.name)
//                                .tag(Optional(location))
//                        }
//                    }
//                }
//            }
        }
        .navigationTitle("Edit Location")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        
        return EditLocationView(location: previewer.location)
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
