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

    /// Semantic font definitions with weight modifiers
    enum Typography {
        // MARK: Headers

        /// Large page titles (with .bold weight)
        static let pageTitle = Font.title

        /// Section headers and detail view names (with .semibold weight)
        static let sectionHeader = Font.title2

        /// Stat values and sub-section headers (with .semibold weight)
        static let subSectionHeader = Font.title3

        // MARK: Body Text

        /// Row titles and primary text
        static let rowTitle = Font.headline

        /// Default body text
        static let body = Font.body

        /// Form field labels and secondary information (with .medium weight)
        static let label = Font.subheadline

        /// Tertiary information and helper text
        static let caption = Font.caption

        /// Smallest text for minimal information
        static let captionSmall = Font.caption2

        // MARK: Custom Sizes

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

    /// Color palette and semantic colors
    enum Colors {
        // MARK: Text Colors

        /// Primary text color (system default)
        static let textPrimary = Color.primary

        /// Secondary/helper text (most common for descriptions)
        static let textSecondary = Color.secondary

        /// Very muted text
        static let textTertiary = Color.secondary.opacity(0.6)

        // MARK: Accent Colors

        /// Primary action color, selected states, numeric emphasis
        static let accentPrimary = Color.blue

        /// Success states, positive indicators
        static let accentSuccess = Color.green

        /// Warnings, alternative emphasis
        static let accentWarning = Color.orange

        /// Destructive actions, errors, low inventory
        static let accentDanger = Color.red

        /// Type indicators (e.g., stringer type)
        static let accentPurple = Color.purple

        /// Additional type colors
        static let accentPink = Color.pink
        static let accentCyan = Color.cyan
        static let accentYellow = Color.yellow

        // MARK: Background Colors

        /// App background
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

        /// Light blue tint for tags
        static let tintBlue = Color.blue.opacity(0.1)

        /// Light green tint for success
        static let tintGreen = Color.green.opacity(0.1)

        /// Light gray tint for neutral chips
        static let tintGray = Color.gray.opacity(0.1)

        /// Light orange tint for warnings
        static let tintOrange = Color.orange.opacity(0.15)

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
