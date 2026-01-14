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
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

extension View {
    func detailLabelStyle() -> some View {
        modifier(DetailLabel())
    }

    func recommendedClipShape() -> some View {
        if #available(iOS 26.0, *) {
            return self.clipShape(.rect(corners: .concentric, isUniform: true))
        } else {
            return self.clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
