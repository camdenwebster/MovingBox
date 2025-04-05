//
//  AddPhotoButton.swift
//  MovingBox
//
//  Created by Camden Webster on 4/5/25.
//

import SwiftUI

struct AddPhotoButton: View {
    var body: some View {
        VStack {
            Image(systemName: "photo.circle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100, maxHeight: 100)
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce.down.byLayer, options: .nonRepeating)
            Text("Tap to add a photo")
        }
    }
}
