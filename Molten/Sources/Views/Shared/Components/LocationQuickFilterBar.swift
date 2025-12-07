//
//  LocationQuickFilterBar.swift
//  Molten
//
//  Horizontal scrolling location filter for quick filtering in inventory view.
//  Shows location chips that can be tapped to filter inventory by location.
//  Supports multi-select with an "All" option that clears other selections.
//

import SwiftUI

/// A horizontal scrolling bar of location chips for quick filtering.
/// Supports multi-select. "All" is first and clears other selections when tapped.
/// "(none)" filters to items without a location set.
struct LocationQuickFilterBar: View {
    /// The currently selected locations (empty set means "All" / no filter)
    @Binding var selectedLocations: Set<String>

    /// All available location names (sorted)
    let availableLocations: [String]

    /// Count of items per location (for display)
    let locationCounts: [String: Int]

    /// Count of items with no location set
    let noLocationCount: Int

    /// Total count of all items (for "All" chip)
    let totalCount: Int

    /// Callback when "Manage" button is tapped
    var onManageTapped: (() -> Void)?

    /// Special value used to represent "items with no location"
    static let noLocationValue = ""

    var body: some View {
        // Only show if there are locations OR there are items with no location
        // (If neither, there's nothing useful to filter by)
        if !availableLocations.isEmpty || noLocationCount > 0 {
            VStack(spacing: 0) {
                // Grey separator to visually distinguish from filter header
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 6)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        // "All" chip - always first, clears selection when tapped
                        allChip

                        // "(none)" chip - filters to items with NO location set
                        if !availableLocations.isEmpty {
                            locationChip(
                                label: "(none)",
                                value: Self.noLocationValue,
                                count: noLocationCount
                            )
                        }

                        // Location chips
                        ForEach(availableLocations, id: \.self) { location in
                            locationChip(
                                label: location,
                                value: location,
                                count: locationCounts[location] ?? 0
                            )
                        }

                        // Manage button (only show if callback provided)
                        if let onManageTapped {
                            Button {
                                onManageTapped()
                            } label: {
                                Text("Manage")
                                    .font(DesignSystem.Typography.caption)
                                    .fontWeight(DesignSystem.FontWeight.medium)
                                    .foregroundColor(DesignSystem.Colors.accentPrimary)
                            }
                            .accessibilityIdentifier("location_quick_filter_manage")
                        }
                    }
                    .padding(.horizontal, DesignSystem.Padding.standard)
                    .padding(.vertical, DesignSystem.Spacing.md)
                }
                .background(Color(.systemBackground))
            }
        }
    }

    private var allChip: some View {
        let isSelected = selectedLocations.isEmpty

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                // "All" clears all selections
                selectedLocations.removeAll()
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text("All")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(isSelected ? DesignSystem.FontWeight.bold : DesignSystem.FontWeight.medium)
                    .lineLimit(1)

                if totalCount > 0 {
                    Text("(\(totalCount))")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(isSelected ? DesignSystem.Colors.accentPrimary : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .accessibilityIdentifier("location_quick_filter_all")
    }

    @ViewBuilder
    private func locationChip(label: String, value: String, count: Int) -> some View {
        let isSelected = selectedLocations.contains(value)

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isSelected {
                    // Deselect this location
                    selectedLocations.remove(value)
                } else {
                    // Select this location (adds to multi-select)
                    selectedLocations.insert(value)
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text(label)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(isSelected ? DesignSystem.FontWeight.bold : DesignSystem.FontWeight.medium)
                    .lineLimit(1)

                if count > 0 {
                    Text("(\(count))")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.captionSmall)
                }
            }
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(isSelected ? DesignSystem.Colors.accentPrimary : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .accessibilityIdentifier("location_quick_filter_\(value.isEmpty ? "none" : value)")
    }
}

#Preview {
    VStack {
        // With locations - none selected (All active) + Manage button
        LocationQuickFilterBar(
            selectedLocations: .constant([]),
            availableLocations: ["Shelf A", "Shelf B", "Studio", "Garage"],
            locationCounts: ["Shelf A": 12, "Shelf B": 8, "Studio": 5, "Garage": 3],
            noLocationCount: 15,
            totalCount: 43,
            onManageTapped: { print("Manage tapped") }
        )

        Divider()

        // With multi-selection
        LocationQuickFilterBar(
            selectedLocations: .constant(["Shelf A", "Studio"]),
            availableLocations: ["Shelf A", "Shelf B", "Studio"],
            locationCounts: ["Shelf A": 12, "Shelf B": 8, "Studio": 5],
            noLocationCount: 10,
            totalCount: 35,
            onManageTapped: { print("Manage tapped") }
        )

        Divider()

        // No locations (should not render)
        LocationQuickFilterBar(
            selectedLocations: .constant([]),
            availableLocations: [],
            locationCounts: [:],
            noLocationCount: 0,
            totalCount: 0
        )
    }
}
