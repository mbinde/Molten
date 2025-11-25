//
//  OverlayButtonStyle.swift
//  Molten
//
//  Reusable button style for buttons overlaid on images
//  Provides a semi-transparent background for visibility on any background
//

import SwiftUI

/// A button style for buttons that appear overlaid on images or variable backgrounds
/// Provides a semi-transparent dark background with blur for readability
struct OverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(DesignSystem.Spacing.sm)
            .background(
                Circle()
                    .fill(Color.black.opacity(configuration.isPressed ? 0.5 : 0.4))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

/// View modifier to apply overlay button background to any view
struct OverlayButtonBackground: ViewModifier {
    var shape: OverlayBackgroundShape = .circle

    enum OverlayBackgroundShape {
        case circle
        case capsule
        case roundedRectangle
    }

    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .padding(DesignSystem.Spacing.sm)
            .background(backgroundShape)
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch shape {
        case .circle:
            Circle()
                .fill(Color.black.opacity(0.4))
        case .capsule:
            Capsule()
                .fill(Color.black.opacity(0.4))
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color.black.opacity(0.4))
        }
    }
}

extension View {
    /// Apply overlay button background for visibility on images
    func overlayButtonBackground(shape: OverlayButtonBackground.OverlayBackgroundShape = .circle) -> some View {
        modifier(OverlayButtonBackground(shape: shape))
    }
}

// MARK: - Preview

#Preview("Overlay Button Styles") {
    ZStack {
        // Sample image background
        LinearGradient(
            colors: [.red, .orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: DesignSystem.Spacing.xl) {
            // Circle style
            HStack(spacing: DesignSystem.Spacing.lg) {
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(OverlayButtonStyle())

                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(OverlayButtonStyle())

                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(OverlayButtonStyle())
            }

            // Using view modifier
            HStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .overlayButtonBackground()

                Text("Back")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .overlayButtonBackground(shape: .capsule)
            }
        }
    }
}
