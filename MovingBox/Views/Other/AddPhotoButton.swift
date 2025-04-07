//
//  AddPhotoButton.swift
//  MovingBox
//
//  Created by Camden Webster on 4/5/25.
//

import SwiftUI

struct AddPhotoButton: View {
    let action: () -> Void
    @State private var isBouncing = false
    
    var body: some View {
        Button {
            isBouncing = true
            action()
            // Reset the animation state after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isBouncing = false
            }
        } label: {
            VStack {
                Image(systemName: "photo.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 100, maxHeight: 100)
                    .foregroundStyle(.secondary)
                    .symbolEffect(.bounce.down.byLayer, options: .nonRepeating, isActive: isBouncing)
                Text("Tap to add a photo")
            }
        }
        .accessibilityIdentifier("tapToAddPhoto")
    }
}
