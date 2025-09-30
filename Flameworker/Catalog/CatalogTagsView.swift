//
//  CatalogTagsView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct CatalogTagsView: View {
    let allAvailableTags: [String]
    @Binding var selectedTags: Set<String>
    let catalogItems: FetchedResults<CatalogItem>
    @Binding var showingAllTags: Bool
    
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
                
                List {
                    Section("All Available Tags (\(filteredTags.count))") {
                        if filteredTags.isEmpty {
                            if searchText.isEmpty {
                                Text("No tags found in catalog items")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No tags match '\(searchText)'")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ForEach(filteredTags, id: \.self) { tag in
                                let itemsWithTag = catalogItems.filter { item in
                                    CatalogItemHelpers.tagsArrayForItem(item).contains(tag)
                                }
                                
                                HStack {
                                    Button(action: {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedTags.contains(tag) ? .blue : .secondary)
                                            
                                            Text(tag)
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            Text("\(itemsWithTag.count)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    
                    if !selectedTags.isEmpty {
                        Section("Active Filters") {
                            ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                                HStack {
                                    Text(tag)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
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
                            
                            Button("Clear All Filters") {
                                selectedTags.removeAll()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Tag Filter")
            .toolbar {
                ToolbarItem {
                    Button("Done") {
                        showingAllTags = false
                    }
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
}

/*
#Preview {
    @Previewable @State var selectedTags: Set<String> = ["clear", "transparent"]
    @Previewable @State var showingAllTags = true
    
    let sampleTags = ["transparent", "clear", "opaque", "white", "colorful", "matte"]
    let persistenceController = PersistenceController.preview
    
    // Create a wrapper view that provides FetchedResults
    struct PreviewWrapper: View {
        @FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)],
            animation: .default
        )
        private var catalogItems: FetchedResults<CatalogItem>
        
        @Binding var selectedTags: Set<String>
        @Binding var showingAllTags: Bool
        let allAvailableTags: [String]
        
        var body: some View {
            CatalogTagsView(
                allAvailableTags: allAvailableTags,
                selectedTags: $selectedTags,
                catalogItems: catalogItems,
                showingAllTags: $showingAllTags
            )
        }
    }
    
    PreviewWrapper(
        selectedTags: $selectedTags,
        showingAllTags: $showingAllTags,
        allAvailableTags: sampleTags
    )
    .environment(\.managedObjectContext, persistenceController.container.viewContext)
}
*/
