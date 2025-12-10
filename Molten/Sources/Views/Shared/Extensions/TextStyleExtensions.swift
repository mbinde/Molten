//
//  TextStyleExtensions.swift
//  Molten
//
//  Created by Assistant on 11/15/25.
//  Common text styling patterns as reusable extensions
//

import SwiftUI

// MARK: - Text Style Extensions

extension Text {
    /// Secondary caption text (most common pattern)
    /// Usage: Text("Label").secondaryCaption()
    func secondaryCaption() -> Text {
        self
            .font(.caption)
            .foregroundColor(DesignSystem.Colors.textSecondary)
    }

    /// Small secondary caption text
    /// Usage: Text("Label").secondaryCaptionSmall()
    func secondaryCaptionSmall() -> Text {
        self
            .font(.caption2)
            .foregroundColor(DesignSystem.Colors.textSecondary)
    }

    /// Secondary subheadline text
    /// Usage: Text("Subtitle").secondarySubheadline()
    func secondarySubheadline() -> Text {
        self
            .font(.subheadline)
            .foregroundColor(DesignSystem.Colors.textSecondary)
    }

    /// Emphasized headline (bold)
    /// Usage: Text("Title").emphasizedHeadline()
    func emphasizedHeadline() -> Text {
        self
            .font(.headline)
            .fontWeight(.semibold)
    }

    /// Medium weight headline
    /// Usage: Text("Title").mediumHeadline()
    func mediumHeadline() -> Text {
        self
            .font(.headline)
            .fontWeight(.medium)
    }

    /// Bold subheadline
    /// Usage: Text("Subtitle").boldSubheadline()
    func boldSubheadline() -> Text {
        self
            .font(.subheadline)
            .fontWeight(.bold)
    }
}

// MARK: - View Text Style Extensions

extension View {
    /// Applies secondary caption styling to any view with text
    /// Usage: Text("Label").secondaryCaptionStyle()
    func secondaryCaptionStyle() -> some View {
        self
            .font(.caption)
            .foregroundColor(DesignSystem.Colors.textSecondary)
    }

    /// Applies small secondary caption styling to any view with text
    /// Usage: Text("Label").secondaryCaptionSmallStyle()
    func secondaryCaptionSmallStyle() -> some View {
        self
            .font(.caption2)
            .foregroundColor(DesignSystem.Colors.textSecondary)
    }

    /// Applies secondary subheadline styling to any view with text
    /// Usage: Text("Subtitle").secondarySubheadlineStyle()
    func secondarySubheadlineStyle() -> some View {
        self
            .font(.subheadline)
            .foregroundColor(DesignSystem.Colors.textSecondary)
    }

    /// Applies emphasized headline styling to any view with text
    /// Usage: Text("Title").emphasizedHeadlineStyle()
    func emphasizedHeadlineStyle() -> some View {
        self
            .font(.headline)
            .fontWeight(.semibold)
    }

    /// Applies medium weight headline styling to any view with text
    /// Usage: Text("Title").mediumHeadlineStyle()
    func mediumHeadlineStyle() -> some View {
        self
            .font(.headline)
            .fontWeight(.medium)
    }

    /// Applies tertiary color styling
    /// Usage: Text("Label").tertiaryStyle()
    func tertiaryStyle() -> some View {
        self
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Previews

#Preview("Text Extensions") {
    VStack(alignment: .leading, spacing: 16) {
        Group {
            Text("Secondary Caption")
                .secondaryCaption()

            Text("Secondary Caption Small")
                .secondaryCaptionSmall()

            Text("Secondary Subheadline")
                .secondarySubheadline()

            Text("Emphasized Headline")
                .emphasizedHeadline()

            Text("Medium Headline")
                .mediumHeadline()

            Text("Bold Subheadline")
                .boldSubheadline()
        }

        Divider()

        Text("Before: Text(\"Label\").font(.caption).foregroundColor(DesignSystem.Colors.textSecondary)")
            .font(.caption2)
            .foregroundStyle(.tertiary)

        Text("After: Text(\"Label\").secondaryCaption()")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
    .padding()
}

#Preview("View Extensions") {
    VStack(alignment: .leading, spacing: 16) {
        Text("Secondary Caption Style")
            .secondaryCaptionStyle()

        Text("Secondary Caption Small Style")
            .secondaryCaptionSmallStyle()

        Text("Secondary Subheadline Style")
            .secondarySubheadlineStyle()

        Text("Emphasized Headline Style")
            .emphasizedHeadlineStyle()

        Text("Medium Headline Style")
            .mediumHeadlineStyle()
    }
    .padding()
}

#Preview("In Context") {
    List {
        VStack(alignment: .leading, spacing: 8) {
            Text("Product Name")
                .emphasizedHeadline()

            Text("Manufacturer")
                .secondarySubheadline()

            HStack {
                Text("SKU: 12345")
                    .secondaryCaption()

                Text("•")
                    .secondaryCaptionSmall()

                Text("COE 96")
                    .secondaryCaption()
            }
        }
        .padding(.vertical, 4)

        VStack(alignment: .leading, spacing: 8) {
            Text("Another Product")
                .mediumHeadline()

            Text("Different Manufacturer")
                .secondarySubheadline()

            Text("Additional details here")
                .secondaryCaptionSmall()
        }
        .padding(.vertical, 4)
    }
}
