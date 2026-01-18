//
//  FullscreenImageGallery.swift
//  Molten
//
//  Fullscreen image gallery with swipe navigation and pinch-to-zoom
//  for viewing multiple catalog images.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

/// Fullscreen gallery view for browsing multiple images
/// Supports swipe navigation, pinch-to-zoom, and double-tap to zoom
struct FullscreenImageGallery: View {
    let images: [UIImage]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    init(images: [UIImage], startIndex: Int = 0) {
        self.images = images
        self.startIndex = startIndex
        self._currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Image gallery
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    ZoomableImageView(image: images[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Overlay controls
            VStack {
                // Top bar with close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.5), radius: 2)
                    }
                    .padding()
                }

                Spacer()

                // Bottom bar with page indicator
                if images.count > 1 {
                    VStack(spacing: 8) {
                        // Page dots
                        HStack(spacing: 8) {
                            ForEach(images.indices, id: \.self) { index in
                                Circle()
                                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: 8, height: 8)
                            }
                        }

                        // Counter text
                        Text("\(currentIndex + 1) of \(images.count)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .statusBarHidden()
    }
}

// MARK: - Zoomable Image View

/// Individual zoomable image view with pinch and double-tap gestures
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
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            scale = min(maxScale, max(minScale, newScale))
                        }
                        .onEnded { _ in
                            lastScale = scale
                            withAnimation(.easeOut(duration: 0.2)) {
                                if scale < minScale {
                                    scale = minScale
                                    lastScale = minScale
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if scale > 1.0 {
                            // Reset to original
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            // Zoom in
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    FullscreenImageGallery(
        images: [
            UIImage(systemName: "photo.fill")!,
            UIImage(systemName: "photo.fill.on.rectangle.fill")!,
            UIImage(systemName: "photo.stack.fill")!
        ],
        startIndex: 0
    )
}

#endif
