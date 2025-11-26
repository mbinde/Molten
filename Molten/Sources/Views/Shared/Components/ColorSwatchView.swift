//
//  ColorSwatchView.swift
//  Molten
//
//  Color gradient swatch view for visualizing glass colors
//
//  DESIGN SYSTEM: Uses DesignSystem.* for corner radius and spacing.
//

import SwiftUI

/// Displays a smooth color gradient based on dominant colors extracted from glass images
/// Used as a fallback when product images cannot be displayed due to licensing restrictions
struct ColorSwatchView: View {
    let colors: [String]  // Array of hex color strings (e.g., ["#2E5E41", "#1D4030", "#0C2219"])
    let size: CGFloat
    let cornerRadius: CGFloat
    let showGradientFrame: Bool  // Whether to show the radial gradient frame indicator

    /// Semantic size presets for consistent usage across the app
    enum Size {
        /// Small thumbnail for compact lists (40pt)
        case small
        /// Standard list row thumbnail (60pt)
        case medium
        /// Large display for detail views (80pt)
        case large
        /// Hero display (120pt)
        case hero
        /// Custom size
        case custom(CGFloat)

        var value: CGFloat {
            switch self {
            case .small: return 40
            case .medium: return 60
            case .large: return 80
            case .hero: return 120
            case .custom(let size): return size
            }
        }
    }

    init(colors: [String], size: CGFloat = 60, cornerRadius: CGFloat = DesignSystem.CornerRadius.medium, showGradientFrame: Bool = true) {
        self.colors = colors
        self.size = size
        self.cornerRadius = cornerRadius
        self.showGradientFrame = showGradientFrame
    }

    /// Convenience initializer using semantic size presets
    init(colors: [String], size: Size, cornerRadius: CGFloat = DesignSystem.CornerRadius.medium, showGradientFrame: Bool = true) {
        self.init(colors: colors, size: size.value, cornerRadius: cornerRadius, showGradientFrame: showGradientFrame)
    }

    var body: some View {
        if let gradient = createGradient() {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(gradient)
                .frame(width: size, height: size)
                .overlay(
                    Group {
                        if showGradientFrame {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(gradientFrameBorder, lineWidth: 3)
                        } else {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
                        }
                    }
                )
        } else {
            // Fallback if color parsing fails
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(.systemGray5))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "paintpalette")
                        .foregroundColor(Color(.systemGray3))
                        .font(.system(size: size * 0.4))
                }
        }
    }

    /// Angular gradient border that indicates this is a color approximation/generated gradient
    /// Light grey at edges (top/bottom/left/right), dark grey at corners - subtle and visible against any color
    private var gradientFrameBorder: some ShapeStyle {
        let darkGrey = Color(white: 0.3)  // Custom dark grey between systemGray6 and black
        let lightGrey = Color(white:0.9)

        return AngularGradient(
            gradient: Gradient(colors: [
                lightGrey,                // Top center (custom light grey)
                darkGrey,                 // Top-right corner (custom dark grey)
                lightGrey,      // Right center
                darkGrey,                 // Bottom-right corner
                lightGrey,      // Bottom center
                darkGrey,                 // Bottom-left corner
                lightGrey,      // Left center
                darkGrey,                 // Top-left corner
                lightGrey       // Back to top center
            ]),
            center: .center,
            startAngle: .degrees(-90),  // Start at top
            endAngle: .degrees(270)     // Full rotation
        )
    }

    /// Creates a linear gradient from the hex color strings
    private func createGradient() -> LinearGradient? {
        let swiftUIColors = colors.compactMap { hexToColor($0) }

        guard !swiftUIColors.isEmpty else {
            return nil
        }

        return LinearGradient(
            colors: swiftUIColors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Converts a hex color string to SwiftUI Color
    /// - Parameter hex: Hex string in format "#RRGGBB" or "RRGGBB"
    /// - Returns: SwiftUI Color, or nil if parsing fails
    private func hexToColor(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else {
            return nil
        }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        return Color(red: red, green: green, blue: blue)
    }
}

// MARK: - Preview

#Preview("Single Color") {
    VStack(spacing: DesignSystem.Spacing.xxl) {
        ColorSwatchView(colors: ["#2E5E41"])
        ColorSwatchView(colors: ["#FF5733"])
        ColorSwatchView(colors: ["#1E2E6C"])
    }
    .padding()
}

#Preview("Multiple Colors") {
    VStack(spacing: DesignSystem.Spacing.xxl) {
        // Green gradient (Agate Green)
        ColorSwatchView(colors: ["#2E5E41", "#1D4030", "#0C2219"])

        // Amber gradient
        ColorSwatchView(colors: ["#FF7F24", "#FF5733", "#D35400"])

        // Blue gradient
        ColorSwatchView(colors: ["#1E2E6C", "#14244B", "#0F1B3D"])

        // Brown gradient
        ColorSwatchView(colors: ["#9B8C6B", "#C4B69C", "#6F5F4D"])
    }
    .padding()
}

#Preview("Semantic Sizes") {
    VStack(spacing: DesignSystem.Spacing.xxl) {
        HStack(spacing: DesignSystem.Spacing.lg) {
            VStack {
                ColorSwatchView(colors: ["#2E5E41", "#1D4030"], size: .small)
                Text("Small").font(DesignSystem.Typography.listItemCaptionSmall)
            }
            VStack {
                ColorSwatchView(colors: ["#2E5E41", "#1D4030"], size: .medium)
                Text("Medium").font(DesignSystem.Typography.listItemCaptionSmall)
            }
            VStack {
                ColorSwatchView(colors: ["#2E5E41", "#1D4030"], size: .large)
                Text("Large").font(DesignSystem.Typography.listItemCaptionSmall)
            }
        }
        VStack {
            ColorSwatchView(colors: ["#2E5E41", "#1D4030"], size: .hero)
            Text("Hero").font(DesignSystem.Typography.listItemCaptionSmall)
        }
    }
    .padding()
}

#Preview("Invalid Colors Fallback") {
    VStack(spacing: DesignSystem.Spacing.xxl) {
        ColorSwatchView(colors: [])
        ColorSwatchView(colors: ["invalid", "colors"])
        ColorSwatchView(colors: ["#ZZZ"])
    }
    .padding()
}

#Preview("Gradient Frame Comparison") {
    VStack(spacing: DesignSystem.Spacing.max) {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("With Gradient Frame (Default)")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            HStack(spacing: DesignSystem.Spacing.xxl) {
                // Very dark colors
                ColorSwatchView(colors: ["#0C2219"], size: .large, showGradientFrame: true)
                // Mid-tone colors
                ColorSwatchView(colors: ["#2E5E41", "#1D4030", "#0C2219"], size: .large, showGradientFrame: true)
                // Light colors
                ColorSwatchView(colors: ["#E8D5C4"], size: .large, showGradientFrame: true)
            }
        }

        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Without Gradient Frame")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            HStack(spacing: DesignSystem.Spacing.xxl) {
                // Very dark colors
                ColorSwatchView(colors: ["#0C2219"], size: .large, showGradientFrame: false)
                // Mid-tone colors
                ColorSwatchView(colors: ["#2E5E41", "#1D4030", "#0C2219"], size: .large, showGradientFrame: false)
                // Light colors
                ColorSwatchView(colors: ["#E8D5C4"], size: .large, showGradientFrame: false)
            }
        }

        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Hero Size with Frame")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            ColorSwatchView(colors: ["#FF7F24", "#FF5733", "#D35400"], size: .hero, showGradientFrame: true)
        }
    }
    .padding()
}
