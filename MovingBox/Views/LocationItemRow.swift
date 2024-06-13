//
//  LocationItemRow.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

struct LocationItemRow: View {
    var location: InventoryLocation
    var body: some View {
        HStack {
            Image(uiImage: location.photo == nil ? Constants.placeholderImage : location.photo!)
                .resizable()
                .imageListViewStyle()
            VStack(alignment: .leading) {
                Text(location.name)
                    .font(.title3)
                Text(location.desc)
                    .detailLabelStyle()
            }
        }
    }
}


#Preview {
    do {
        let previewer = try Previewer()
        
        return LocationItemRow(location: previewer.location)
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
