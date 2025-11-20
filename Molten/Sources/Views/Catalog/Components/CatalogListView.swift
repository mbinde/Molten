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
        }
        .accessibilityIdentifier("catalog.list")
    }
}
