//
//  CatalogView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct CatalogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingDeleteAlert = false
    @State private var showingBundleDebug = false
    @State private var bundleContents: [String] = []
    @State private var searchText = ""
    @State private var sortOption: SortOption = .name
    @State private var showingSortOptions = false
    @State private var selectedTags: Set<String> = []
    @State private var showingTagFilter = false
    @State private var showingAllTags = false
    @State private var isLoadingData = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)],
        animation: .default
    )
    private var catalogItems: FetchedResults<CatalogItem>
    
    var body: some View {
        NavigationStack {
            List {
                // Debug information
                if catalogItems.isEmpty {
                    Text("No catalog items found")
                        .foregroundColor(.secondary)
                        .onAppear {
                            print("🐛 CatalogView: No catalog items in fetch results")
                        }
                } else {
                    let totalItems = catalogItems.count
                    let filteredCount = filteredItems.count
                    let manufacturerCount = groupedItems.count
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Found \(totalItems) total items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !searchText.isEmpty || !selectedTags.isEmpty {
                            HStack {
                                Text("Showing \(filteredCount) filtered items")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                if !selectedTags.isEmpty {
                                    Text("• \(selectedTags.count) tag filter\(selectedTags.count == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        Text("\(manufacturerCount) manufacturers")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        print("🐛 CatalogView: Displaying \(totalItems) total items, \(filteredCount) filtered")
                    }
                }
                
                // Tag Filter Section
                if !allAvailableTags.isEmpty {
                    Section {
                        CatalogTagFilterView(
                            allAvailableTags: allAvailableTags,
                            selectedTags: $selectedTags,
                            showingAllTags: $showingAllTags
                        )
                    }
                }
                
                // Sections by manufacturer
                ForEach(groupedItems, id: \.0) { manufacturer, items in
                    Section(header: manufacturerSectionHeader(manufacturer, count: items.count)) {
                        ForEach(items) { item in
                            NavigationLink {
                                CatalogItemDetailView(item: item)
                            } label: {
                                CatalogItemRowView(item: item)
                            }
                        }
                        .onDelete { indexSet in
                            deleteItemsFromSection(items: items, offsets: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("Glass Color Catalog")
            .searchable(text: $searchText, prompt: "Search colors, codes, manufacturers, tags, or synonyms...")
            .toolbar {
                CatalogToolbarContent(
                    sortOption: $sortOption,
                    showingAllTags: $showingAllTags,
                    showingDeleteAlert: $showingDeleteAlert,
                    showingBundleDebug: $showingBundleDebug,
                    catalogItemsCount: catalogItems.count,
                    refreshAction: refreshData,
                    debugBundleAction: debugBundleContents,
                    inspectJSONAction: inspectJSONStructure,
                    loadJSONAction: loadJSONData,
                    smartMergeAction: smartMergeJSONData,
                    loadIfEmptyAction: loadJSONIfEmpty,
                    addItemAction: addItem
                )
            }
            .onChange(of: sortOption) { newValue in
                updateSorting(newValue)
            }
        }
        .alert("Delete All Items", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllItems()
            }
        } message: {
            Text("This will permanently delete all \(catalogItems.count) catalog items. This action cannot be undone.")
        }
        .sheet(isPresented: $showingBundleDebug) {
            CatalogBundleDebugView(bundleContents: bundleContents, isPresented: $showingBundleDebug)
        }
        .sheet(isPresented: $showingAllTags) {
            CatalogAllTagsView(
                allAvailableTags: allAvailableTags,
                catalogItems: catalogItems,
                selectedTags: $selectedTags,
                isPresented: $showingAllTags
            )
        }
    }
}

// MARK: - Preview
#Preview {
    CatalogView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}