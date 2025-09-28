//
//  ContentView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
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
                (tagsForItem(item).localizedCaseInsensitiveContains(searchText)) ||
                (!synonymsForItem(item).isEmpty && synonymsForItem(item).localizedCaseInsensitiveContains(searchText)) ||
                (coeForItem(item).localizedCaseInsensitiveContains(searchText))
            }
        }
        
        // Apply tag filter
        if !selectedTags.isEmpty {
            items = items.filter { item in
                let itemTags = Set(tagsArrayForItem(item))
                return !selectedTags.isDisjoint(with: itemTags) // Item has at least one of the selected tags
            }
        }
        
        return items
    }
    
    // All available tags from catalog items
    private var allAvailableTags: [String] {
        let allTags = catalogItems.flatMap { item in
            tagsArrayForItem(item)
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
    
    // Color scheme for manufacturers
    private func colorForManufacturer(_ manufacturer: String?) -> Color {
        let cleanManufacturer = manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "unknown"
        
        switch cleanManufacturer {
        case "effetre", "moretti":
            return .blue
        case "vetrofond":
            return .green
        case "reichenbach":
            return .purple
        case "double helix":
            return .orange
        case "northstar":
            return .red
        case "glass alchemy":
            return .mint
        case "zimmermann":
            return .yellow
        case "kugler":
            return .pink
        case "unknown":
            return .secondary
        default:
            // Generate a consistent color based on manufacturer name
            let hash = cleanManufacturer.hash
            let colors: [Color] = [.cyan, .indigo, .teal, .brown, .gray]
            return colors[abs(hash) % colors.count]
        }
    }
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case code = "Code"
        case manufacturer = "Manufacturer"
        case startDate = "Start Date"
        
        var keyPath: KeyPath<CatalogItem, String?> {
            switch self {
            case .name: return \CatalogItem.name
            case .code: return \CatalogItem.code
            case .manufacturer: return \CatalogItem.manufacturer
            case .startDate: return \CatalogItem.name // We'll handle date sorting differently
            }
        }
        
        var nsSortDescriptor: NSSortDescriptor {
            switch self {
            case .name:
                return NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)
            case .code:
                return NSSortDescriptor(keyPath: \CatalogItem.code, ascending: true)
            case .manufacturer:
                return NSSortDescriptor(keyPath: \CatalogItem.manufacturer, ascending: true)
            case .startDate:
                return NSSortDescriptor(keyPath: \CatalogItem.start_date, ascending: false)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Debug information
                if catalogItems.isEmpty {
                    Text("No catalog items found")
                        .foregroundColor(.secondary)
                        .onAppear {
                            print("🐛 ContentView: No catalog items in fetch results")
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
                        print("🐛 ContentView: Displaying \(totalItems) total items, \(filteredCount) filtered")
                    }
                }
                
                // Tag Filter Section
                if !allAvailableTags.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Filter by Tags")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                Spacer()
                                if !selectedTags.isEmpty {
                                    Button("Clear") {
                                        selectedTags.removeAll()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                                Button("All Tags") {
                                    showingAllTags = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            
                            // Show selected tags
                            if !selectedTags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                                            HStack(spacing: 4) {
                                                Text(tag)
                                                    .font(.caption)
                                                Button("×") {
                                                    selectedTags.remove(tag)
                                                }
                                                .font(.caption)
                                                .foregroundColor(.red)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.2))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 1)
                                }
                            }
                            
                            // Show first few available tags for quick selection
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(allAvailableTags.prefix(10), id: \.self) { tag in
                                        Button(tag) {
                                            if selectedTags.contains(tag) {
                                                selectedTags.remove(tag)
                                            } else {
                                                selectedTags.insert(tag)
                                            }
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(selectedTags.contains(tag) ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                        .foregroundColor(selectedTags.contains(tag) ? .blue : .secondary)
                                        .clipShape(Capsule())
                                    }
                                    
                                    if allAvailableTags.count > 10 {
                                        Button("More...") {
                                            showingAllTags = true
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.1))
                                        .foregroundColor(.secondary)
                                        .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Sections by manufacturer
                ForEach(groupedItems, id: \.0) { manufacturer, items in
                    Section(header: manufacturerSectionHeader(manufacturer, count: items.count)) {
                        ForEach(items) { item in
                            NavigationLink {
                                detailView(for: item)
                            } label: {
                                catalogItemRow(for: item)
                            }
                        }
                        .onDelete { indexSet in
                            deleteItemsFromSection(items: items, offsets: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("Flameworker Catalog")
            .searchable(text: $searchText, prompt: "Search colors, codes, manufacturers, tags, or synonyms...")
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
#if os(iOS)
                    EditButton()
#endif
                    Menu {
                        Picker("Sort by", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Label(option.rawValue, systemImage: sortIcon(for: option))
                                    .tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                    
                    Button("Tags") {
                        showingAllTags = true
                    }
                    
                    Button("Refresh") {
                        refreshData()
                    }
                    Button("Debug") {
                        debugBundleContents()
                        showingBundleDebug = true
                    }
                    Button("Inspect JSON") {
                        inspectJSONStructure()
                    }
                    Menu("Load Data") {
                        Button("Load JSON (Clear & Reload)") {
                            loadJSONData()
                        }
                        Button("Smart Merge JSON") {
                            smartMergeJSONData()
                        }
                        Button("Load Only If Empty") {
                            loadJSONIfEmpty()
                        }
                    }
                    Button("Reset", role: .destructive) {
                        showingDeleteAlert = true
                    }
                    Button(action: addItem) {
                        Label("Add", systemImage: "plus")
                    }
                }
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
            bundleDebugView()
        }
        .sheet(isPresented: $showingAllTags) {
            allTagsView()
        }
    }
    
    // MARK: - Tags Helper Functions
    
    private func tagsForItem(_ item: CatalogItem) -> String {
        // Get tags from Core Data - they're stored as comma-separated string
        if let tagsString = item.value(forKey: "tags") as? String {
            return tagsString
        }
        return ""
    }
    
    private func tagsArrayForItem(_ item: CatalogItem) -> [String] {
        let tagsString = tagsForItem(item)
        if tagsString.isEmpty {
            return []
        }
        return tagsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    // MARK: - Synonyms Helper Functions
    
    private func synonymsForItem(_ item: CatalogItem) -> String {
        // Get synonyms from Core Data - they're stored as comma-separated string
        // Handle case where synonyms attribute might not exist in the model
        do {
            if let synonymsString = item.value(forKey: "synonyms") as? String {
                return synonymsString
            }
        } catch {
            // Synonyms attribute doesn't exist in Core Data model
            return ""
        }
        return ""
    }
    
    private func synonymsArrayForItem(_ item: CatalogItem) -> [String] {
        let synonymsString = synonymsForItem(item)
        if synonymsString.isEmpty {
            return []
        }
        return synonymsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    // MARK: - COE Helper Functions
    
    private func coeForItem(_ item: CatalogItem) -> String {
        // Get COE from Core Data
        // Handle case where coe attribute might not exist in the model
        do {
            if let coeString = item.value(forKey: "coe") as? String {
                return coeString
            }
        } catch {
            // COE attribute doesn't exist in Core Data model
            return ""
        }
        return ""
    }
    
    // MARK: - Additional Helper Functions
    
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
    
    private func sortIcon(for option: SortOption) -> String {
        switch option {
        case .name:
            return "textformat.abc"
        case .code:
            return "number"
        case .manufacturer:
            return "building.2"
        case .startDate:
            return "calendar"
        }
    }
    
    @ViewBuilder
    private func catalogItemRow(for item: CatalogItem) -> some View {
        HStack {
            Circle()
                .fill(colorForManufacturer(item.manufacturer))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "Unknown")
                    .fontWeight(.medium)
                
                HStack {
                    Text(item.code ?? "N/A")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    // Show COE if available
                    if let coe = item.value(forKey: "coe") as? String, !coe.isEmpty {
                        Text("COE \(coe)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    Text(item.manufacturer ?? "Unknown")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Display image path if available
                if let imagePath = item.value(forKey: "image_path") as? String, !imagePath.isEmpty {
                    Text("📷 \(imagePath)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                // Display tags if available
                let tags = tagsArrayForItem(item)
                if !tags.isEmpty {
                    HStack {
                        ForEach(tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                        if tags.count > 3 {
                            Text("+\(tags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                
                // Display synonyms if available
                let synonyms = synonymsArrayForItem(item)
                if !synonyms.isEmpty {
                    HStack {
                        ForEach(synonyms.prefix(2), id: \.self) { synonym in
                            Text(synonym)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                        if synonyms.count > 2 {
                            Text("+\(synonyms.count - 2)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func manufacturerSectionHeader(_ manufacturer: String, count: Int) -> some View {
        HStack {
            Circle()
                .fill(colorForManufacturer(manufacturer))
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
    
    @ViewBuilder
    private func allTagsView() -> some View {
        NavigationStack {
            List {
                Section("All Available Tags (\(allAvailableTags.count))") {
                    if allAvailableTags.isEmpty {
                        Text("No tags found in catalog items")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(allAvailableTags, id: \.self) { tag in
                            let itemsWithTag = catalogItems.filter { item in
                                tagsArrayForItem(item).contains(tag)
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
            .navigationTitle("Tag Filter")
            .toolbar {
                ToolbarItem {
                    Button("Done") {
                        showingAllTags = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func bundleDebugView() -> some View {
        NavigationStack {
            List {
                Section("Bundle Information") {
                    if let bundlePath = Bundle.main.resourcePath {
                        Text("Bundle Path:")
                            .fontWeight(.medium)
                        Text(bundlePath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("All Files (\(bundleContents.count))") {
                    ForEach(bundleContents.sorted(), id: \.self) { file in
                        HStack {
                            Image(systemName: file.hasSuffix(".json") ? "doc.text" : "doc")
                                .foregroundColor(file.hasSuffix(".json") ? .blue : .secondary)
                            Text(file)
                            Spacer()
                            if file.hasSuffix(".json") {
                                Text("JSON")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                Section("JSON Files") {
                    let jsonFiles = bundleContents.filter { $0.hasSuffix(".json") }
                    if jsonFiles.isEmpty {
                        Text("No JSON files found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(jsonFiles, id: \.self) { file in
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                Text(file)
                                Spacer()
                                if file == "colors.json" {
                                    Text("TARGET FILE")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bundle Contents")
            .toolbar {
                ToolbarItem {
                    Button("Done") {
                        showingBundleDebug = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func detailView(for item: CatalogItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name ?? "Unknown")
                .font(.title2)
                .fontWeight(.bold)
            Text("Code: \(item.code ?? "N/A")")
                .foregroundColor(.secondary)
            Text("Manufacturer: \(item.manufacturer ?? "N/A")")
                .foregroundColor(.secondary)
            
            // Display COE if available
            if let coe = item.value(forKey: "coe") as? String, !coe.isEmpty {
                Text("COE: \(coe)")
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }
            if let startDate = item.start_date {
                Text("Available from: \(startDate, formatter: itemFormatter)")
                    .foregroundColor(.secondary)
            }
            
            // Display image path if available
            if let imagePath = item.value(forKey: "image_path") as? String, !imagePath.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image:")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text(imagePath)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            // Display tags
            let tags = tagsArrayForItem(item)
            if !tags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tags:")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            // Display synonyms
            let synonyms = synonymsArrayForItem(item)
            if !synonyms.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Synonyms:")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(synonyms, id: \.self) { synonym in
                            Text(synonym)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Item Details")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
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

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { catalogItems[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting items: \(nsError), \(nsError.userInfo)")
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

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

private let yearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy"
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
