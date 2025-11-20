//
//  CatalogToolbar.swift
//  Molten
//
//  Toolbar component for CatalogView
//

import SwiftUI

struct CatalogToolbar: ToolbarContent {
    @Binding var sortOption: SortOption
    let onSortChange: (SortOption) -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                        onSortChange(option)
                    } label: {
                        Label(option.rawValue, systemImage: option.sortIcon)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .accessibilityLabel("Sort")
            }
        }
    }
}
