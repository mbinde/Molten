//
//  DesignSystem.swift
//  Flameworker
//
//  Design system for maintaining UI consistency across the app.
//  All views should reference these values instead of using hardcoded constants.
//

import SwiftUI

/// Central design system for Flameworker UI
/// Reference these constants in all views to maintain consistency
enum DesignSystem {

    // MARK: - Spacing

    /// Standard spacing values used throughout the app
    enum Spacing {
        /// No spacing (0pt)
        static let none: CGFloat = 0

        /// Minimal spacing for very tight layouts (2pt)
        static let xxs: CGFloat = 2

        /// Extra small spacing for text hierarchies (4pt)
        static let xs: CGFloat = 4

        /// Small spacing for compact layouts (6pt)
        static let sm: CGFloat = 6

        /// **Most common** - Standard spacing for related content (8pt)
        static let md: CGFloat = 8

        /// Large spacing between sections (12pt)
        static let lg: CGFloat = 12

        /// Extra large spacing for major sections (16pt)
        static let xl: CGFloat = 16

        /// Very large spacing for separated content (20pt)
        static let xxl: CGFloat = 20

        /// Maximum spacing for major page sections (24pt)
        static let xxxl: CGFloat = 24

        /// Extra maximum spacing for special cases (30pt)
        static let max: CGFloat = 30
    }

    // MARK: - Padding

    /// Standard padding values for containers and cards
    enum Padding {
        /// Compact internal padding (8pt)
        static let compact: CGFloat = 8

        /// **Most common** - Standard card/form padding (12pt)
        static let standard: CGFloat = 12

        /// Generous external padding (16pt)
        static let generous: CGFloat = 16

        /// Vertical padding for rows (8pt)
        static let rowVertical: CGFloat = 8

        /// Vertical padding for compact rows (4pt)
        static let rowVerticalCompact: CGFloat = 4

        /// Horizontal padding for chips/tags (6pt)
        static let chip: CGFloat = 6

        /// Vertical padding for chips/tags (2pt)
        static let chipVertical: CGFloat = 2

        /// Vertical padding for buttons (6pt)
        static let buttonVertical: CGFloat = 6
    }

    // MARK: - Corner Radius

    /// Corner radius values for rounded elements
    enum CornerRadius {
        /// Small radius for minor elements (4pt)
        static let small: CGFloat = 4

        /// Small-medium radius for search results (6pt)
        static let smallMedium: CGFloat = 6

        /// **Most common** - Standard radius for cards and containers (8pt)
        static let medium: CGFloat = 8

        /// Large radius for search bars and input fields (10pt)
        static let large: CGFloat = 10

        /// Extra large radius for detail view cards (12pt)
        static let extraLarge: CGFloat = 12
    }

    // MARK: - Typography
    //
    // Use semantic names so it's clear what font to use where.
    // All fonts use system fonts (SF Pro) to support Dynamic Type.

    /// Semantic font definitions
    enum Typography {
        // MARK: - Screen-Level Headers
        // These are for navigation titles and major screen sections

        /// Large navigation titles - use with .bold weight
        /// Example: "My Inventory", "Catalog", "Projects"
        static let screenTitle = Font.largeTitle

        /// Inline navigation titles and major section headers - use with .semibold weight
        /// Example: Detail view titles, "Specifications", "Segments"
        static let sectionTitle = Font.title2

        /// Sub-section headers - use with .semibold weight
        /// Example: "Inventory Status", card headers
        static let subsectionTitle = Font.title3

        // MARK: - List Row Typography
        // Consistent fonts for all list rows across the app

        /// Primary text in list rows (item name)
        /// Example: "Bullseye Red Transparent"
        static let listItemTitle = Font.headline

        /// Secondary text in list rows (manufacturer, SKU)
        /// Example: "Bullseye • 0124-30"
        static let listItemSubtitle = Font.subheadline

        /// Tertiary text in list rows (tags, metadata)
        /// Example: Tag chips, "Sheet, 3mm"
        static let listItemCaption = Font.caption

        /// Smallest text for minimal info
        /// Example: "+3" quantity diff, tiny badges
        static let listItemCaptionSmall = Font.caption2

        // MARK: - Prominent Numbers (SF Rounded)
        // Use for inventory counts, temperatures, quantities - the "tactile" feel

        /// Large prominent number - SF Rounded Bold
        /// Example: "8" sheets in stock (detail view)
        static let prominentNumberLarge = Font.system(.title, design: .rounded)

        /// Medium prominent number - SF Rounded Bold
        /// Example: "8" in list row trailing badge
        static let prominentNumber = Font.system(.title3, design: .rounded)

        /// Small prominent number - SF Rounded
        /// Example: Compact quantity badges
        static let prominentNumberSmall = Font.system(.subheadline, design: .rounded)

        // MARK: - Form & Detail Typography

        /// Form field labels
        static let formLabel = Font.subheadline

        /// Form field values and body text
        static let formValue = Font.body

        /// Helper text below form fields
        static let formHelper = Font.caption

        // MARK: - Data Tiles (Detail View Specs)
        // For the grid of specification tiles

        /// Tile label (e.g., "COE Rating", "Manufacturer")
        static let tileLabel = Font.caption

        /// Tile value (e.g., "90", "Bullseye")
        static let tileValue = Font.system(.body, design: .rounded)

        // MARK: - Legacy Aliases (for gradual migration)

        @available(*, deprecated, renamed: "screenTitle")
        static let pageTitle = Font.title

        @available(*, deprecated, renamed: "sectionTitle")
        static let sectionHeader = Font.title2

        @available(*, deprecated, renamed: "subsectionTitle")
        static let subSectionHeader = Font.title3

        @available(*, deprecated, renamed: "listItemTitle")
        static let rowTitle = Font.headline

        @available(*, deprecated, renamed: "formValue")
        static let body = Font.body

        @available(*, deprecated, renamed: "formLabel")
        static let label = Font.subheadline

        @available(*, deprecated, renamed: "listItemCaption")
        static let caption = Font.caption

        @available(*, deprecated, renamed: "listItemCaptionSmall")
        static let captionSmall = Font.caption2

        // MARK: - Icon Sizes

        /// Large icon size for emphasis (60pt)
        static let iconLarge = Font.system(size: 60)

        /// Medium icon size for emphasis (20pt)
        static let iconMedium = Font.system(size: 20)
    }

    // MARK: - Font Weights

    /// Standard font weight modifiers
    enum FontWeight {
        /// Bold weight for page titles
        static let bold = Font.Weight.bold

        /// Semibold weight for section headers
        static let semibold = Font.Weight.semibold

        /// Medium weight for labels and emphasis
        static let medium = Font.Weight.medium
    }

    // MARK: - Colors
    //
    // "Luminous Precision" palette - warm colors inspired by molten glass
    //
    // IMPORTANT: Always use DesignSystem.Colors or Color.molten* extensions.
    // NEVER use raw Color.orange, Color.red, etc. in Views.
    // Run this to find violations:
    //   grep -r "Color\.\(red\|blue\|green\|orange\|yellow\|purple\|pink\|cyan\)" Molten/Sources/Views/

    /// Color palette and semantic colors
    enum Colors {
        // MARK: Text Colors

        /// Primary text color - Charcoal, softer than pure black
        static let textPrimary = Color(hex: "212121")

        /// Secondary/helper text (most common for descriptions)
        static let textSecondary = Color(hex: "757575")

        /// Very muted text
        static let textTertiary = Color(hex: "9E9E9E")

        // MARK: Brand Colors (Luminous Precision Palette)

        /// Molten Orange - Primary brand color, the color of hot glass
        /// Use for: main buttons, active tab icons, key highlights, tint color
        static let moltenOrange = Color(hex: "FF5722")

        /// Warm Amber - Secondary warmth
        /// Use for: warnings, low-stock indicators, "heating up" states
        static let moltenAmber = Color(hex: "FFC107")

        /// Slate Teal - Cool contrast
        /// Use for: links, in-stock counts, secondary actions where orange is too aggressive
        static let moltenTeal = Color(hex: "00796B")

        /// Warm Off-White - Subtle warmth to avoid "clinical" feel
        /// A very light cream that's warmer than pure white
        static let moltenAsh = Color(hex: "FFFBF7")

        // MARK: Semantic Colors (mapped to brand)

        /// Primary action color, selected states, numeric emphasis
        static let accentPrimary = moltenOrange

        /// Secondary action color for buttons and interactive elements
        static let accentSecondary = moltenTeal

        /// Success states, positive indicators, in-stock
        static let accentSuccess = moltenTeal

        /// Warnings, low stock, alternative emphasis
        static let accentWarning = moltenAmber

        /// Destructive actions, errors, out of stock
        static let accentDanger = Color(hex: "D32F2F")

        /// User-created content indicator (tags, notes) - violet from logo
        static let accentUser = Color(hex: "512DA8")

        /// Additional accent colors for variety
        static let accentPink = Color(hex: "E91E63")
        static let accentCyan = Color(hex: "00BCD4")

        // MARK: Background Colors

        /// App background - clean white/off-white
        #if canImport(UIKit)
        static let background = Color(.systemBackground)
        #else
        static let background = Color.white
        #endif

        /// Secondary content backgrounds (cards, forms)
        #if canImport(UIKit)
        static let backgroundSecondary = Color(.secondarySystemBackground)
        #else
        static let backgroundSecondary = Color.gray.opacity(0.1)
        #endif

        /// Tertiary nested backgrounds
        #if canImport(UIKit)
        static let backgroundTertiary = Color(.tertiarySystemBackground)
        #else
        static let backgroundTertiary = Color.gray.opacity(0.05)
        #endif

        /// Light gray backgrounds for input fields
        #if canImport(UIKit)
        static let backgroundInput = Color(.systemGray5)
        #else
        static let backgroundInput = Color.gray.opacity(0.15)
        #endif

        /// Even lighter backgrounds
        #if canImport(UIKit)
        static let backgroundInputLight = Color(.systemGray6)
        #else
        static let backgroundInputLight = Color.gray.opacity(0.08)
        #endif

        // MARK: Tinted Backgrounds

        /// Light teal tint for tags, info states
        static let tintTeal = moltenTeal.opacity(0.1)

        /// Light green tint for success states
        static let tintSuccess = accentSuccess.opacity(0.1)

        /// Light gray tint for neutral chips
        static let tintGray = Color(hex: "9E9E9E").opacity(0.1)

        /// Light amber tint for warnings
        static let tintWarning = moltenAmber.opacity(0.15)

        /// Light orange tint for primary highlights
        static let tintPrimary = moltenOrange.opacity(0.1)

        /// Light purple tint for user content
        static let tintUser = accentUser.opacity(0.1)

        /// Light red tint for errors/danger
        static let tintDanger = accentDanger.opacity(0.1)

        // MARK: Legacy Aliases (for gradual migration)
        // TODO: Remove these after updating all usages

        @available(*, deprecated, renamed: "tintTeal")
        static let tintBlue = tintTeal

        @available(*, deprecated, renamed: "tintSuccess")
        static let tintGreen = tintSuccess

        @available(*, deprecated, renamed: "tintWarning")
        static let tintOrange = tintWarning

        @available(*, deprecated, renamed: "accentUser")
        static let accentPurple = accentUser

        @available(*, deprecated, message: "Use accentWarning instead")
        static let accentYellow = moltenAmber

        // MARK: Opacity Modifiers

        /// Light background tinting
        static let opacityLight: Double = 0.1

        /// Slightly darker background tinting
        static let opacityMedium: Double = 0.15

        /// Muted interactive elements
        static let opacityInteractive: Double = 0.3

        /// Medium opacity backgrounds
        static let opacityBackground: Double = 0.5

        /// Subtle foreground dimming
        static let opacityForeground: Double = 0.6
    }

    // MARK: - Common Patterns

    /// Pre-defined component styles for consistency
    enum ComponentStyles {
        /// Standard card style
        static func card(background: Color = Colors.backgroundSecondary) -> some ViewModifier {
            CardStyle(background: background)
        }

        /// Standard chip/tag style
        static func chip(isSelected: Bool = false) -> some ViewModifier {
            ChipStyle(isSelected: isSelected)
        }

        /// Standard search bar style
        static func searchBar() -> some ViewModifier {
            SearchBarStyle()
        }
    }
}

// MARK: - View Modifiers

/// Standard card styling
private struct CardStyle: ViewModifier {
    let background: Color

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.vertical, DesignSystem.Padding.rowVertical)
            .background(background)
            .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

/// Standard chip/tag styling
private struct ChipStyle: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .font(.caption)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(isSelected ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.tintGray)
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

/// Standard search bar styling
private struct SearchBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.vertical, DesignSystem.Padding.rowVertical)
            .background(DesignSystem.Colors.backgroundInput)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Apply standard card styling
    func cardStyle(background: Color = DesignSystem.Colors.backgroundSecondary) -> some View {
        modifier(CardStyle(background: background))
    }

    /// Apply standard chip/tag styling
    func chipStyle(isSelected: Bool = false) -> some View {
        modifier(ChipStyle(isSelected: isSelected))
    }

    /// Apply standard search bar styling
    func searchBarStyle() -> some View {
        modifier(SearchBarStyle())
    }
}

extension Color {
    /// Create a Color from a hex string (e.g., "ff4500" or "#ff4500")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Convert Color to hex string (e.g., "#FF5733")
    func toHex() -> String? {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        #else
        return nil
        #endif
    }

    // MARK: - Molten Design System Colors
    //
    // Use these Color.molten* properties throughout the app.
    // This makes violations easy to detect:
    //   grep -r "Color\.\(red\|blue\|green\|orange\|yellow\|purple\|pink\|cyan\)" Molten/Sources/Views/
    //
    // If the grep finds matches, those are violations that should use Color.molten* instead.

    /// Primary brand color - hot glass orange
    static var moltenOrange: Color { DesignSystem.Colors.moltenOrange }

    /// Secondary warmth - amber for warnings/low stock
    static var moltenAmber: Color { DesignSystem.Colors.moltenAmber }

    /// Cool contrast - teal for links/success/in-stock
    static var moltenTeal: Color { DesignSystem.Colors.moltenTeal }

    /// Clean background - off-white ash
    static var moltenAsh: Color { DesignSystem.Colors.moltenAsh }

    /// Charcoal text - softer than pure black
    static var moltenCharcoal: Color { DesignSystem.Colors.textPrimary }

    /// User-created content - purple for user tags/notes
    static var moltenUser: Color { DesignSystem.Colors.accentUser }

    /// Danger/error state - red
    static var moltenDanger: Color { DesignSystem.Colors.accentDanger }
}
