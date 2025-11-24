//
//  CatalogToolbarContent.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI

struct CatalogToolbarContent: ToolbarContent {
    @Binding var sortOption: SortOption
    @Binding var showingAllTags: Bool
    @Binding var showingDeleteAlert: Bool
    @Binding var showingBundleDebug: Bool
    let catalogItemsCount: Int
    
    let refreshAction: () -> Void
    let debugBundleAction: () -> Void
    let inspectJSONAction: () -> Void
    let loadJSONAction: () -> Void
    let smartMergeAction: () -> Void
    let loadIfEmptyAction: () -> Void
    let addItemAction: () -> Void
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
#if os(iOS)
            EditButton()
#endif
            Menu {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Label(option.rawValue, systemImage: option.sortIcon)
                            .tag(option)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .accessibilityIdentifier("catalog_toolbar_sort")

            Button("Tags") {
                showingAllTags = true
            }
            .accessibilityIdentifier("catalog_toolbar_tags")

            Button("Refresh") {
                refreshAction()
            }
            .accessibilityIdentifier("catalog_toolbar_refresh")

            Button("Debug") {
                debugBundleAction()
                showingBundleDebug = true
            }
            .accessibilityIdentifier("catalog_toolbar_debug")

            Button("Inspect JSON") {
                inspectJSONAction()
            }
            .accessibilityIdentifier("catalog_toolbar_inspect_json")

            Menu("Load Data") {
                Button("Load JSON (Clear & Reload)") {
                    loadJSONAction()
                }
                Button("Smart Merge JSON") {
                    smartMergeAction()
                }
                Button("Load Only If Empty") {
                    loadIfEmptyAction()
                }
            }
            .accessibilityIdentifier("catalog_toolbar_load_data")

            Button("Reset", role: .destructive) {
                showingDeleteAlert = true
            }
            .accessibilityIdentifier("catalog_toolbar_reset")

            Button(action: addItemAction) {
                Label("Add", systemImage: "plus")
            }
            .accessibilityIdentifier("catalog_toolbar_add")
        }
    }
}