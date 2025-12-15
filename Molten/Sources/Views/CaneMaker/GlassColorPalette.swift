//
//  GlassColorPalette.swift
//  Molten
//
//  Reusable color palette component for selecting glass colors from catalog/inventory.
//  Used by both Twist (CaneBuilder) and WigWag views.
//

import SwiftUI

/// Reusable color palette for selecting glass colors
struct GlassColorPalette: View {
    /// Title for the section
    let title: String

    /// Called when user taps a color in the palette
    let onColorSelected: (UnifiedCatalogItem) -> Void

    /// Optional: called when palette items change (for parent to track)
    var onPaletteChanged: (([UnifiedCatalogItem]) -> Void)?

    /// Available COE values for filtering
    private static let coeOptions: [Int] = [33, 90, 96, 104]

    /// Threshold for high color variance warning
    private static let highVarianceThreshold: Double = 50.0

    @AppStorage("caneMakerSelectedCOE") private var selectedCOE: Int = 33
    @State private var paletteItems: [UnifiedCatalogItem] = []
    @State private var showingCatalogSearch = false
    @State private var showingVarianceInfo = false
    @State private var catalogItems: [UnifiedCatalogItem] = []
    @State private var isLoadingCatalog = false

    private let catalogService = AppDependencies.shared.catalogService

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            headerRow

            colorGrid

            if paletteItems.isEmpty {
                Text("Tap + to add glass colors to your palette")
                    .font(DesignSystem.Typography.listItemCaptionSmall)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .sheet(isPresented: $showingCatalogSearch) {
            CatalogColorPickerSheet(
                catalogItems: $catalogItems,
                isLoading: $isLoadingCatalog,
                selectedCOE: selectedCOE,
                onSelect: { item in
                    addCatalogItem(item)
                    showingCatalogSearch = false
                }
            )
        }
        .alert("Color Variance", isPresented: $showingVarianceInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Some colors in your palette have significant color variation and may produce unexpected results. The color shown is the approximate average color.")
        }
        .task {
            await loadCatalogItems()
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.subsectionTitle)
                .fontWeight(DesignSystem.FontWeight.semibold)

            if paletteHasHighVarianceItems {
                Button {
                    showingVarianceInfo = true
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.accentWarning)
                }
            }

            Spacer()

            // COE picker
            Menu {
                ForEach(Self.coeOptions, id: \.self) { coe in
                    Button {
                        selectedCOE = coe
                    } label: {
                        HStack {
                            Text("COE \(coe)")
                            if coe == selectedCOE {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("COE \(selectedCOE)")
                        .font(DesignSystem.Typography.listItemCaption)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
    }

    // MARK: - Color Grid

    private var colorGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: DesignSystem.Spacing.md) {
            // "+" button to search catalog
            Button {
                showingCatalogSearch = true
            } label: {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.backgroundTertiary)
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.accentPrimary)
                }
                .overlay {
                    Circle()
                        .stroke(DesignSystem.Colors.accentPrimary, lineWidth: 2)
                }
            }
            .accessibilityLabel("Search catalog for glass color")

            // Palette colors from catalog
            ForEach(paletteItems, id: \.stable_id) { item in
                paletteColorButton(for: item)
            }
        }
    }

    // MARK: - Palette Color Button

    private func paletteColorButton(for item: UnifiedCatalogItem) -> some View {
        let isHighVariance = hasHighVariance(item)

        return Button {
            onColorSelected(item)
        } label: {
            ZStack(alignment: .topTrailing) {
                // Color swatch - show layered circles for multiple colors
                colorSwatch(for: item)
                    .frame(width: 44, height: 44)

                if isHighVariance {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.accentWarning)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.background)
                                .frame(width: 16, height: 16)
                        )
                        .offset(x: 4, y: -4)
                }
            }
        }
        .accessibilityLabel(item.name + (isHighVariance ? ", high color variance" : ""))
        .contextMenu {
            Button(role: .destructive) {
                removePaletteItem(item)
            } label: {
                Label("Remove from Palette", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func colorSwatch(for item: UnifiedCatalogItem) -> some View {
        if let colors = item.dominant_colors, !colors.isEmpty {
            if colors.count == 1 {
                Circle()
                    .fill(Color(hex: colors[0]))
                    .overlay {
                        Circle()
                            .stroke(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                    }
            } else {
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
            Circle()
                .fill(Color(hex: "888888"))
                .overlay {
                    Circle()
                        .stroke(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                }
        }
    }

    // MARK: - Helper Methods

    private func loadCatalogItems() async {
        guard catalogItems.isEmpty else { return }
        isLoadingCatalog = true
        do {
            catalogItems = try await catalogService.getAllCatalogItemsLightweight()
        } catch {
            print("Error loading catalog items: \(error)")
        }
        isLoadingCatalog = false
    }

    private func addCatalogItem(_ item: UnifiedCatalogItem) {
        withAnimation {
            if !paletteItems.contains(where: { $0.stable_id == item.stable_id }) {
                paletteItems.append(item)
                onPaletteChanged?(paletteItems)
            }
        }
    }

    private func removePaletteItem(_ item: UnifiedCatalogItem) {
        withAnimation {
            paletteItems.removeAll { $0.stable_id == item.stable_id }
            onPaletteChanged?(paletteItems)
        }
    }

    private func hasHighVariance(_ item: UnifiedCatalogItem) -> Bool {
        guard let spread = item.color_spread else { return false }
        return spread > Self.highVarianceThreshold
    }

    private var paletteHasHighVarianceItems: Bool {
        paletteItems.contains { hasHighVariance($0) }
    }
}

#Preview {
    GlassColorPalette(
        title: "Add Color",
        onColorSelected: { item in
            print("Selected: \(item.name)")
        }
    )
    .padding()
}
