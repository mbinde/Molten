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
    private let technicalTags: Set<String> = [
        "amber-purple", "cfl", "uv", "luster", "reducing", "reduction",
        "silver", "sparkle", "sparkles", "striker", "striking",
        "seeded", "reactive", "cadmium", "copper", "chrome"
    ]

    // Known color tags in rainbow order
    private let colorTags: [String] = [
        // Rainbow colors
        "red", "orange", "yellow", "green", "blue", "purple", "pink",
        "teal", "aqua", "turquoise", "lavender", "magenta",
        // Neutrals in specific order
        "clear", "white", "cream", "brown", "gray", "grey", "black"
    ]

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
    private var userFilteredTags: [String] {
        filteredTags.filter { tag in
            let lowercased = tag.lowercased()
            return !technicalTags.contains(lowercased) && !colorTags.contains(lowercased)
        }.sorted()
    }

    private var technicalFilteredTags: [String] {
        // Keep technical tags in the order specified
        let techOrder: [String] = [
            "amber-purple", "cfl", "uv", "luster", "reducing", "reduction",
            "silver", "sparkle", "sparkles", "striker", "striking",
            "seeded", "reactive", "cadmium", "copper", "chrome"
        ]
        return techOrder.filter { techTag in
            filteredTags.contains { $0.lowercased() == techTag }
        }
    }

    private var colorFilteredTags: [String] {
        let filteredColorSet = Set(filteredTags.map { $0.lowercased() })
        return colorTags.filter { filteredColorSet.contains($0) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Tags list with categorization
                List {
                    // User tags section (custom tags)
                    if !userFilteredTags.isEmpty && UserSettings.shared.showUserTagsInFilter {
                        Section("User Tags (\(userFilteredTags.count))") {
                            ForEach(userFilteredTags, id: \.self) { tag in
                                let itemsWithTag = catalogItems.filter { item in
                                    item.tags.contains(tag)
                                }

                                tagRow(for: tag, itemCount: itemsWithTag.count)
                            }
                        }
                    }

                    // Technical tags section
                    if !technicalFilteredTags.isEmpty && UserSettings.shared.showTechnicalTagsInFilter {
                        Section("Technical (\(technicalFilteredTags.count))") {
                            ForEach(technicalFilteredTags, id: \.self) { tag in
                                let itemsWithTag = catalogItems.filter { item in
                                    item.tags.contains(tag)
                                }

                                tagRow(for: tag, itemCount: itemsWithTag.count)
                            }
                        }
                    }

                    // Colors section (rainbow order)
                    if !colorFilteredTags.isEmpty {
                        Section("Colors (\(colorFilteredTags.count))") {
                            ForEach(colorFilteredTags, id: \.self) { tag in
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
                .font(.body)
            
            TextField("Search tags...", text: $localSearchText)
                .focused($isSearchFieldFocused)
                #if os(iOS)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
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
                        .font(.body)
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
                    .font(.title3)

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
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(Color.accentColor)
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
        case "SPARKLES", "SPARKLE":
            return "sparkles"
        case "STREAMER":
            return "waveform"
        case "STRIKER", "STRIKING":
            return "flame"
        case "SILVER":
            return "moon.stars"
        case "COPPER":
            return "atom"
        case "REDUCTION", "REDUCING":
            return "flame"
        case "LUSTER":
            return "diamond"
        case "AMBER-PURPLE":
            return "circle.hexagongrid"
        case "SEEDED":
            return "circle.dotted"
        case "REACTIVE":
            return "bolt"
        case "CADMIUM":
            return "exclamationmark.triangle"
        case "CHROME":
            return "atom"
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
        case "SPARKLES", "SPARKLE":
            return "sparkles"  // sparkles doesn't have a .fill variant
        case "STREAMER":
            return "waveform"  // waveform doesn't have a .fill variant
        case "STRIKER", "STRIKING":
            return "flame.fill"
        case "SILVER":
            return "moon.stars.fill"
        case "COPPER":
            return "atom"  // no .fill variant
        case "REDUCTION", "REDUCING":
            return "flame.fill"
        case "LUSTER":
            return "diamond.fill"
        case "AMBER-PURPLE":
            return "circle.hexagongrid.fill"
        case "SEEDED":
            return "circle.dotted"  // no .fill variant
        case "REACTIVE":
            return "bolt.fill"
        case "CADMIUM":
            return "exclamationmark.triangle.fill"
        case "CHROME":
            return "atom"  // no .fill variant
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