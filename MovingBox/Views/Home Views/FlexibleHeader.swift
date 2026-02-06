import SwiftUI

struct BackgroundExtensionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.backgroundExtensionEffect()
        } else {
            content
        }
    }
}

@Observable private class FlexibleHeaderGeometry {
    var offset: CGFloat = 0
}

private struct FlexibleHeaderContentModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(FlexibleHeaderGeometry.self) private var geometry

    func body(content: Content) -> some View {
        let baseHeight = UIScreen.main.bounds.height / 3
        let height = baseHeight - geometry.offset
        content
            .frame(height: height)
            .padding(.bottom, geometry.offset)
            .offset(y: geometry.offset)
    }
}

extension ScrollView {
    @MainActor func flexibleHeaderScrollView() -> some View {
        modifier(FlexibleHeaderScrollViewModifier())
    }
}

private struct FlexibleHeaderScrollViewModifier: ViewModifier {
    @State private var geometry = FlexibleHeaderGeometry()

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                min(geometry.contentOffset.y + geometry.contentInsets.top, 0)
            } action: { _, offset in
                geometry.offset = offset
            }
            .environment(geometry)
    }
}

extension View {
    func flexibleHeaderContent() -> some View {
        modifier(FlexibleHeaderContentModifier())
    }
}
