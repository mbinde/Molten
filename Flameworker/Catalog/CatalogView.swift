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
    @State private var searchText = ""
    @State private var sortOption: SortOption = .name
    @State private var showingSortMenu = false
    @State private var selectedTags: Set<String> = []
    @State private var showingAllTags = false
    @State private var isLoadingData = false
    @State private var bundleContents: [String] = []
    
    // Read enabled manufacturers from settings
    @AppStorage("enabledManufacturers") private var enabledManufacturersData: Data = Data()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)],
        animation: .default
    )
    private var catalogItems: FetchedResults<CatalogItem>
    
    // Get enabled manufacturers set from settings
    private var enabledManufacturers: Set<String> {
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: enabledManufacturersData) {
            return decoded
        }
        // If no settings saved, return all manufacturers (default behavior)
        let allManufacturers = catalogItems.compactMap { item in
            item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        return Set(allManufacturers)
    }
    
    // Filtered items based on search text, selected tags, and enabled manufacturers
    private var filteredItems: [CatalogItem] {
        var items = Array(catalogItems)
        
        // Apply manufacturer filter first using centralized utility
        items = FilterUtilities.filterCatalogByManufacturers(items, enabledManufacturers: enabledManufacturers)
        
        // Apply text search filter using centralized utility
        items = SearchUtilities.searchCatalogItems(items, query: searchText)
        
        // Apply tag filter using centralized utility
        items = FilterUtilities.filterCatalogByTags(items, selectedTags: selectedTags)
        
        return items
    }
    
    // Sorted filtered items for the unified list using centralized utility
    private var sortedFilteredItems: [CatalogItem] {
        return SortUtilities.sortCatalog(filteredItems, by: catalogSortCriteria)
    }
    
    // Convert our SortOption to the new CatalogSortCriteria
    private var catalogSortCriteria: CatalogSortCriteria {
        switch sortOption {
        case .name:
            return .name
        case .manufacturer:
            return .manufacturer
        case .code:
            return .code
        case .startDate:
            return .startDate
        }
    }
    
    // All available tags from catalog items (only from enabled manufacturers)
    private var allAvailableTags: [String] {
        let allTags = filteredItems.flatMap { item in
            CatalogItemHelpers.tagsArrayForItem(item)
        }
        return Array(Set(allTags)).sorted()
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if catalogItems.isEmpty {
                    catalogEmptyState
                } else if filteredItems.isEmpty && !searchText.isEmpty {
                    searchEmptyStateView
                } else {
                    catalogListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        Text("Catalog")
                            .font(.headline)
                            .fontWeight(.bold)
                            .fixedSize()
                        
                        // Tag filter button right after the title
                        if !allAvailableTags.isEmpty {
                            Button {
                                showingAllTags = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "tag")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("Tags")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(selectedTags.isEmpty ? .primary : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedTags.isEmpty ? Color.clear : Color.blue
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                // Custom search bar with inline sort button
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search colors, codes, manufacturers...", text: $searchText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    Button {
                        showingSortMenu = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .confirmationDialog("Sort Options", isPresented: $showingSortMenu) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(option.rawValue) {
                        sortOption = option
                        updateSorting(option)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingAllTags) {
                TagFilterView(
                    availableTags: allAvailableTags,
                    selectedTags: $selectedTags
                )
            }
        }
    }
    
    // MARK: - Views
    
    private var catalogEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "eyedropper.halffull")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Catalog Items")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start building your glass color catalog by loading catalog data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var searchEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("No catalog items match '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var catalogListView: some View {
        List {
            // All items in one list
            ForEach(sortedFilteredItems) { item in
                NavigationLink {
                    CatalogItemDetailView(item: item)
                } label: {
                    CatalogItemRowView(item: item)
                }
            }
            .onDelete(perform: deleteItems)
        }
    }
}

// MARK: - CatalogView Actions
extension CatalogView {
    
    private func deleteItems(offsets: IndexSet) {
        CoreDataOperations.deleteItems(sortedFilteredItems, at: offsets, in: viewContext)
    }
    
    private func deleteItemsFromSection(items: [CatalogItem], offsets: IndexSet) {
        CoreDataOperations.deleteItems(items, at: offsets, in: viewContext)
    }
    
    private func updateSorting(_ sortOption: SortOption) {
        // Update the fetch request's sort descriptors
        catalogItems.nsSortDescriptors = [sortOption.nsSortDescriptor]
    }
    
    private func refreshData() {
        let request: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        do {
            let items = try viewContext.fetch(request)
            print("🔄 Manual refresh: Found \(items.count) catalog items in Core Data")
            for (index, item) in items.enumerated() {
                if index < 5 { // Show first 5 items
                    print("   Item \(index + 1): \(item.name ?? "No name") (\(item.code ?? "No code"))")
                }
            }
            if items.count > 5 {
                print("   ... and \(items.count - 5) more items")
            }
        } catch {
            print("❌ Error fetching catalog items: \(error)")
        }
    }

    private func addItem() {
        withAnimation {
            let newCatalogItem = CatalogItem(context: viewContext)
            newCatalogItem.code = "NEW-\(Int(Date().timeIntervalSince1970))"
            newCatalogItem.name = "New Item"
            newCatalogItem.manufacturer = "Unknown"
            newCatalogItem.start_date = Date()
            
            // Set default image_path if the attribute exists
            let entityDescription = newCatalogItem.entity
            if entityDescription.attributesByName["image_path"] != nil {
                newCatalogItem.setValue("", forKey: "image_path") // Empty string as default
            }

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error saving new item: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteAllItems() {
        withAnimation {
            // Delete all catalog items
            catalogItems.forEach { item in
                viewContext.delete(item)
            }
            
            do {
                try viewContext.save()
                print("🗑️ All catalog items deleted successfully")
            } catch {
                let nsError = error as NSError
                print("❌ Error deleting all items: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func debugBundleContents() {
        print("🔍 Debug: Checking bundle contents...")
        guard let bundlePath = Bundle.main.resourcePath else {
            print("❌ Could not get bundle resource path")
            bundleContents = []
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
            bundleContents = contents
            print("📁 Bundle contents:")
            for item in contents.sorted() {
                print("   - \(item)")
            }
            
            // Check specifically for JSON files
            let jsonFiles = contents.filter { $0.hasSuffix(".json") }
            print("📄 JSON files found: \(jsonFiles)")
            
            // Try to find colors.json specifically
            if let url = Bundle.main.url(forResource: "colors", withExtension: "json") {
                print("✅ Found colors.json at: \(url)")
            } else {
                print("❌ Could not find colors.json in bundle")
            }
        } catch {
            print("❌ Error reading bundle contents: \(error)")
            bundleContents = []
        }
    }
    
    // MARK: - Data Loading Helpers
    
    private func loadJSONData() {
        AsyncOperationHandler.perform(
            operation: {
                try await DataLoadingService.shared.loadCatalogItemsFromJSON(into: viewContext)
            },
            operationName: "JSON loading",
            loadingState: $isLoadingData
        )
    }
    
    private func smartMergeJSONData() {
        AsyncOperationHandler.perform(
            operation: {
                try await DataLoadingService.shared.loadCatalogItemsFromJSONWithMerge(into: viewContext)
            },
            operationName: "Smart merge",
            loadingState: $isLoadingData
        )
    }
    
    private func loadJSONIfEmpty() {
        AsyncOperationHandler.perform(
            operation: {
                try await DataLoadingService.shared.loadCatalogItemsFromJSONIfEmpty(into: viewContext)
            },
            operationName: "Conditional JSON loading",
            loadingState: $isLoadingData
        )
    }
    
    private func inspectJSONStructure() {
        print("🔍 Inspecting JSON structure...")
        
        guard let url = Bundle.main.url(forResource: "colors", withExtension: "json") else {
            print("❌ Could not find colors.json")
            return
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("❌ Could not load colors.json")
            return
        }
        
        // Try standard JSON inspection
        do {
            // Try to parse as generic JSON to see the structure
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📄 Standard JSON is a Dictionary with keys:")
                for (key, value) in jsonObject.prefix(3) { // Show first 3 items
                    print("   Key: \(key)")
                    if let itemDict = value as? [String: Any] {
                        print("     Item fields:")
                        for (field, fieldValue) in itemDict {
                            let valueType = type(of: fieldValue)
                            print("       \(field): \(fieldValue) (Type: \(valueType))")
                        }
                    }
                    print()
                }
            } else if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("📄 Standard JSON is an Array with \(jsonArray.count) items")
                if let firstItem = jsonArray.first {
                    print("   First item fields:")
                    for (field, fieldValue) in firstItem {
                        let valueType = type(of: fieldValue)
                        print("     \(field): \(fieldValue) (Type: \(valueType))")
                    }
                }
            } else {
                print("❌ JSON structure is neither dictionary nor array")
                
                // Show raw content for debugging
                if let rawString = String(data: data, encoding: .utf8) {
                    print("📄 First 500 characters of raw file:")
                    print(String(rawString.prefix(500)))
                }
            }
        } catch {
            print("❌ Error parsing standard JSON: \(error)")
        }
    }
}

// MARK: - Tag Filter View
struct TagFilterView: View {
    let availableTags: [String]
    @Binding var selectedTags: Set<String>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(availableTags, id: \.self) { tag in
                    HStack {
                        Text(tag)
                        Spacer()
                        if selectedTags.contains(tag) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                }
            }
            .navigationTitle("Filter by Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        selectedTags.removeAll()
                    }
                    .disabled(selectedTags.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - Preview
#Preview {
    CatalogView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
