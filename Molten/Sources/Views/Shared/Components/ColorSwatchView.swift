//
//  ColorSwatchView.swift
//  Molten
//
//  Created by Assistant on 11/18/25.
//  Color gradient swatch view for visualizing glass colors
//

import SwiftUI

/// Displays a smooth color gradient based on dominant colors extracted from glass images
/// Used as a fallback when product images cannot be displayed due to licensing restrictions
struct ColorSwatchView: View {
    let colors: [String]  // Array of hex color strings (e.g., ["#2E5E41", "#1D4030", "#0C2219"])
    let size: CGFloat
    let cornerRadius: CGFloat

    init(colors: [String], size: CGFloat = 60, cornerRadius: CGFloat = 8) {
        self.colors = colors
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        if let gradient = createGradient() {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(gradient)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
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
    VStack(spacing: 20) {
        ColorSwatchView(colors: ["#2E5E41"])
        ColorSwatchView(colors: ["#FF5733"])
        ColorSwatchView(colors: ["#1E2E6C"])
    }
    .padding()
}

#Preview("Multiple Colors") {
    VStack(spacing: 20) {
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

#Preview("Different Sizes") {
    VStack(spacing: 20) {
        ColorSwatchView(colors: ["#2E5E41", "#1D4030", "#0C2219"], size: 40)
        ColorSwatchView(colors: ["#2E5E41", "#1D4030", "#0C2219"], size: 60)
        ColorSwatchView(colors: ["#2E5E41", "#1D4030", "#0C2219"], size: 100)
        ColorSwatchView(colors: ["#2E5E41", "#1D4030", "#0C2219"], size: 200)
    }
    .padding()
}

#Preview("Invalid Colors Fallback") {
    VStack(spacing: 20) {
        ColorSwatchView(colors: [])
        ColorSwatchView(colors: ["invalid", "colors"])
        ColorSwatchView(colors: ["#ZZZ"])
    }
    .padding()
}
