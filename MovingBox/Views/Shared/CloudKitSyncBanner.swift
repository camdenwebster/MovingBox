//
//  CloudKitSyncBanner.swift
//  MovingBox
//
//  Created by Claude Code
//

import SwiftUI

/// A banner that displays when CloudKit is actively syncing data
struct CloudKitSyncBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)

            Text("Syncing with iCloud...")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .padding(.top, 8)
    }
}

#Preview {
    VStack {
        CloudKitSyncBanner()
        Spacer()
    }
}
