//
//  TagColorMapping.swift
//  Flameworker
//
//  Utility for mapping tag names to SwiftUI colors and gradients
//

import SwiftUI

/// Represents a color fill that can be either solid or gradient
enum TagColorFill {
    case solid(Color)
    case gradient(Gradient)
}

/// Utility for extracting colors from tag names
enum TagColorMapping {
    /// Extract color fill from tag name if it represents a color
    /// - Parameter tag: The tag name to analyze
    /// - Returns: A TagColorFill if the tag represents a known color, nil otherwise
    static func colorFillFromTag(_ tag: String) -> TagColorFill? {
        let lowercased = tag.lowercased()

        // Check for special gradient patterns first
        if lowercased.contains("amber") && lowercased.contains("purple") {
            // Amber-purple gradient
            return .gradient(Gradient(colors: [
                Color(red: 1.0, green: 0.75, blue: 0.0),  // Amber
                Color(red: 0.58, green: 0.0, blue: 0.83)   // Purple
            ]))
        }

        if lowercased == "multi" || lowercased == "multicolored" || lowercased.contains("rainbow") {
            // Rainbow gradient
            return .gradient(Gradient(colors: [
                .red, .orange, .yellow, .green, .blue, .purple
            ]))
        }

        if lowercased == "silver" || lowercased.contains("silver") {
            // Metallic silver gradient
            return .gradient(Gradient(colors: [
                Color(red: 0.9, green: 0.9, blue: 0.92),   // Bright silver
                Color(red: 0.65, green: 0.65, blue: 0.67), // Mid silver
                Color(red: 0.85, green: 0.85, blue: 0.87)  // Light silver
            ]))
        }

        if lowercased == "metallic" {
            // Darker metallic gradient
            return .gradient(Gradient(colors: [
                Color(red: 0.5, green: 0.5, blue: 0.52),   // Dark metallic
                Color(red: 0.35, green: 0.35, blue: 0.37), // Darker metallic
                Color(red: 0.55, green: 0.55, blue: 0.57)  // Mid metallic
            ]))
        }

        // Standard solid color mapping
        let colorMap: [String: Color] = [
            "red": .red,
            "orange": .orange,
            "yellow": .yellow,
            "green": .green,
            "blue": .blue,
            "purple": .purple,
            "pink": .pink,
            "brown": Color(red: 0.6, green: 0.4, blue: 0.2),
            "gray": .gray,
            "grey": .gray,
            "black": .black,
            "white": .white,
            "clear": Color(white: 0.95),
            "transparent": Color(white: 0.95),  // Same as clear
            "amber": Color(red: 1.0, green: 0.75, blue: 0.0),
            "teal": Color(red: 0.0, green: 0.5, blue: 0.5),
            "turquoise": Color(red: 0.25, green: 0.88, blue: 0.82),
            "violet": Color(red: 0.58, green: 0.0, blue: 0.83),
            "gold": Color(red: 1.0, green: 0.84, blue: 0.0),
            "bronze": Color(red: 0.8, green: 0.5, blue: 0.2),
            "copper": Color(red: 0.72, green: 0.45, blue: 0.2),
            "lime": Color(red: 0.75, green: 1.0, blue: 0.0),
            "cyan": .cyan,
            "magenta": Color(red: 1.0, green: 0.0, blue: 1.0),
            "indigo": Color(red: 0.29, green: 0.0, blue: 0.51)
        ]

        // Check for exact color name match
        for (colorName, color) in colorMap {
            if lowercased == colorName || lowercased.contains(colorName) {
                return .solid(color)
            }
        }

        return nil
    }

    /// Check if tag should display as a question mark icon
    /// - Parameter tag: The tag name to analyze
    /// - Returns: true if tag represents unknown/uncertain color
    static func isUnknownTag(_ tag: String) -> Bool {
        let lowercased = tag.lowercased()
        return lowercased == "unknown" || lowercased.contains("unknown")
    }

    /// Legacy function for backward compatibility - returns first color only
    /// - Parameter tag: The tag name to analyze
    /// - Returns: A Color if the tag represents a known color, nil otherwise
    @available(*, deprecated, message: "Use colorFillFromTag instead for gradient support")
    static func colorFromTag(_ tag: String) -> Color? {
        if let fill = colorFillFromTag(tag) {
            switch fill {
            case .solid(let color):
                return color
            case .gradient(let gradient):
                // Return the first color from the gradient
                return gradient.stops.first?.color ?? nil
            }
        }
        return nil
    }
}

/// View that renders a color circle with optional gradient support
struct TagColorCircle: View {
    let tag: String
    let size: CGFloat
    let strokeWidth: CGFloat
    let strokeColor: Color

    init(tag: String, size: CGFloat = 10, strokeWidth: CGFloat = 0.5, strokeColor: Color = Color.black.opacity(0.1)) {
        self.tag = tag
        self.size = size
        self.strokeWidth = strokeWidth
        self.strokeColor = strokeColor
    }

    var body: some View {
        // Check if this is an "unknown" tag first
        if TagColorMapping.isUnknownTag(tag) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )

                Image(systemName: "questionmark")
                    .font(.system(size: size * 0.6, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        } else if let fill = TagColorMapping.colorFillFromTag(tag) {
            switch fill {
            case .solid(let color):
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
            case .gradient(let gradient):
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: gradient,
                            center: .center
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
            }
        }
    }
}
