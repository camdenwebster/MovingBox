//
//  CustomModifiers.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

struct DetailLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundColor(.gray)
    }
}

struct ImageListView: ViewModifier {
    func body(content: Content) -> some View {
        content                
            .scaledToFit()
            .frame(width: 50, height: 50)
            .cornerRadius(12)
            .clipped()
    }
}

extension View {
    func detailLabelStyle() -> some View {
        modifier(DetailLabel())
    }
    
    func imageListViewStyle() -> some View {
        modifier(ImageListView())
    }
}
