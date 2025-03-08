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
            if let uiImage = location.photo {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading) {
                Text(location.name)
                    .font(.title3)
                Text(location.desc)
                    .detailLabelStyle()
            }
            Spacer()
            Text("Items: \(location.inventoryItems?.count ?? 0)")
                .detailLabelStyle()
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
