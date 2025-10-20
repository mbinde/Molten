//
//  TagFilterView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isAdvancedFilteringEnabled = false

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
    let catalogItems: [CatalogItemModel]
    let configuration: TagFilterConfiguration

    @State private var searchText = ""
    @State private var localSearchText = ""  // Local copy for immediate UI updates
    @FocusState private var isSearchFieldFocused: Bool
    
    // Technical tags that describe glass properties/effects (not colors)
    private let technicalTags: Set<String> = ["uv", "cfl", "sparkles", "streamer", "striker", "silver", "copper", "reduction", "luster"]

    // Filtered tags based on search text
    private var filteredTags: [String] {
        if localSearchText.isEmpty {
            return allAvailableTags
        } else {
            return allAvailableTags.filter { tag in
                tag.localizedCaseInsensitiveContains(localSearchText)
            }
        }
    }

    // Categorized tags for grouped display
    private var technicalFilteredTags: [String] {
        filteredTags.filter { technicalTags.contains($0.lowercased()) }.sorted()
    }

    private var colorAndMiscFilteredTags: [String] {
        filteredTags.filter { !technicalTags.contains($0.lowercased()) }.sorted()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Tags list with categorization
                List {
                    // Technical tags section
                    if !technicalFilteredTags.isEmpty {
                        Section("Technical (\(technicalFilteredTags.count))") {
                            ForEach(technicalFilteredTags, id: \.self) { tag in
                                let itemsWithTag = catalogItems.filter { item in
                                    item.tags.contains(tag)
                                }

                                tagRow(for: tag, itemCount: itemsWithTag.count)
                            }
                        }
                    }

                    // Colors & Misc tags section
                    if !colorAndMiscFilteredTags.isEmpty {
                        Section("Colors & Misc (\(colorAndMiscFilteredTags.count))") {
                            ForEach(colorAndMiscFilteredTags, id: \.self) { tag in
                                let itemsWithTag = catalogItems.filter { item in
                                    item.tags.contains(tag)
                                }

                                tagRow(for: tag, itemCount: itemsWithTag.count)
                            }
                        }
                    }

                    // Empty state
                    if filteredTags.isEmpty {
                        Section {
                            emptyStateView
                        }
                    }

                    // Selected tags section
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
            
            TextField("Search tags...", text: $localSearchText)
                .focused($isSearchFieldFocused)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .onSubmit {
                    isSearchFieldFocused = false
                }
                .onChange(of: localSearchText) { oldValue, newValue in
                    // Debounce search text updates (200ms delay)
                    Task {
                        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                        if localSearchText == newValue {
                            searchText = newValue
                        }
                    }
                }

            if !localSearchText.isEmpty {
                Button {
                    localSearchText = ""
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
        .background(DesignSystem.Colors.backgroundInput)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(DesignSystem.Colors.background)
    }
    
    private var emptyStateView: some View {
        Group {
            if localSearchText.isEmpty {
                Text("No tags found in catalog items")
                    .foregroundColor(.secondary)
            } else {
                Text("No tags match '\(localSearchText)'")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func tagRow(for tag: String, itemCount: Int) -> some View {
        Button(action: {
            toggleTag(tag)
        }) {
            HStack {
                Image(systemName: selectedTags.contains(tag) ? tagIconFilled(for: tag) : tagIcon(for: tag))
                    .foregroundColor(selectedTags.contains(tag) ? .blue : .secondary)
                    .font(.system(size: 20))

                TagColorCircle(tag: tag, size: 12)

                Text(tag)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                Text("\(itemCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.backgroundInput)
                    .clipShape(Capsule())
            }
            .contentShape(Rectangle()) // Make entire row tappable
        }
        .buttonStyle(.plain)
    }
    
    private func selectedTagRow(for tag: String) -> some View {
        HStack {
            HStack(spacing: 6) {
                TagColorCircle(tag: tag, size: 10)

                Text(tag)
            }
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

    // MARK: - Tag Icon Helpers

    /// Returns the unfilled icon for a tag
    private func tagIcon(for tag: String) -> String {
        switch tag.uppercased() {
        case "UV":
            return "sun.max"
        case "CFL":
            return "lightbulb"
        case "SPARKLES":
            return "sparkles"
        case "STREAMER":
            return "waveform"
        case "STRIKER":
            return "flame"
        case "SILVER":
            return "moon.stars"
        case "COPPER":
            return "dot.radiowaves.left.and.right"
        case "REDUCTION":
            return "flame"
        case "LUSTER":
            return "diamond"
        default:
            return "circle"
        }
    }

    /// Returns the filled icon for a tag
    private func tagIconFilled(for tag: String) -> String {
        switch tag.uppercased() {
        case "UV":
            return "sun.max.fill"
        case "CFL":
            return "lightbulb.fill"
        case "SPARKLES":
            return "sparkles"  // sparkles doesn't have a .fill variant
        case "STREAMER":
            return "waveform"  // waveform doesn't have a .fill variant
        case "STRIKER":
            return "flame.fill"
        case "SILVER":
            return "moon.stars.fill"
        case "COPPER":
            return "dot.radiowaves.left.and.right"  // no .fill variant
        case "REDUCTION":
            return "flame.fill"
        case "LUSTER":
            return "diamond.fill"
        default:
            return "checkmark.circle.fill"
        }
    }

}

// MARK: - Convenience Views

/// Drop-in replacement for SearchableTagsView
struct SearchableTagsView: View {
    let allAvailableTags: [String]
    @Binding var selectedTags: Set<String>
    let catalogItems: [CatalogItemModel]
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
    let catalogItems: [CatalogItemModel]
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
    let catalogItems: [CatalogItemModel]
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
    
    // Sample catalog items for preview
    let sampleCatalogItems: [CatalogItemModel] = [
        CatalogItemModel(name: "Clear Rod", code: "CLR-001", manufacturer: "Bullseye", tags: ["transparent", "clear"]),
        CatalogItemModel(name: "White Opaque", code: "WH-002", manufacturer: "Spectrum", tags: ["opaque", "white"]),
        CatalogItemModel(name: "Metallic Silver", code: "MT-003", manufacturer: "Uroboros", tags: ["metallic", "silver fuming"])
    ]
    
    SearchableTagsView(
        allAvailableTags: sampleTags,
        selectedTags: $selectedTags,
        catalogItems: sampleCatalogItems,
        isPresented: $isPresented
    )
}

#Preview("All Tags") {
    @Previewable @State var selectedTags: Set<String> = ["transparent"]
    @Previewable @State var isPresented = true
    
    let sampleTags = ["transparent", "opaque", "metallic", "reactive", "clear", "matte"]
    
    // Sample catalog items for preview
    let sampleCatalogItems: [CatalogItemModel] = [
        CatalogItemModel(name: "Clear Rod", code: "CLR-001", manufacturer: "Bullseye", tags: ["transparent", "clear"]),
        CatalogItemModel(name: "White Opaque", code: "WH-002", manufacturer: "Spectrum", tags: ["opaque", "white"]),
        CatalogItemModel(name: "Metallic Silver", code: "MT-003", manufacturer: "Uroboros", tags: ["metallic", "reactive"])
    ]
    
    CatalogAllTagsView(
        allAvailableTags: sampleTags,
        catalogItems: sampleCatalogItems,
        selectedTags: $selectedTags,
        isPresented: $isPresented
    )
}
        
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
*/