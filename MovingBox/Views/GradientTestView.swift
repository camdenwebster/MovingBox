//
//  GradientTestView.swift
//  MovingBox
//
//  Created by Camden Webster on 9/29/25.
//

import SwiftUI

struct GradientTestView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image("tablet")
                .resizable()
                .scaledToFit()
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.5), .init(color: .black.opacity(0.6), location: 0.8),
                        ], startPoint: .top, endPoint: .bottom)
                }
            Rectangle()
                .frame(height: 200)

        }
        .ignoresSafeArea()
        .clipShape(.rect(cornerRadius: 12.0))
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading) {
                Text("Sunburn")
                    .font(.headline)
                Text("Dominic Fike")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    GradientTestView()
}
