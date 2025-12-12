//
//  CatalogListView.swift
//  Molten
//
//  List view component for CatalogView
//

import SwiftUI

struct CatalogListView: View {
    let items: [CompleteInventoryItemModel]

    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                NavigationLink(value: CatalogNavigationDestination.catalogItemDetail(itemModel: item)) {
                    GlassItemRowView.catalog(item: item)
                }
                .accessibilityIdentifier("catalog.item.\(item.glassItem.stable_id)")
            }

            // Footer with contact info for missing glass
            Section {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Are we missing some glass that you think should be here?")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Link("Contact us at info@moltenglass.app", destination: URL(string: "mailto:info@moltenglass.app")!)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.moltenOrange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .listRowBackground(Color.clear)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
        .accessibilityIdentifier("catalog.list")
    }
}
