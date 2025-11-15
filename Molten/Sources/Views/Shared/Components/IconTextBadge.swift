//
//  IconTextBadge.swift
//  Molten
//
//  Created by Assistant on 11/15/25.
//  Reusable icon + text combination component
//

import SwiftUI

/// A simple icon + text component for metadata display
/// Lightweight alternative to BadgeLabel when no background is needed
struct IconTextBadge: View {
    let systemImage: String
    let text: String
    let foregroundColor: Color
    let font: Font
    let iconFont: Font?
    let spacing: CGFloat

    init(
        systemImage: String,
        text: String,
        foregroundColor: Color = .secondary,
        font: Font = .caption,
        iconFont: Font? = nil,
        spacing: CGFloat = 4
    ) {
        self.systemImage = systemImage
        self.text = text
        self.foregroundColor = foregroundColor
        self.font = font
        self.iconFont = iconFont
        self.spacing = spacing
    }

    var body: some View {
        HStack(spacing: spacing) {
            Image(systemName: systemImage)
                .font(iconFont ?? font)
            Text(text)
                .font(font)
        }
        .foregroundStyle(foregroundColor)
    }
}

// MARK: - Convenience Initializers

extension IconTextBadge {
    /// Location/distance badge (map pin icon)
    static func location(_ text: String) -> IconTextBadge {
        IconTextBadge(
            systemImage: "location.fill",
            text: text,
            foregroundColor: .secondary,
            font: .caption
        )
    }

    /// Phone number badge
    static func phone(_ text: String) -> IconTextBadge {
        IconTextBadge(
            systemImage: "phone.fill",
            text: text,
            foregroundColor: .secondary,
            font: .caption
        )
    }

    /// Time/duration badge (clock icon)
    static func time(_ text: String, color: Color = .secondary) -> IconTextBadge {
        IconTextBadge(
            systemImage: "clock.fill",
            text: text,
            foregroundColor: color,
            font: .caption,
            iconFont: .caption2
        )
    }

    /// Flame/technique badge (flame icon)
    static func flame(_ text: String, color: Color) -> IconTextBadge {
        IconTextBadge(
            systemImage: "flame.fill",
            text: text,
            foregroundColor: color,
            font: .caption,
            iconFont: .caption2
        )
    }

    /// Chart/segments badge (chart icon)
    static func chart(_ text: String) -> IconTextBadge {
        IconTextBadge(
            systemImage: "chart.line.uptrend.xyaxis",
            text: text,
            foregroundColor: .secondary,
            font: .caption,
            iconFont: .caption2
        )
    }

    /// Quantity badge (number/cube icon)
    static func quantity(_ text: String, color: Color = .blue) -> IconTextBadge {
        IconTextBadge(
            systemImage: "number",
            text: text,
            foregroundColor: color,
            font: .caption
        )
    }

    /// Inventory type badge with custom icon
    static func inventory(icon: String, text: String, color: Color = .blue) -> IconTextBadge {
        IconTextBadge(
            systemImage: icon,
            text: text,
            foregroundColor: color,
            font: .caption
        )
    }
}

// MARK: - Previews

#Preview("Basic Badges") {
    VStack(spacing: 12) {
        IconTextBadge(systemImage: "location.fill", text: "5.2 mi")

        IconTextBadge(systemImage: "phone.fill", text: "(206) 555-1234")

        IconTextBadge(systemImage: "clock.fill", text: "2h 30m", iconFont: .caption2)

        IconTextBadge(systemImage: "flame.fill", text: "Fusing", foregroundColor: .orange)
    }
    .padding()
}

#Preview("Convenience Initializers") {
    VStack(spacing: 12) {
        IconTextBadge.location("5.2 mi")

        IconTextBadge.phone("(206) 555-1234")

        IconTextBadge.time("2h 30m", color: .orange)

        IconTextBadge.flame("Fusing", color: .orange)

        IconTextBadge.chart("4 segments")

        IconTextBadge.quantity("15.5", color: .blue)

        IconTextBadge.inventory(icon: "line.3.horizontal", text: "50 rod", color: .blue)
    }
    .padding()
}

#Preview("Different Colors") {
    VStack(spacing: 12) {
        IconTextBadge.flame("Fusing", color: .orange)

        IconTextBadge.flame("Casting", color: .purple)

        IconTextBadge.flame("Glassblowing", color: .blue)

        IconTextBadge.time("Active", color: .green)

        IconTextBadge.time("Warning", color: .orange)

        IconTextBadge.time("Error", color: .red)
    }
    .padding()
}

#Preview("In Context - Location Details") {
    VStack(alignment: .leading, spacing: 8) {
        Text("Glass Art Supply")
            .font(.headline)

        Text("123 Main St, Seattle, WA")
            .font(.caption)
            .foregroundColor(.secondary)

        IconTextBadge.location("5.2 mi")

        IconTextBadge.phone("(206) 555-1234")
    }
    .padding()
}

#Preview("In Context - Schedule Details") {
    VStack(alignment: .leading, spacing: 8) {
        Text("Full Fuse - Dichroic")
            .font(.headline)

        HStack(spacing: 12) {
            IconTextBadge.flame("Fusing", color: .orange)

            Spacer()

            IconTextBadge.chart("4 segments")
        }

        IconTextBadge.time("2h 30m", color: .orange)
    }
    .padding()
}

#Preview("In List Row") {
    List {
        VStack(alignment: .leading, spacing: 8) {
            Text("Store Name")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("123 Main St, Seattle, WA")
                    .font(.caption)
                    .foregroundColor(.secondary)

                IconTextBadge.location("5.2 mi")

                IconTextBadge.phone("(206) 284-5600")
            }
        }
        .padding(.vertical, 4)
    }
}
