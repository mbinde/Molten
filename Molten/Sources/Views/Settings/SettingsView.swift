//
//  SettingsView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI

// MARK: - Manufacturer Filter Preference Management

/// Manages user preferences for manufacturer filtering
class ManufacturerFilterPreference {

    /// Storage key for UserDefaults
    nonisolated static let storageKey = "selectedManufacturerFilter"

    /// UserDefaults instance (can be overridden for testing)
    nonisolated(unsafe) private static var userDefaults: UserDefaults = .standard

    /// Selected manufacturers (multi-selection)
    nonisolated static var selectedManufacturers: Set<String> {
        if let data = userDefaults.data(forKey: storageKey),
           let manufacturers = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return manufacturers
        }

        // Default: all manufacturers selected
        return Set(GlassManufacturers.allCodes)
    }

    /// Add a manufacturer to the multi-selection
    nonisolated static func addManufacturer(_ manufacturer: String) {
        var current = selectedManufacturers
        current.insert(manufacturer)
        saveSelectedManufacturers(current)
        NotificationCenter.default.post(name: .manufacturerSelectionChanged, object: nil)
    }

    /// Remove a manufacturer from the multi-selection
    nonisolated static func removeManufacturer(_ manufacturer: String) {
        var current = selectedManufacturers
        current.remove(manufacturer)
        saveSelectedManufacturers(current)
        NotificationCenter.default.post(name: .manufacturerSelectionChanged, object: nil)
    }

    /// Set the complete multi-selection
    nonisolated static func setSelectedManufacturers(_ manufacturers: Set<String>) {
        saveSelectedManufacturers(manufacturers)
        NotificationCenter.default.post(name: .manufacturerSelectionChanged, object: nil)
    }

    /// Save selected manufacturers to UserDefaults
    nonisolated private static func saveSelectedManufacturers(_ manufacturers: Set<String>) {
        if let data = try? JSONEncoder().encode(manufacturers) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    /// Reset to default (all manufacturers selected)
    nonisolated static func resetToDefault() {
        userDefaults.removeObject(forKey: storageKey)
    }

    /// Set UserDefaults instance (for testing)
    nonisolated static func setUserDefaults(_ defaults: UserDefaults) {
        userDefaults = defaults
    }
}

// MARK: - Manufacturer Filter Helpers

/// Helpers for integrating manufacturer filter into SettingsView
struct ManufacturerFilterHelpers {
    
    /// Check if manufacturer filter section should be shown
    static func shouldShowManufacturerFilterSection() -> Bool {
        return true  // Always show manufacturer filter
    }
    
    /// Title for manufacturer filter section
    static let manufacturerFilterSectionTitle = "Manufacturer Filter"
    
    /// Footer text for manufacturer filter section
    static let manufacturerFilterSectionFooter = "Select which manufacturers to show in the catalog. This filter works alongside the COE filter to refine your search results."
}

// MARK: - Manufacturer Filter Service

/// Service for integrating manufacturer filtering throughout the app
class ManufacturerFilterService {

    static let shared = ManufacturerFilterService()

    nonisolated private init() {}

    /// Check if a specific manufacturer is enabled
    nonisolated func isManufacturerEnabled(_ manufacturer: String) -> Bool {
        return ManufacturerFilterPreference.selectedManufacturers.contains(manufacturer)
    }

    /// Get all currently enabled manufacturers
    nonisolated var enabledManufacturers: Set<String> {
        return ManufacturerFilterPreference.selectedManufacturers
    }

    /// Check if a catalog item should be shown based on manufacturer filter
    nonisolated func shouldShowItem(manufacturer: String?) -> Bool {
        guard let manufacturer = manufacturer else { return true }
        return isManufacturerEnabled(manufacturer)
    }
}

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isAdvancedFeaturesEnabled = false

struct SettingsView: View {
    @AppStorage("defaultSortOption") private var defaultSortOptionRawValue = SortOption.name.rawValue
    @AppStorage("defaultInventorySortOption") private var defaultInventorySortOptionRawValue = "Name"
    @AppStorage("defaultUnits") private var defaultUnitsRawValue = DefaultUnits.pounds.rawValue
    
    private let catalogService: CatalogService
    
    init(catalogService: CatalogService = RepositoryFactory.createCatalogService()) {
        self.catalogService = catalogService
    }
    
    private var defaultSortOptionBinding: Binding<SortOption> {
        Binding(
            get: { SortOption(rawValue: defaultSortOptionRawValue) ?? .name },
            set: { defaultSortOptionRawValue = $0.rawValue }
        )
    }
    
    private var defaultInventorySortOptionBinding: Binding<String> {
        Binding(
            get: { defaultInventorySortOptionRawValue },
            set: { defaultInventorySortOptionRawValue = $0 }
        )
    }
    
    private var defaultUnitsBinding: Binding<DefaultUnits> {
        Binding(
            get: { DefaultUnits(rawValue: defaultUnitsRawValue) ?? .pounds },
            set: { defaultUnitsRawValue = $0.rawValue }
        )
    }
    
    
    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Appearance", selection: Binding(
                        get: { UserSettings.shared.appearanceMode },
                        set: { UserSettings.shared.appearanceMode = $0 }
                    )) {
                        ForEach(UserSettings.AppearanceMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Interface") {
                    NavigationLink {
                        TabCustomizationView()
                    } label: {
                        Label("Customize Tabs", systemImage: "square.grid.2x2")
                    }
                }

                Section("Display") {
                    Toggle("Expand Manufacturer Descriptions by Default", isOn: Binding(
                        get: { UserSettings.shared.expandManufacturerDescriptionsByDefault },
                        set: { UserSettings.shared.expandManufacturerDescriptionsByDefault = $0 }
                    ))
                    .help("When enabled, manufacturer descriptions in item detail views will be fully expanded by default")

                    Toggle("Expand My Notes by Default", isOn: Binding(
                        get: { UserSettings.shared.expandUserNotesByDefault },
                        set: { UserSettings.shared.expandUserNotesByDefault = $0 }
                    ))
                    .help("When enabled, your personal notes in item detail views will be fully expanded by default")

                    HStack {
                        Picker("Default Catalog Sort Order", selection: defaultSortOptionBinding) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Picker("Default Inventory Sort Order", selection: defaultInventorySortOptionBinding) {
                            Text("Name").tag("Name")
                            Text("Inventory Count").tag("Inventory Count")
                            Text("Buy Count").tag("Buy Count")
                            Text("Sell Count").tag("Sell Count")
                        }
                        .pickerStyle(.menu)
                    }
 /*
                    HStack {
                        Picker("Default Units", selection: defaultUnitsBinding) {
                            ForEach(DefaultUnits.allCases, id: \.self) { unit in
                                Label(unit.displayName, systemImage: unit.systemImage).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                        .help("Default units for recording inventory")
                    }
 */
                }
                
                // REMOVED: Haptic feedback section - HapticService removed from project
                
                // Filtering section - navigate to separate views
                Section("Filtering") {
                    NavigationLink {
                        COEFilterView()
                    } label: {
                        Label("COE Filter", systemImage: "flame")
                    }

                    NavigationLink {
                        ManufacturerFilterView()
                    } label: {
                        Label("Manufacturer Filter", systemImage: "building.2")
                    }
                }

                // Author Profile section
                Section("Author Profile") {
                    NavigationLink {
                        AuthorSettingsView()
                    } label: {
                        Label("Author Information", systemImage: "person.circle")
                    }
                }

                // Terminology section
                Section("Terminology") {
                    NavigationLink {
                        TerminologySettingsView()
                    } label: {
                        Label("Glass Working Terminology", systemImage: "text.bubble")
                    }
                }

                // Advanced filtering settings - feature gated for release
                // Note: This legacy section is replaced by the new Manufacturer Filter section above
                /*
                if isAdvancedFeaturesEnabled {
                    // Legacy manufacturer filtering code removed
                }
                */
                
                Section("Debug") {
                    NavigationLink {
                        DebugSettingsView(catalogService: catalogService)
                    } label: {
                        Label("Debug Settings", systemImage: "ladybug")
                    }
                }
                
                Section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Data Management View
struct DataManagementView: View {
    @State private var isLoadingData = false
    @State private var showingDeleteAlert = false
    @State private var showingClearInventoryAlert = false
    @StateObject private var errorState = ErrorAlertState()
    @State private var catalogItemsCount = 0
    @State private var inventoryItemsCount = 0

    private let catalogService: CatalogService
    private let dataLoadingService: GlassItemDataLoadingService
    private let inventoryRepository: InventoryRepository

    init(
        catalogService: CatalogService = RepositoryFactory.createCatalogService(),
        dataLoadingService: GlassItemDataLoadingService? = nil
    ) {
        self.catalogService = catalogService
        self.dataLoadingService = dataLoadingService ?? GlassItemDataLoadingService(catalogService: catalogService)
        self.inventoryRepository = RepositoryFactory.createInventoryRepository()
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total Catalog Items")
                    Spacer()
                    Text("\(catalogItemsCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Items with Inventory")
                    Spacer()
                    Text("\(inventoryItemsCount)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Database Status")
            }
            
            Section {
                Button {
                    loadJSONData()
                } label: {
                    Label("Load JSON Data", systemImage: "square.and.arrow.down")
                }
                .disabled(isLoadingData)
                
                Button {
                    smartMergeJSONData()
                } label: {
                    Label("Smart Merge JSON", systemImage: "arrow.triangle.merge")
                }
                .disabled(isLoadingData)
                
                Button {
                    loadJSONIfEmpty()
                } label: {
                    Label("Load if Empty", systemImage: "questionmark.square.dashed")
                }
                .disabled(isLoadingData)
            } header: {
                Text("Data Import")
            } footer: {
                if isLoadingData {
                    Text("Loading data...")
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button {
                    showingClearInventoryAlert = true
                } label: {
                    Label("Clear All Inventory", systemImage: "archivebox")
                        .foregroundColor(.orange)
                }
                .disabled(inventoryItemsCount == 0)

                Button {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete All Catalog Data", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .disabled(catalogItemsCount == 0)
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Clear Inventory removes all inventory records but keeps catalog items. Delete All removes everything including catalog data.")
            }
        }
        .navigationTitle("Data Management")
        .errorAlert(errorState)
        .task {
            await loadCatalogItemsCount()
        }
        .alert("Clear All Inventory", isPresented: $showingClearInventoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Inventory", role: .destructive) {
                clearAllInventory()
            }
        } message: {
            Text("This will delete all inventory records for \(inventoryItemsCount) items, but keep the catalog data. This action cannot be undone.")
        }
        .alert("Delete All Items", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllItems()
            }
        } message: {
            Text("This will permanently delete all \(catalogItemsCount) catalog items. This action cannot be undone.")
        }
    }
    
    // MARK: - Actions
    
    private func loadCatalogItemsCount() async {
        do {
            let items = try await catalogService.getAllGlassItems()
            let itemsWithInventory = items.filter { $0.totalQuantity > 0 }
            await MainActor.run {
                catalogItemsCount = items.count
                inventoryItemsCount = itemsWithInventory.count
            }
        } catch {
            print("Error loading catalog items count: \(error)")
        }
    }

    private func clearAllInventory() {
        Task {
            do {
                // Fetch all inventory records
                let allInventory = try await inventoryRepository.fetchInventory(matching: nil)

                // Delete each inventory record
                for inventory in allInventory {
                    try await inventoryRepository.deleteInventory(id: inventory.id)
                }

                // Reload counts
                await loadCatalogItemsCount()

                // Invalidate cache and notify InventoryView to refresh
                await MainActor.run {
                    // Force cache reload
                    Task {
                        await CatalogDataCache.shared.reload(catalogService: catalogService)
                    }

                    // Post notification to refresh InventoryView
                    NotificationCenter.default.post(name: .inventoryItemAdded, object: nil)
                }

                print("✅ All inventory cleared successfully - deleted \(allInventory.count) records")
            } catch {
                await MainActor.run {
                    errorState.show(error: error, context: "Failed to clear inventory")
                }
            }
        }
    }
    
    private func loadJSONData() {
        guard !isLoadingData else { return }
        
        isLoadingData = true
        
        Task {
            let result = await ErrorHandler.shared.executeAsync(context: "Loading JSON data") {
                _ = try await dataLoadingService.loadGlassItemsFromJSON()
            }
            
            await MainActor.run {
                isLoadingData = false
                switch result {
                case .success:
                    print("✅ JSON loading completed successfully")
                    Task {
                        await loadCatalogItemsCount()
                    }
                case .failure(let error):
                    errorState.show(error: error, context: "JSON loading failed")
                }
            }
        }
    }
    
    private func smartMergeJSONData() {
        guard !isLoadingData else { return }
        
        isLoadingData = true
        
        Task {
            let result = await ErrorHandler.shared.executeAsync(context: "Smart merging JSON data") {
                _ = try await dataLoadingService.loadGlassItemsAndUpdateExisting()
            }
            
            await MainActor.run {
                isLoadingData = false
                switch result {
                case .success:
                    print("✅ Smart merge completed successfully")
                    Task {
                        await loadCatalogItemsCount()
                    }
                case .failure(let error):
                    errorState.show(error: error, context: "Smart merge failed")
                }
            }
        }
    }
    
    private func loadJSONIfEmpty() {
        guard !isLoadingData else { return }
        
        isLoadingData = true
        
        Task {
            let result = await ErrorHandler.shared.executeAsync(context: "Conditional JSON loading") {
                _ = try await dataLoadingService.loadGlassItemsFromJSONIfEmpty()
            }
            
            await MainActor.run {
                isLoadingData = false
                switch result {
                case .success:
                    print("✅ Conditional JSON loading completed")
                    Task {
                        await loadCatalogItemsCount()
                    }
                case .failure(let error):
                    errorState.show(error: error, context: "Conditional JSON loading failed")
                }
            }
        }
    }
    
    private func deleteAllItems() {
        // TODO: Add deleteAllItems method to CatalogService/Repository
        // For now, this functionality needs to be implemented at the repository level
        Task {
            do {
                let items = try await catalogService.getAllGlassItems()
                // Note: This is a temporary solution - ideally we'd have a deleteAll method
                // in the repository to avoid loading all items into memory first
                print("⚠️ Delete all items functionality needs to be implemented in repository pattern")
                print("🗑️ Would delete \(items.count) items")
                
                // Reset the count
                await MainActor.run {
                    catalogItemsCount = 0
                }
            } catch {
                await MainActor.run {
                    errorState.show(error: error, context: "Failed to delete items")
                }
            }
        }
    }
}

// MARK: - COE Filter View
struct COEFilterView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note: COE (Coefficient of Expansion) filtering works alongside the manufacturer filter. Both filters must match for items to appear in the catalog.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                // Quick actions for all COE types
                COEQuickActionsView()

                if SettingsViewHelpers.shouldShowCOEFilterSection() {
                    ForEach(COEGlassType.allCases, id: \.self) { coeType in
                        COEToggleRow(coeType: coeType)
                    }
                    
                } else {
                    Text("COE filtering is not available")
                        .foregroundColor(.secondary)
                }
            } footer: {
                if SettingsViewHelpers.shouldShowCOEFilterSection() {
                    COESelectionFooter()
                } else {
                    Text("COE glass filtering feature is currently disabled.")
                }
            }
        }
        .navigationTitle("COE Filter")
    }
}

// MARK: - Manufacturer Filter View
struct ManufacturerFilterView: View {
    @State private var localEnabledManufacturers: Set<String> = []
    @State private var glassItems: [CompleteInventoryItemModel] = []
    @State private var isLoading = true
    
    private let catalogService: CatalogService
    
    init(catalogService: CatalogService = RepositoryFactory.createCatalogService()) {
        self.catalogService = catalogService
    }
    
    // All unique manufacturers from both catalog items and GlassManufacturers, sorted by COE first, then alphabetically
    private var allManufacturers: [String] {
        // Get manufacturers from database
        let databaseManufacturers = glassItems.compactMap { item in
            item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        
        // Get manufacturers from GlassManufacturers static list
        let staticManufacturers = GlassManufacturers.allCodes
        
        // Union both sets to create complete list
        let allManufacturerCodes = Set(databaseManufacturers).union(Set(staticManufacturers))
        let uniqueManufacturers = Array(allManufacturerCodes)
        
        // Sort by COE first, then alphabetically within each COE group
        return uniqueManufacturers.sorted { manufacturer1, manufacturer2 in
            let coe1 = GlassManufacturers.primaryCOE(for: manufacturer1) ?? Int.max
            let coe2 = GlassManufacturers.primaryCOE(for: manufacturer2) ?? Int.max
            
            if coe1 != coe2 {
                return coe1 < coe2
            }
            
            // If COEs are the same, sort alphabetically by full name
            let name1 = GlassManufacturers.fullName(for: manufacturer1) ?? manufacturer1
            let name2 = GlassManufacturers.fullName(for: manufacturer2) ?? manufacturer2
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    // Load catalog items from repository
    private func loadCatalogItems() async {
        do {
            let items = try await catalogService.getAllGlassItems()
            await MainActor.run {
                glassItems = items
                isLoading = false
                loadEnabledManufacturers()
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
            print("Error loading catalog items: \(error)")
        }
    }
    
    // Load enabled manufacturers from ManufacturerFilterPreference
    private func loadEnabledManufacturers() {
        let currentManufacturers = Set(allManufacturers)
        let selectedFromPreference = ManufacturerFilterPreference.selectedManufacturers

        // Start with saved preferences, but only keep manufacturers that still exist
        var enabled = selectedFromPreference.intersection(currentManufacturers)

        // Add any NEW manufacturers that weren't in the saved preferences
        // This ensures new manufacturers are enabled by default
        let newManufacturers = currentManufacturers.subtracting(selectedFromPreference)
        enabled.formUnion(newManufacturers)

        // If no valid manufacturers at all, default to all
        if enabled.isEmpty {
            enabled = currentManufacturers
        }

        localEnabledManufacturers = enabled

        // Save the updated set if it changed (to persist new manufacturers as enabled)
        if enabled != selectedFromPreference {
            ManufacturerFilterPreference.setSelectedManufacturers(enabled)
        }
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note: Selecting manufacturers here works alongside the COE filter in Settings. Both filters must match for items to appear in the catalog.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading manufacturers...")
                        Spacer()
                    }
                    .padding()
                } else if allManufacturers.isEmpty {
                    Text("No manufacturers found")
                        .foregroundColor(.secondary)
                } else {
                    // Quick actions for all manufacturers
                    ManufacturerQuickActionsView(
                        allManufacturers: allManufacturers,
                        localEnabledManufacturers: $localEnabledManufacturers
                    )

                    ForEach(allManufacturers, id: \.self) { manufacturer in
                        ManufacturerToggleRow(
                            manufacturer: manufacturer,
                            isEnabled: localEnabledManufacturers.contains(manufacturer)
                        ) { isEnabled in
                            if isEnabled {
                                ManufacturerFilterPreference.addManufacturer(manufacturer)
                                localEnabledManufacturers.insert(manufacturer)
                            } else {
                                ManufacturerFilterPreference.removeManufacturer(manufacturer)
                                localEnabledManufacturers.remove(manufacturer)
                            }
                        }
                    }
                    
                }
            } footer: {
                if !isLoading {
                    Text("\(ManufacturerFilterHelpers.manufacturerFilterSectionFooter) \(localEnabledManufacturers.count) of \(allManufacturers.count) manufacturers selected.")
                }
            }
        }
        .navigationTitle("Manufacturer Filter")
        .task {
            await loadCatalogItems()
        }
        .onChange(of: allManufacturers) { _, _ in
            // When manufacturers list changes, reload to handle new/removed manufacturers
            loadEnabledManufacturers()
        }
    }
}

// MARK: - SortOption Extension
extension SortOption {
    var displayName: String {
        switch self {
        case .name:
            return "Name"
        case .manufacturer:
            return "Manufacturer"
        case .code:
            return "Code"
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
}

// MARK: - COE Filter UI Components

struct COEToggleRow: View {
    let coeType: COEGlassType
    @State private var isSelected: Bool = false
    
    var body: some View {
        HStack {
            Text(coeType.displayName)
            
            Spacer()
            
            Toggle("", isOn: $isSelected)
                .labelsHidden()
                .onChange(of: isSelected) { _, newValue in
                    if newValue {
                        COEGlassPreference.addCOEType(coeType)
                    } else {
                        COEGlassPreference.removeCOEType(coeType)
                    }
                }
        }
        .onAppear {
            isSelected = COEGlassPreference.selectedCOETypes.contains(coeType)
        }
        .onReceive(NotificationCenter.default.publisher(for: .coeSelectionChanged)) { _ in
            isSelected = COEGlassPreference.selectedCOETypes.contains(coeType)
        }
    }
}

struct COEQuickActionsView: View {
    @State private var selectedCount: Int = 0
    
    var body: some View {
        HStack {
            Button("Select All") {
                let allTypes = Set(COEGlassType.allCases)
                COEGlassPreference.setSelectedCOETypes(allTypes)
                NotificationCenter.default.post(name: .coeSelectionChanged, object: nil)
            }
            .buttonStyle(.bordered)
            .disabled(selectedCount == COEGlassType.allCases.count)
            
            Spacer()
            
            Button("Select None") {
                COEGlassPreference.setSelectedCOETypes(Set())
                NotificationCenter.default.post(name: .coeSelectionChanged, object: nil)
            }
            .buttonStyle(.bordered)
            .disabled(selectedCount == 0)
        }
        .padding(.top, 8)
        .onAppear {
            selectedCount = COEGlassPreference.selectedCOETypes.count
        }
        .onReceive(NotificationCenter.default.publisher(for: .coeSelectionChanged)) { _ in
            selectedCount = COEGlassPreference.selectedCOETypes.count
        }
    }
}

struct COESelectionFooter: View {
    @State private var selectedCount: Int = 0
    
    var body: some View {
        let totalCount = COEGlassType.allCases.count
        let footerText = "\(SettingsViewHelpers.coeFilterSectionFooter) \(selectedCount) of \(totalCount) COE types selected."
        Text(footerText)
            .onAppear {
                selectedCount = COEGlassPreference.selectedCOETypes.count
            }
            .onReceive(NotificationCenter.default.publisher(for: .coeSelectionChanged)) { _ in
                selectedCount = COEGlassPreference.selectedCOETypes.count
            }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    nonisolated static let coeSelectionChanged = Notification.Name("coeSelectionChanged")
    nonisolated static let manufacturerSelectionChanged = Notification.Name("manufacturerSelectionChanged")
}

// MARK: - Manufacturer Filter UI Components

struct ManufacturerToggleRow: View {
    let manufacturer: String
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    @State private var internalIsEnabled: Bool = false
    
    private var displayText: String {
        let fullName = GlassManufacturers.fullName(for: manufacturer) ?? manufacturer
        return fullName
    }
    
    var body: some View {
        HStack {
            Text(displayText)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { internalIsEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .onAppear {
            internalIsEnabled = ManufacturerFilterService.shared.isManufacturerEnabled(manufacturer)
        }
        .onReceive(NotificationCenter.default.publisher(for: .manufacturerSelectionChanged)) { _ in
            internalIsEnabled = ManufacturerFilterService.shared.isManufacturerEnabled(manufacturer)
        }
    }
}

struct ManufacturerQuickActionsView: View {
    let allManufacturers: [String]
    @Binding var localEnabledManufacturers: Set<String>
    @State private var selectedCount: Int = 0
    
    var body: some View {
        HStack {
            Button("Select All") {
                let allManufacturerSet = Set(allManufacturers)
                ManufacturerFilterPreference.setSelectedManufacturers(allManufacturerSet)
                localEnabledManufacturers = allManufacturerSet
            }
            .buttonStyle(.bordered)
            .disabled(selectedCount == allManufacturers.count)
            
            Spacer()
            
            Button("Select None") {
                ManufacturerFilterPreference.setSelectedManufacturers(Set())
                localEnabledManufacturers.removeAll()
            }
            .buttonStyle(.bordered)
            .disabled(selectedCount == 0)
        }
        .padding(.top, 8)
        .onAppear {
            selectedCount = ManufacturerFilterService.shared.enabledManufacturers.count
        }
        .onReceive(NotificationCenter.default.publisher(for: .manufacturerSelectionChanged)) { _ in
            selectedCount = ManufacturerFilterService.shared.enabledManufacturers.count
        }
    }
}

struct ManufacturerSelectionFooter: View {
    let selectedCount: Int
    let totalCount: Int

    var body: some View {
        Text("\(ManufacturerFilterHelpers.manufacturerFilterSectionFooter) \(selectedCount) of \(totalCount) manufacturers selected.")
    }
}

// MARK: - Terminology Settings View

struct TerminologySettingsView: View {
    @ObservedObject var settings = GlassTerminologySettings.shared
    @State private var showingBothEnabledAlert = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The glass industry uses different terms for rod sizes:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hot Shop")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("\"Rods\" = 12mm+")
                                .font(.caption2)
                            Text("\"Cane\" = 2-10mm+")
                                .font(.caption2)
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Flameworking/Fusing")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("\"Rods\" = 2-10mm+")
                                .font(.caption2)
                            Text("(calls cane \"rods\")")
                                .font(.caption2)
                                .italic()
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(.vertical, 4)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { settings.enableHotShop },
                    set: { newValue in
                        settings.enableHotShop = newValue
                        settings.validateSettings()
                        if settings.enableHotShop && settings.enableFlameworking {
                            showingBothEnabledAlert = true
                        }
                    }
                )) {
                    Label("Hot Shop / Glass Blowing", systemImage: "fireplace.fill")
                }

                Toggle(isOn: Binding(
                    get: { settings.enableFlameworking },
                    set: { newValue in
                        settings.enableFlameworking = newValue
                        settings.validateSettings()
                        if settings.enableHotShop && settings.enableFlameworking {
                            showingBothEnabledAlert = true
                        }
                    }
                )) {
                    Label("Flameworking / Fusing", systemImage: "flame")
                }
            } header: {
                Text("Enable Terminology")
            } footer: {
                Text(settings.currentSettingsMessage)
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Changing terminology settings only affects how products are displayed in the app.")
                                .font(.callout)
                                .foregroundStyle(.primary)

                            Text("Your stored inventory data will not be affected, so you can safely switch between terminologies at any time.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Glass Terminology")
        .alert("Both Terminologies Enabled", isPresented: $showingBothEnabledAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("""
            When both terminologies are enabled:
            • Hot shop rods (12mm+) will be called "Rods"
            • Flameworking rods (5-6mm) will be called "Cane"

            This lets you work with both types while keeping them distinct.
            """)
        }
    }
}
