//
//  GlobalSearchOverlay.swift
//  Molten
//
//  Full-screen search overlay triggered by the floating search button
//

import SwiftUI

struct GlobalSearchOverlay: View {
    @Binding var isPresented: Bool
    let deps: AppDependencies
    var initialSearchText: String = ""
    var onSearchSubmit: ((String) -> Void)?
    var onItemSelected: ((CompleteInventoryItemModel) -> Void)?

    @State private var searchText: String
    @FocusState private var isSearchFieldFocused: Bool

    init(isPresented: Binding<Bool>, deps: AppDependencies, initialSearchText: String = "", onSearchSubmit: ((String) -> Void)? = nil, onItemSelected: ((CompleteInventoryItemModel) -> Void)? = nil) {
        self._isPresented = isPresented
        self.deps = deps
        self.initialSearchText = initialSearchText
        self.onSearchSubmit = onSearchSubmit
        self.onItemSelected = onItemSelected
        self._searchText = State(initialValue: initialSearchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Results area (above search bar) - always show, filter as you type
            SearchResultsView(searchText: searchText, deps: deps) { item in
                // Save search text before dismissing, then navigate to detail
                onSearchSubmit?(searchText)  // Save current search text
                isPresented = false
                onItemSelected?(item)
            }

            Divider()

            // Search bar at bottom
            HStack(spacing: 12) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search catalog...", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            // When user taps search button on keyboard, apply filter to catalog
                            if !searchText.isEmpty {
                                onSearchSubmit?(searchText)
                                isPresented = false
                            }
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )

                // X button to dismiss
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.systemGray5)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(DesignSystem.Colors.background)
        .presentationDragIndicator(.visible)
        .onAppear {
            // Focus the search field when overlay appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isSearchFieldFocused = true
            }
        }
    }
}

// MARK: - Search Results View

private struct SearchResultsView: View {
    let searchText: String
    let deps: AppDependencies
    let onItemTap: (CompleteInventoryItemModel) -> Void

    @State private var results: [CompleteInventoryItemModel] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty && !searchText.isEmpty {
                // Only show "no results" if user actually searched for something
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No results for \"\(searchText)\"")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results, id: \.id) { item in
                    SearchResultRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onItemTap(item)
                        }
                }
                .listStyle(.plain)
            }
        }
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
        .onAppear {
            performSearch(query: searchText)
        }
    }

    private func performSearch(query: String) {
        isLoading = true

        Task {
            // Search using the cached items
            let allItems = await MainActor.run { CatalogDataCache.shared.items }

            let filtered: [CompleteInventoryItemModel]
            if query.isEmpty {
                // Show all items when no search query
                filtered = allItems
            } else {
                // Use SearchTextParser for consistent search behavior with main catalog
                let searchMode = SearchTextParser.parseSearchText(query)
                // Always search all fields in global search (not just titles)
                filtered = allItems.filter { item in
                    let allFields = [
                        item.catalogItem.name,
                        item.catalogItem.stable_id,
                        item.catalogItem.manufacturer,
                        item.catalogItem.sku,
                        item.catalogItem.mfr_notes
                    ].compactMap { $0 }
                    return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
                }
            }

            await MainActor.run {
                results = filtered
                isLoading = false
            }
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let item: CompleteInventoryItemModel

    var body: some View {
        HStack(spacing: 12) {
            // Color swatch
            ColorSwatchView(
                colors: item.catalogItem.dominant_colors ?? [],
                size: .small,
                showGradientFrame: false
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.catalogItem.name)
                    .font(.body)
                    .lineLimit(1)

                Text("\(item.catalogItem.sku ?? "") • \(item.catalogItem.manufacturer)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
