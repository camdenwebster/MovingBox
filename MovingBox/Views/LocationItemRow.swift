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
            if let imageData = location.photo, let uiImage = UIImage(data: imageData) {
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
            }
            Text(location.name)
                .font(.title3)
            Text(location.desc)
                .detailLabelStyle()
        }
    }
}

//#Preview {
//    LocationItemRow()
//}
