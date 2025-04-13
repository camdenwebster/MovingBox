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
//            .foregroundColor(.gray)
    }
}

extension View {
    func detailLabelStyle() -> some View {
        modifier(DetailLabel())
    }
}
