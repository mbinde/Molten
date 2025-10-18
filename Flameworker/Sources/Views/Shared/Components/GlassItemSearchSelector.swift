//
//  GlassItemSearchSelector.swift
//  Flameworker
//
//  Created by Assistant on 10/18/25.
//  Shared component for searching and selecting glass items
//

import SwiftUI

/// Shared component for searching and selecting glass items
/// Used by AddInventoryItemView and AddShoppingListItemView
struct GlassItemSearchSelector: View {
    @Binding var selectedGlassItem: GlassItemModel?
    @Binding var searchText: String
    let prefilledNaturalKey: String?
    let glassItems: [CompleteInventoryItemModel]
    let onSelect: (GlassItemModel) -> Void
    let onClear: () -> Void

    var body: some View {
        Section("Glass Item") {
            VStack(alignment: .leading, spacing: 8) {
                if prefilledNaturalKey == nil {
                    searchField
                }

                if let glassItem = selectedGlassItem {
                    selectedItemView(glassItem)
                } else if !searchText.isEmpty && prefilledNaturalKey == nil {
                    searchResultsView
                } else if prefilledNaturalKey != nil {
                    notFoundView
                } else {
                    instructionView
                }
            }
        }
    }

    // MARK: - Sub-Views

    private var searchField: some View {
        TextField("Search glass items...", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .disabled(selectedGlassItem != nil)
    }

    private func selectedItemView(_ glassItem: GlassItemModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            selectedItemHeader
            GlassItemCard(item: glassItem, variant: .compact)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(selectedItemBackgroundColor)
        .overlay(selectedItemBorder)
        .cornerRadius(8)
    }

    private var selectedItemHeader: some View {
        HStack {
            Text(prefilledNaturalKey != nil ? "Adding for:" : "Selected:")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if prefilledNaturalKey == nil {
                clearButton
            }
        }
    }

    private var clearButton: some View {
        Button("Clear") {
            onClear()
        }
        .font(.caption)
        .foregroundColor(.blue)
    }

    private var selectedItemBackgroundColor: Color {
        let baseColor = prefilledNaturalKey != nil ? Color.blue : Color.green
        return baseColor.opacity(0.1)
    }

    private var selectedItemBorder: some View {
        let borderColor = prefilledNaturalKey != nil ? Color.blue : Color.green
        return RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor, lineWidth: 1)
    }

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(filteredGlassItems.prefix(10), id: \.id) { item in
                    Button(action: {
                        onSelect(item.glassItem)
                    }) {
                        GlassItemCard(item: item.glassItem, variant: .compact)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 300)
    }

    private var notFoundView: some View {
        Group {
            if selectedGlassItem == nil && prefilledNaturalKey != nil {
                NotFoundCard(naturalKey: prefilledNaturalKey!)
            } else {
                EmptyView()
            }
        }
    }

    private var instructionView: some View {
        Group {
            if selectedGlassItem == nil && prefilledNaturalKey == nil {
                Text("Search above to find a glass item")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredGlassItems: [CompleteInventoryItemModel] {
        if searchText.isEmpty {
            return glassItems
        } else {
            return glassItems.filter { item in
                let searchLower = searchText.lowercased()
                return item.glassItem.name.lowercased().contains(searchLower) ||
                       item.glassItem.natural_key.lowercased().contains(searchLower) ||
                       item.glassItem.manufacturer.lowercased().contains(searchLower)
            }
        }
    }
}

// MARK: - Helper Views

struct NotFoundCard: View {
    let naturalKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Glass item not found")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Natural Key: \(naturalKey)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange, lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

#Preview {
    let _ = RepositoryFactory.configureForTesting()

    struct PreviewWrapper: View {
        @State private var selectedItem: GlassItemModel? = nil
        @State private var searchText: String = ""
        @State private var glassItems: [CompleteInventoryItemModel] = []
        private let catalogService = RepositoryFactory.createCatalogService()

        var body: some View {
            Form {
                GlassItemSearchSelector(
                    selectedGlassItem: $selectedItem,
                    searchText: $searchText,
                    prefilledNaturalKey: nil,
                    glassItems: glassItems,
                    onSelect: { item in
                        selectedItem = item
                        searchText = ""
                    },
                    onClear: {
                        selectedItem = nil
                        searchText = ""
                    }
                )
            }
            .task {
                do {
                    glassItems = try await catalogService.getAllGlassItems()
                } catch {
                    print("Error loading items: \(error)")
                }
            }
        }
    }

    return PreviewWrapper()
}
