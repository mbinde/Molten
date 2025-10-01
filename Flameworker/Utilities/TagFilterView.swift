//
//  TagFilterView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI
import CoreData

/// Configuration for tag filter view appearance and behavior
struct TagFilterConfiguration {
    let navigationTitle: String
    let sectionTitle: String
    let selectedSectionTitle: String
    let clearAllButtonTitle: String
    let dismissAction: () -> Void
    let showCancelButton: Bool
    
    static func searchable(dismissAction: @escaping () -> Void) -> TagFilterConfiguration {
        TagFilterConfiguration(
            navigationTitle: "Filter by Tags",
            sectionTitle: "Available Tags",
            selectedSectionTitle: "Selected Tags",
            clearAllButtonTitle: "Clear All Selected Tags",
            dismissAction: dismissAction,
            showCancelButton: true
        )
    }
    
    static func allTags(dismissAction: @escaping () -> Void) -> TagFilterConfiguration {
        TagFilterConfiguration(
            navigationTitle: "Tag Filter",
            sectionTitle: "All Available Tags",
            selectedSectionTitle: "Active Filters",
            clearAllButtonTitle: "Clear All Filters",
            dismissAction: dismissAction,
            showCancelButton: false
        )
    }
}

/// Unified tag filter view that can be configured for different use cases
struct TagFilterView: View {
    let allAvailableTags: [String]
    @Binding var selectedTags: Set<String>
    let catalogItems: FetchedResults<CatalogItem>
    let configuration: TagFilterConfiguration
    
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    // Filtered tags based on search text
    private var filteredTags: [String] {
        if searchText.isEmpty {
            return allAvailableTags
        } else {
            return allAvailableTags.filter { tag in
                tag.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Tags list
                List {
                    Section("\(configuration.sectionTitle) (\(filteredTags.count))") {
                        if filteredTags.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(filteredTags, id: \.self) { tag in
                                let itemsWithTag = catalogItems.filter { item in
                                    CatalogItemHelpers.tagsArrayForItem(item).contains(tag)
                                }
                                
                                tagRow(for: tag, itemCount: itemsWithTag.count)
                            }
                        }
                    }
                    
                    if !selectedTags.isEmpty {
                        Section("\(configuration.selectedSectionTitle) (\(selectedTags.count))") {
                            ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                                selectedTagRow(for: tag)
                            }
                            
                            Button(configuration.clearAllButtonTitle) {
                                selectedTags.removeAll()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(configuration.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if configuration.showCancelButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            configuration.dismissAction()
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        configuration.dismissAction()
                    }
                    .fontWeight(configuration.showCancelButton ? .semibold : .regular)
                }
            }
            .onAppear {
                // Focus search field when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFieldFocused = true
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            TextField("Search tags...", text: $searchText)
                .focused($isSearchFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    isSearchFieldFocused = false
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFieldFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var emptyStateView: some View {
        Group {
            if searchText.isEmpty {
                Text("No tags found in catalog items")
                    .foregroundColor(.secondary)
            } else {
                Text("No tags match '\(searchText)'")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func tagRow(for tag: String, itemCount: Int) -> some View {
        Button(action: {
            toggleTag(tag)
        }) {
            HStack {
                Image(systemName: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedTags.contains(tag) ? .blue : .secondary)
                    .font(.system(size: 20))
                
                Text(tag)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Text("\(itemCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .contentShape(Rectangle()) // Make entire row tappable
        }
        .buttonStyle(.plain)
    }
    
    private func selectedTagRow(for tag: String) -> some View {
        HStack {
            Text(tag)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
            
            Spacer()
            
            Button("Remove") {
                selectedTags.remove(tag)
            }
            .font(.caption)
            .foregroundColor(.red)
        }
    }
    
    // MARK: - Actions
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
}

// MARK: - Convenience Views

/// Drop-in replacement for SearchableTagsView
struct SearchableTagsView: View {
    let allAvailableTags: [String]
    @Binding var selectedTags: Set<String>
    let catalogItems: FetchedResults<CatalogItem>
    @Binding var isPresented: Bool
    
    var body: some View {
        TagFilterView(
            allAvailableTags: allAvailableTags,
            selectedTags: $selectedTags,
            catalogItems: catalogItems,
            configuration: .searchable {
                isPresented = false
            }
        )
    }
}

/// Drop-in replacement for CatalogAllTagsView
struct CatalogAllTagsView: View {
    let allAvailableTags: [String]
    let catalogItems: FetchedResults<CatalogItem>
    @Binding var selectedTags: Set<String>
    @Binding var isPresented: Bool
    
    var body: some View {
        TagFilterView(
            allAvailableTags: allAvailableTags,
            selectedTags: $selectedTags,
            catalogItems: catalogItems,
            configuration: .allTags {
                isPresented = false
            }
        )
    }
}

/// Drop-in replacement for CatalogTagsView
struct CatalogTagsView: View {
    let allAvailableTags: [String]
    @Binding var selectedTags: Set<String>
    let catalogItems: FetchedResults<CatalogItem>
    @Binding var showingAllTags: Bool
    
    var body: some View {
        TagFilterView(
            allAvailableTags: allAvailableTags,
            selectedTags: $selectedTags,
            catalogItems: catalogItems,
            configuration: .allTags {
                showingAllTags = false
            }
        )
    }
}

/*
#Preview("Searchable Tags") {
    @Previewable @State var selectedTags: Set<String> = ["transparent", "clear"]
    @Previewable @State var isPresented = true
    
    let sampleTags = ["transparent", "clear", "opaque", "white", "colorful", "matte", "metallic", "reactive", "borosilicate", "soft glass", "dichroic", "silver fuming", "reduction", "striking"]
    let persistenceController = PersistenceController.preview
    
    struct PreviewWrapper: View {
        @FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)],
            animation: .default
        )
        private var catalogItems: FetchedResults<CatalogItem>
        
        @Binding var selectedTags: Set<String>
        @Binding var isPresented: Bool
        let allAvailableTags: [String]
        
        var body: some View {
            SearchableTagsView(
                allAvailableTags: allAvailableTags,
                selectedTags: $selectedTags,
                catalogItems: catalogItems,
                isPresented: $isPresented
            )
        }
    }
    
    PreviewWrapper(
        selectedTags: $selectedTags,
        isPresented: $isPresented,
        allAvailableTags: sampleTags
    )
    .environment(\.managedObjectContext, persistenceController.container.viewContext)
}

#Preview("All Tags") {
    @Previewable @State var selectedTags: Set<String> = ["transparent"]
    @Previewable @State var isPresented = true
    
    let sampleTags = ["transparent", "opaque", "metallic", "reactive", "clear", "matte"]
    let persistenceController = PersistenceController.preview
    
    struct PreviewWrapper: View {
        @FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)],
            animation: .default
        )
        private var catalogItems: FetchedResults<CatalogItem>
        
        @Binding var selectedTags: Set<String>
        @Binding var isPresented: Bool
        let allAvailableTags: [String]
        
        var body: some View {
            CatalogAllTagsView(
                allAvailableTags: allAvailableTags,
                catalogItems: catalogItems,
                selectedTags: $selectedTags,
                isPresented: $isPresented
            )
        }
    }
    
    PreviewWrapper(
        selectedTags: $selectedTags,
        isPresented: $isPresented,
        allAvailableTags: sampleTags
    )
    .environment(\.managedObjectContext, persistenceController.container.viewContext)
}
*/