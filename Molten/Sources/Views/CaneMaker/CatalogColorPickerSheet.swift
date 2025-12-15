//
//  CatalogColorPickerSheet.swift
//  Molten
//
//  Sheet for searching and selecting catalog items to use as colors in cane designs.
//

import SwiftUI

/// Scope for filtering color picker results
enum ColorPickerScope: String, CaseIterable {
    case catalog = "Catalog"
    case inventory = "Inventory"
}

/// Sheet view for searching catalog items and selecting one for its color
struct CatalogColorPickerSheet: View {
    @Binding var catalogItems: [UnifiedCatalogItem]
    @Binding var isLoading: Bool
    let selectedCOE: Int
    let onSelect: (UnifiedCatalogItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    @State private var searchText = ""
    @State private var selectedScope: ColorPickerScope = .inventory
    @State private var itemsWithInventory: Set<String> = []
    @State private var isLoadingInventory = false

    /// Items that have color data and match the selected COE
    private var itemsWithColors: [UnifiedCatalogItem] {
        catalogItems.filter { item in
            // Must be glass (not coatings or tools)
            guard item.itemType == .glass else {
                return false
            }
            // Must have color data
            guard let colors = item.dominant_colors, !colors.isEmpty else {
                return false
            }
            // Must match selected COE
            guard let itemCOE = item.coe, Int(itemCOE) == selectedCOE else {
                return false
            }
            // If inventory scope, must have inventory
            if selectedScope == .inventory {
                return itemsWithInventory.contains(item.stable_id)
            }
            return true
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
                if isLoading || isLoadingInventory {
                    loadingView
                } else if itemsWithColors.isEmpty {
                    // No items have color data
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 40))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Text(selectedScope == .inventory ? "No inventory items with color data" : "No items with color data")
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
            .navigationTitle("COE \(selectedCOE) Glass")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search glass colors...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(ColorPickerScope.allCases, id: \.self) { scope in
                            Button {
                                selectedScope = scope
                            } label: {
                                HStack {
                                    Text(scope.rawValue)
                                    if scope == selectedScope {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedScope.rawValue)
                                .font(DesignSystem.Typography.listItemCaption)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await loadInventoryItems()
        }
    }

    private func loadInventoryItems() async {
        isLoadingInventory = true
        do {
            let items = try await dependencies.inventoryTrackingService.getItemsWithInventory()
            itemsWithInventory = Set(items)
        } catch {
            print("Error loading inventory items: \(error)")
        }
        isLoadingInventory = false
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

    /// Threshold for high color variance warning
    private static let highVarianceThreshold: Double = 50.0

    /// Whether this item has high color variance
    private var hasHighVariance: Bool {
        guard let spread = item.color_spread else { return false }
        return spread > Self.highVarianceThreshold
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Color swatch
                colorSwatch
                    .frame(width: 44, height: 44)

                // Item info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.name)
                            .font(DesignSystem.Typography.formValue)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        if hasHighVariance {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DesignSystem.Colors.accentWarning)
                        }
                    }

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
                // Multiple colors - show layered circles to indicate variance
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
        selectedCOE: 96,
        onSelect: { _ in }
    )
}
