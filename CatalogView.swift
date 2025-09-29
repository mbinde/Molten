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
    
    // Filtered items based on search text and selected tags
    private var filteredItems: [CatalogItem] {
        var items = Array(catalogItems)
        
        // Apply text search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                (item.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (item.code?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (item.manufacturer?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (CatalogItemHelpers.tagsForItem(item).localizedCaseInsensitiveContains(searchText)) ||
                (!CatalogItemHelpers.synonymsForItem(item).isEmpty && CatalogItemHelpers.synonymsForItem(item).localizedCaseInsensitiveContains(searchText)) ||
                (CatalogItemHelpers.coeForItem(item).localizedCaseInsensitiveContains(searchText))
            }
        }
        
        // Apply tag filter
        if !selectedTags.isEmpty {
            items = items.filter { item in
                let itemTags = Set(CatalogItemHelpers.tagsArrayForItem(item))
                return !selectedTags.isDisjoint(with: itemTags) // Item has at least one of the selected tags
            }
        }
        
        return items
    }
    
    // All available tags from catalog items
    private var allAvailableTags: [String] {
        let allTags = catalogItems.flatMap { item in
            CatalogItemHelpers.tagsArrayForItem(item)
        }
        return Array(Set(allTags)).sorted()
    }
    
    // Grouped items by manufacturer
    private var groupedItems: [(String, [CatalogItem])] {
        let grouped = Dictionary(grouping: filteredItems) { item in
            item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
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
            CatalogBundleDebugView(bundleContents: $bundleContents)
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

// MARK: - CatalogView Actions
extension CatalogView {
    
    private func deleteItemsFromSection(items: [CatalogItem], offsets: IndexSet) {
        withAnimation {
            offsets.forEach { index in
                if index < items.count {
                    viewContext.delete(items[index])
                }
            }
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("❌ Error deleting items from section: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    @ViewBuilder
    private func manufacturerSectionHeader(_ manufacturer: String, count: Int) -> some View {
        HStack {
            Circle()
                .fill(CatalogItemHelpers.colorForManufacturer(manufacturer))
                .frame(width: 8, height: 8)
            Text(manufacturer)
                .fontWeight(.medium)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
    
    private func loadJSONData() {
        guard !isLoadingData else {
            print("⚠️ Already loading data, skipping request")
            return
        }
        
        Task {
            await MainActor.run { isLoadingData = true }
            do {
                try await DataLoadingService.shared.loadCatalogItemsFromJSON(into: viewContext)
                await MainActor.run {
                    print("✅ JSON loading completed successfully")
                    isLoadingData = false
                }
            } catch {
                await MainActor.run {
                    print("❌ JSON loading failed: \(error)")
                    isLoadingData = false
                }
            }
        }
    }
    
    private func smartMergeJSONData() {
        guard !isLoadingData else {
            print("⚠️ Already loading data, skipping smart merge request")
            return
        }
        
        Task {
            await MainActor.run { isLoadingData = true }
            do {
                try await DataLoadingService.shared.loadCatalogItemsFromJSONWithMerge(into: viewContext)
                await MainActor.run {
                    print("✅ Smart merge completed successfully")
                    isLoadingData = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Smart merge failed: \(error)")
                    isLoadingData = false
                }
            }
        }
    }
    
    private func loadJSONIfEmpty() {
        guard !isLoadingData else {
            print("⚠️ Already loading data, skipping conditional load request")
            return
        }
        
        Task {
            await MainActor.run { isLoadingData = true }
            do {
                try await DataLoadingService.shared.loadCatalogItemsFromJSONIfEmpty(into: viewContext)
                await MainActor.run {
                    print("✅ Conditional JSON loading completed")
                    isLoadingData = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Conditional JSON loading failed: \(error)")
                    isLoadingData = false
                }
            }
        }
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


// MARK: - Preview
#Preview {
    CatalogView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
