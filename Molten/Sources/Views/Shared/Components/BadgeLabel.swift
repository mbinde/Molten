//
//  BadgeLabel.swift
//  Molten
//
//  Created by Assistant on 11/15/25.
//  Reusable badge component for displaying metadata, quantities, and status
//

import SwiftUI

/// A reusable badge label for displaying metadata, quantities, or status
/// Displays text with optional icon in a colored rounded rectangle
struct BadgeLabel: View {
    let text: String
    let icon: String?
    let color: Color
    let style: BadgeStyle

    enum BadgeStyle {
        case filled      // Solid background with white text
        case tinted      // Light background with colored text
        case outlined    // Border only with colored text

        var textColor: Color {
            switch self {
            case .filled: return .white
            case .tinted, .outlined: return .primary
            }
        }
    }

    init(
        text: String,
        icon: String? = nil,
        color: Color = .accentColor,
        style: BadgeStyle = .tinted
    ) {
        self.text = text
        self.icon = icon
        self.color = color
        self.style = style
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(borderColor, lineWidth: style == .outlined ? 1 : 0)
        )
    }

    private var backgroundColor: Color {
        switch style {
        case .filled:
            return color
        case .tinted:
            return color.opacity(0.15)
        case .outlined:
            return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .filled:
            return .white
        case .tinted, .outlined:
            return color
        }
    }

    private var borderColor: Color {
        style == .outlined ? color : .clear
    }
}

// MARK: - Convenience Initializers

extension BadgeLabel {
    /// Creates a quantity badge (e.g., "5 items")
    static func quantity(_ count: Int, suffix: String = "item") -> BadgeLabel {
        let text = "\(count) \(count == 1 ? suffix : suffix + "s")"
        return BadgeLabel(text: text, icon: "number", color: .blue, style: .tinted)
    }

    /// Creates a COE badge (e.g., "COE 96")
    static func coe(_ value: Int32) -> BadgeLabel {
        BadgeLabel(text: "COE \(value)", color: .purple, style: .tinted)
    }

    /// Creates a status badge (e.g., "Active", "Completed")
    static func status(_ status: String, color: Color = .green) -> BadgeLabel {
        BadgeLabel(text: status, icon: "circle.fill", color: color, style: .filled)
    }

    /// Creates a tag badge (e.g., "Glass", "Tools")
    static func tag(_ tag: String, color: Color = .gray) -> BadgeLabel {
        BadgeLabel(text: tag, icon: "tag.fill", color: color, style: .tinted)
    }

    /// Creates a location badge (e.g., "Studio A")
    static func location(_ location: String) -> BadgeLabel {
        BadgeLabel(text: location, icon: "location.fill", color: .orange, style: .tinted)
    }

    /// Creates a store badge (e.g., "Bullseye Glass Co.")
    static func store(_ store: String) -> BadgeLabel {
        BadgeLabel(text: store, icon: "storefront", color: .blue, style: .tinted)
    }
}

// MARK: - View Extensions

extension View {
    /// Adds a badge overlay to the top-trailing corner
    func badge(_ badge: BadgeLabel) -> some View {
        self.overlay(
            badge
                .padding(4),
            alignment: .topTrailing
        )
    }
}

// MARK: - Previews

#Preview("Styles") {
    VStack(spacing: 16) {
        HStack(spacing: 8) {
            BadgeLabel(text: "Filled", color: .blue, style: .filled)
            BadgeLabel(text: "Tinted", color: .blue, style: .tinted)
            BadgeLabel(text: "Outlined", color: .blue, style: .outlined)
        }

        HStack(spacing: 8) {
            BadgeLabel(text: "With Icon", icon: "star.fill", color: .orange, style: .filled)
            BadgeLabel(text: "With Icon", icon: "star.fill", color: .orange, style: .tinted)
            BadgeLabel(text: "With Icon", icon: "star.fill", color: .orange, style: .outlined)
        }
    }
    .padding()
}

#Preview("Convenience Initializers") {
    VStack(spacing: 12) {
        BadgeLabel.quantity(5)
        BadgeLabel.quantity(1, suffix: "box")
        BadgeLabel.coe(96)
        BadgeLabel.coe(104)
        BadgeLabel.status("Active", color: .green)
        BadgeLabel.status("Pending", color: .orange)
        BadgeLabel.status("Cancelled", color: .red)
        BadgeLabel.tag("Glass")
        BadgeLabel.tag("Tools", color: .blue)
        BadgeLabel.location("Studio A")
        BadgeLabel.store("Bullseye Glass Co.")
    }
    .padding()
}

#Preview("Colors") {
    VStack(spacing: 12) {
        HStack(spacing: 8) {
            BadgeLabel(text: "Blue", color: .blue, style: .tinted)
            BadgeLabel(text: "Green", color: .green, style: .tinted)
            BadgeLabel(text: "Orange", color: .orange, style: .tinted)
            BadgeLabel(text: "Red", color: .red, style: .tinted)
        }
        HStack(spacing: 8) {
            BadgeLabel(text: "Purple", color: .purple, style: .tinted)
            BadgeLabel(text: "Pink", color: .pink, style: .tinted)
            BadgeLabel(text: "Gray", color: .gray, style: .tinted)
            BadgeLabel(text: "Accent", color: .accentColor, style: .tinted)
        }
    }
    .padding()
}

#Preview("In Context") {
    List {
        HStack {
            VStack(alignment: .leading) {
                Text("Bullseye 001 Transparent Clear")
                    .font(.headline)
                HStack(spacing: 8) {
                    BadgeLabel.coe(96)
                    BadgeLabel.quantity(12, suffix: "rod")
                    BadgeLabel.location("Shelf A")
                }
            }
            Spacer()
        }

        HStack {
            VStack(alignment: .leading) {
                Text("Effetre 004 Opaque Yellow")
                    .font(.headline)
                HStack(spacing: 8) {
                    BadgeLabel.coe(104)
                    BadgeLabel.quantity(3, suffix: "rod")
                    BadgeLabel.tag("Transparent")
                }
            }
            Spacer()
        }
    }
}

#Preview("Badge Overlay") {
    VStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 12)
            .fill(.accentColor.opacity(0.2))
            .frame(width: 200, height: 100)
            .badge(BadgeLabel.quantity(5))

        RoundedRectangle(cornerRadius: 12)
            .fill(Color.green.opacity(0.2))
            .frame(width: 200, height: 100)
            .badge(BadgeLabel.status("New", color: .green))
    }
    .padding()
}
