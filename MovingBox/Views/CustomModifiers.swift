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

    @ViewBuilder
    func movingBoxNavigationTitleDisplayModeInline() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }

    @ViewBuilder
    func movingBoxFullScreenCoverCompat<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
            fullScreenCover(isPresented: isPresented, content: content)
        #else
            sheet(isPresented: isPresented, content: content)
        #endif
    }

    func recommendedClipShape() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            return self.clipShape(.rect(corners: .concentric, isUniform: true))
        } else {
            return self.clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    func movingBoxNavigationBarHidden(_ hidden: Bool) -> some View {
        #if os(iOS)
            navigationBarHidden(hidden)
        #else
            self
        #endif
    }

    @ViewBuilder
    func movingBoxNumberPadKeyboardType() -> some View {
        #if os(iOS)
            keyboardType(.numberPad)
        #else
            self
        #endif
    }

    @ViewBuilder
    func movingBoxDecimalPadKeyboardType() -> some View {
        #if os(iOS)
            keyboardType(.decimalPad)
        #else
            self
        #endif
    }

    @ViewBuilder
    func movingBoxNavigationBarToolbarHidden() -> some View {
        #if os(iOS)
            toolbar(.hidden, for: .navigationBar)
        #else
            self
        #endif
    }

    @ViewBuilder
    func movingBoxNavigationBarToolbarBackgroundVisible() -> some View {
        #if os(iOS)
            toolbarBackground(.visible, for: .navigationBar)
        #else
            self
        #endif
    }

    @ViewBuilder
    func movingBoxNavigationBarToolbarBackgroundHidden() -> some View {
        #if os(iOS)
            toolbarBackground(.hidden, for: .navigationBar)
        #else
            self
        #endif
    }
}

extension ToolbarItemPlacement {
    static var movingBoxLeading: ToolbarItemPlacement {
        #if os(iOS)
            .navigationBarLeading
        #else
            .automatic
        #endif
    }

    static var movingBoxTrailing: ToolbarItemPlacement {
        #if os(iOS)
            .navigationBarTrailing
        #else
            .automatic
        #endif
    }

    static var movingBoxBottomBar: ToolbarItemPlacement {
        #if os(iOS)
            .bottomBar
        #else
            .automatic
        #endif
    }
}
