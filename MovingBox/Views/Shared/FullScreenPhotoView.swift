import SwiftUI

struct FullScreenPhotoView: View {
    let images: [UIImage]
    @State private var selectedIndex: Int
    @Binding var isPresented: Bool

    @State private var showUI = true
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    init(images: [UIImage], initialIndex: Int = 0, isPresented: Binding<Bool>) {
        self.images = images
        self._selectedIndex = State(initialValue: initialIndex)
        self._isPresented = isPresented
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()

            // Photo carousel using TabView for reliable swipe behavior
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    ZoomableImageView(image: image)
                        .tag(index)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showUI.toggle()
                            }
                        }
                        .background(Color.black)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .background(Color.black)
            .simultaneousGesture(
                // Dismissal gesture - only vertical drags, simultaneous with TabView swipes
                DragGesture()
                    .onChanged { value in
                        // Only handle predominantly vertical drags
                        if abs(value.translation.height) > abs(value.translation.width) * 2 {
                            dragOffset = value.translation
                            isDragging = true
                        }
                    }
                    .onEnded { value in
                        // Dismiss if dragged down significantly
                        if value.translation.height > 150 {
                            isPresented = false
                        } else {
                            // Spring back to original position
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                        isDragging = false
                    }
            )
            .offset(y: dragOffset.height)
            .scaleEffect(isDragging ? 1 - abs(dragOffset.height) / 1000 : 1)

            // Top toolbar
            VStack {
                HStack {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()

                    Spacer()

                    // Photo counter
                    if images.count > 1 {
                        Text("\(selectedIndex + 1) of \(images.count)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.7),
                            Color.clear,
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                )

                Spacer()
            }
            .opacity(showUI ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: showUI)

            // Bottom indicators
            if images.count > 1 {
                VStack {
                    Spacer()

                    HStack(spacing: 8) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Circle()
                                .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 50)
                }
                .opacity(showUI ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showUI)
            }
        }
        .statusBarHidden(!showUI)
    }
}

struct ZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    // Magnification gesture for zoom
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            scale = min(max(newScale, minScale), maxScale)
                        }
                        .onEnded { _ in
                            lastScale = scale

                            // Reset if zoomed out too far
                            if scale <= minScale {
                                withAnimation(.spring()) {
                                    scale = minScale
                                    offset = .zero
                                    lastOffset = .zero
                                    lastScale = minScale
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    // Drag gesture only when zoomed in - simultaneous with TabView swipe
                    scale > minScale
                        ? DragGesture()
                            .onChanged { value in
                                let newOffset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                                offset = newOffset
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            } : nil
                )
                .onTapGesture(count: 2) {
                    // Double tap to zoom
                    withAnimation(.spring()) {
                        if scale > minScale {
                            // Reset zoom
                            scale = minScale
                            offset = .zero
                            lastOffset = .zero
                            lastScale = minScale
                        } else {
                            // Zoom in to 2x
                            scale = 2.0
                            lastScale = 2.0
                        }
                    }
                }
                .clipped()
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isPresented = true

        var body: some View {
            Button("Show Photos") {
                isPresented = true
            }
            .fullScreenCover(isPresented: $isPresented) {
                if let image = UIImage(systemName: "photo") {
                    FullScreenPhotoView(
                        images: [image, image, image],
                        initialIndex: 0,
                        isPresented: $isPresented
                    )
                }
            }
        }
    }

    return PreviewWrapper()
}
