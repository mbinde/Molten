//
//  CatalogColorPickerSheet.swift
//  Molten
//
//  Sheet for searching and selecting catalog items to use as colors in cane designs.
//

import SwiftUI

/// Sheet view for searching catalog items and selecting one for its color
struct CatalogColorPickerSheet: View {
    @Binding var catalogItems: [UnifiedCatalogItem]
    @Binding var isLoading: Bool
    let onSelect: (UnifiedCatalogItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    /// Items that have color data
    private var itemsWithColors: [UnifiedCatalogItem] {
        catalogItems.filter { item in
            if let colors = item.dominant_colors, !colors.isEmpty {
                return true
            }
            return false
        }
    }

    /// Filtered items based on search text
    private var filteredItems: [UnifiedCatalogItem] {
        if searchText.isEmpty {
            return itemsWithColors
        }

        let searchLower = searchText.lowercased()
        return itemsWithColors.filter { item in
            item.name.lowercased().contains(searchLower) ||
            item.manufacturer.lowercased().contains(searchLower) ||
            (item.sku?.lowercased().contains(searchLower) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if itemsWithColors.isEmpty {
                    // No items have color data
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 40))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Text("No items with color data")
                            .font(DesignSystem.Typography.formValue)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Find Glass Color")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search glass colors...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
            Text("Loading catalog...")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
            Text("No results for \"\(searchText)\"")
                .font(DesignSystem.Typography.formValue)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        List {
            ForEach(filteredItems, id: \.stable_id) { item in
                CatalogColorRow(item: item) {
                    onSelect(item)
                    dismiss()
                }
                .listRowBackground(DesignSystem.Colors.backgroundSecondary)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Catalog Color Row

/// A row displaying a catalog item with its color swatch
struct CatalogColorRow: View {
    let item: UnifiedCatalogItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Color swatch
                colorSwatch
                    .frame(width: 44, height: 44)

                // Item info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(DesignSystem.Typography.formValue)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    Text(item.manufacturer)
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var colorSwatch: some View {
        if let colors = item.dominant_colors, !colors.isEmpty {
            if colors.count == 1 {
                // Single color
                Circle()
                    .fill(Color(hex: colors[0]))
                    .overlay {
                        Circle()
                            .stroke(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                    }
            } else {
                // Multiple colors - show gradient or segments
                ZStack {
                    ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) { index, hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .scaleEffect(1.0 - Double(index) * 0.2)
                    }
                }
                .overlay {
                    Circle()
                        .stroke(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                }
            }
        } else {
            // No color - show placeholder
            Circle()
                .fill(DesignSystem.Colors.backgroundTertiary)
                .overlay {
                    Image(systemName: "questionmark")
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
        }
    }
}

#Preview {
    CatalogColorPickerSheet(
        catalogItems: .constant([]),
        isLoading: .constant(false),
        onSelect: { _ in }
    )
}
