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
    @Environment(EntitlementService.self) private var entitlementService
    @Environment(SubscriptionManager.self) private var subscriptionManager

    private let catalogService: CatalogService
    private let subscriptionService: SubscriptionServiceProtocol
    @State private var subscriptionViewModel: SubscriptionViewModel
    @State private var catalogUpdateViewModel: CatalogUpdateViewModel

    init(
        catalogService: CatalogService = AppDependencies().catalogService,
        subscriptionService: SubscriptionServiceProtocol = AppDependencies().subscriptionService,
        catalogUpdateService: CatalogUpdateService? = nil
    ) {
        self.catalogService = catalogService
        self.subscriptionService = subscriptionService
        self._subscriptionViewModel = State(initialValue: SubscriptionViewModel(subscriptionService: subscriptionService))

        // Initialize catalog update view model
        let updateService = catalogUpdateService ?? CatalogUpdateService(
            apiClient: CatalogAPIClient(),
            storageService: try! CatalogStorageService(),
            networkMonitor: NetworkMonitor.shared
        )
        self._catalogUpdateViewModel = State(initialValue: CatalogUpdateViewModel(updateService: updateService))
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

    // Subscription computed properties
    private var subscriptionIcon: String {
        subscriptionViewModel.hasProAccess ? "star.fill" : "star"
    }

    private var subscriptionBadge: String {
        subscriptionViewModel.hasProAccess ? "Pro" : "Free"
    }

    private var subscriptionBadgeColor: Color {
        subscriptionViewModel.hasProAccess ? .white : .blue
    }

    private var subscriptionBadgeBackground: Color {
        subscriptionViewModel.hasProAccess ? .yellow : .blue.opacity(0.2)
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

                // Subscription section
                Section("Subscription") {
                    NavigationLink {
                        SubscriptionStatusView(viewModel: subscriptionViewModel)
                    } label: {
                        HStack {
                            Label("Manage Subscription", systemImage: subscriptionIcon)
                            Spacer()
                            Text(subscriptionBadge)
                                .font(.caption.bold())
                                .foregroundColor(subscriptionBadgeColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(subscriptionBadgeBackground)
                                .cornerRadius(6)
                        }
                    }
                }
                .task {
                    // Load subscription status when settings view appears
                    await subscriptionViewModel.loadSubscriptionStatus()
                }

                // Catalog Updates section
                Section("Catalog") {
                    NavigationLink {
                        CatalogInfoView(viewModel: catalogUpdateViewModel)
                    } label: {
                        HStack {
                            Label("Catalog Updates", systemImage: "arrow.down.circle")

                            Spacer()

                            if let updateMessage = catalogUpdateViewModel.updateAvailableMessage {
                                Text(updateMessage)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            } else {
                                Text("v\(catalogUpdateViewModel.currentVersion)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Inventory Owner")
                        Spacer()
                        TextField("Optional", text: Binding(
                            get: { UserSettings.shared.inventoryOwner ?? "" },
                            set: { UserSettings.shared.inventoryOwner = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .multilineTextAlignment(.trailing)
                    }
                    .help("Optional name to display on inventory labels (e.g., studio name or artist name)")
                } header: {
                    Text("Labels")
                } footer: {
                    Text("The inventory owner will appear as an optional field on printed labels when set.")
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

                    Picker("Project Thumbnail Style", selection: Binding(
                        get: { UserSettings.shared.thumbnailDisplayMode },
                        set: { UserSettings.shared.thumbnailDisplayMode = $0 }
                    )) {
                        ForEach(UserSettings.ThumbnailDisplayMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .help("Choose how project thumbnails are displayed: Fit preserves aspect ratio, Fill crops to square")

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

                // Image Quality section
                Section {
                    NavigationLink {
                        ImageQualitySettingsView()
                    } label: {
                        Label("Image Quality & Cache", systemImage: "photo.on.rectangle.angled")
                    }
                } header: {
                    Text("Images")
                }

                // REMOVED: Haptic feedback section - HapticService removed from project

                // Kiln settings section
                Section("Kiln") {
                    Picker("Temperature Unit", selection: Binding(
                        get: { UserSettings.shared.preferredTemperatureUnit },
                        set: { UserSettings.shared.preferredTemperatureUnit = $0 }
                    )) {
                        ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help("Choose your preferred temperature unit for displaying kiln schedules")

                    NavigationLink {
                        KilnRatesSettingsView()
                    } label: {
                        Label("Kiln Max Rates", systemImage: "gauge.with.dots.needle.67percent")
                    }
                }

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

                // Tag Filters section
                Section {
                    Toggle("Show User Tags in Filters", isOn: Binding(
                        get: { UserSettings.shared.showUserTagsInFilter },
                        set: { UserSettings.shared.showUserTagsInFilter = $0 }
                    ))
                    .help("When enabled, user-created tags will appear in the tag filter menu")

                    Toggle("Show Technical Tags in Filters", isOn: Binding(
                        get: { UserSettings.shared.showTechnicalTagsInFilter },
                        set: { UserSettings.shared.showTechnicalTagsInFilter = $0 }
                    ))
                    .help("When enabled, technical property tags (reducing, seeded, reactive, striker, uv, cfl, luster, etc.) will appear in the tag filter menu")
                } header: {
                    Text("Tag Filters")
                } footer: {
                    Text("Control which tag categories appear in the tag filter menu. Tags will remain visible on catalog items regardless of these settings.")
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

                // Data Management section
                Section("Data") {
                    NavigationLink {
                        DataExportView()
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
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
                    // Subscription tier override for testing
                    Toggle(isOn: Binding(
                        get: { DebugConfig.debugOverrideSubscriptionTier },
                        set: { DebugConfig.debugOverrideSubscriptionTier = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Override Subscription Tier")
                                .font(.body)
                            Text("Test premium features without purchase")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if DebugConfig.debugOverrideSubscriptionTier {
                        Picker("Debug Tier", selection: Binding(
                            get: { DebugConfig.debugSubscriptionTierValue },
                            set: { DebugConfig.debugSubscriptionTierValue = $0 }
                        )) {
                            Text("Free").tag(0)
                            Text("Premium").tag(1)
                        }
                        .pickerStyle(.segmented)

                        // Show current tier status
                        HStack {
                            Image(systemName: entitlementService.currentTier == .premium ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(entitlementService.currentTier == .premium ? .green : .secondary)
                            Text("Current Tier: \(entitlementService.currentTier == .premium ? "Premium" : "Free")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink {
                        DebugSettingsView()
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
    @State private var showingDeleteAlert = false
    @State private var showingClearInventoryAlert = false
    @StateObject private var errorState = ErrorAlertState()
    @State private var catalogItemsCount = 0
    @State private var inventoryItemsCount = 0

    private let catalogService: CatalogService
    private let inventoryRepository: InventoryRepository

    init(
        catalogService: CatalogService = AppDependencies().catalogService
    ) {
        self.catalogService = catalogService
        self.inventoryRepository = AppDependencies().inventoryRepository
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
    
    init(catalogService: CatalogService = AppDependencies().catalogService) {
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

// MARK: - Subscription Management View

struct SubscriptionManagementView: View {
    @Environment(EntitlementService.self) private var entitlementService
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var showingUpgradePrompt = false

    var body: some View {
        List {
            // Current tier section
            Section {
                HStack {
                    if entitlementService.tier == .premium {
                        Image(systemName: "crown.fill")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                    } else {
                        Image(systemName: "star.circle")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entitlementService.tier == .premium ? "Premium Member" : "Free Tier")
                            .font(.title2.bold())

                        if entitlementService.tier == .premium {
                            Text("Unlimited access to all features")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Limited to free tier features")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 8)
                }
                .padding(.vertical, 8)
            }

            // Usage section
            Section("Current Usage") {
                UsageRow(
                    icon: "cube.box",
                    title: "Inventory Items",
                    current: 0,  // TODO: Get actual count
                    limit: entitlementService.getInventoryLimit()
                )

                UsageRow(
                    icon: "cart",
                    title: "Shopping List Items",
                    current: 0,  // TODO: Get actual count
                    limit: entitlementService.getShoppingListLimit()
                )

                UsageRow(
                    icon: "folder",
                    title: "Projects",
                    current: 0,  // TODO: Get actual count
                    limit: entitlementService.getProjectsLimit()
                )

                UsageRow(
                    icon: "book",
                    title: "Logbook Entries",
                    current: 0,  // TODO: Get actual count
                    limit: entitlementService.getLogbookEntriesLimit()
                )
            }

            // Actions section
            if entitlementService.tier == .free {
                Section {
                    Button(action: {
                        showingUpgradePrompt = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                            Text("Upgrade to Premium")
                                .font(.headline)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Upgrade")
                } footer: {
                    Text("Unlock unlimited inventory, shopping lists, projects, and logbook entries plus premium features.")
                }
            } else {
                Section {
                    Button(action: {
                        #if os(iOS)
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                        #endif
                    }) {
                        Label("Manage Subscription in App Store", systemImage: "gear")
                    }

                    Button(action: {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }) {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("Manage")
                }
            }

            // Premium features section
            Section("Premium Features") {
                FeatureRow(icon: "infinity", title: "Unlimited Inventory Items")
                FeatureRow(icon: "cart.fill", title: "Unlimited Shopping Lists")
                FeatureRow(icon: "folder.fill", title: "Unlimited Projects")
                FeatureRow(icon: "book.fill", title: "Unlimited Logbook Entries")
                FeatureRow(icon: "printer.fill", title: "Batch Label Printing")
                FeatureRow(icon: "qrcode.viewfinder", title: "QR Code Scanning for Inventory")
                FeatureRow(icon: "tag.fill", title: "Custom Tags & Notes for Inventory")
                FeatureRow(icon: "photo.fill", title: "Add Images to Inventory Items")
            }
        }
        .navigationTitle("Subscription")
        .sheet(isPresented: $showingUpgradePrompt) {
            UpgradePromptView(
                feature: "subscription",
                currentCount: 0,
                limit: 0
            )
        }
    }
}

// MARK: - Supporting Views

struct UsageRow: View {
    let icon: String
    let title: String
    let current: Int
    let limit: Int?

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundColor(.accentColor)

            Text(title)

            Spacer()

            if let limit = limit {
                Text("\(current) / \(limit)")
                    .foregroundColor(usageColor)
                    .font(.subheadline.bold())
            } else {
                Text("Unlimited")
                    .foregroundColor(.green)
                    .font(.subheadline.bold())
            }
        }
    }

    private var usagePercentage: Double {
        guard let limit = limit, limit > 0 else { return 0 }
        return Double(current) / Double(limit)
    }

    private var usageColor: Color {
        let percentage = usagePercentage
        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundColor(.accentColor)

            Text(title)
        }
    }
}

// MARK: - Kiln Rates Settings View

struct KilnRatesSettingsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configure your kiln's maximum heating and cooling rates for different temperature ranges.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("These rates are used when you enter 9999 as a ramp rate in a schedule segment, providing more accurate duration estimates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                TemperatureRateRow(
                    label: "20°C - 260°C",
                    value: Binding(
                        get: { UserSettings.shared.kilnHeatupRate20to260 },
                        set: { UserSettings.shared.kilnHeatupRate20to260 = $0 }
                    ),
                    placeholder: "222"
                )

                TemperatureRateRow(
                    label: "260°C - 540°C",
                    value: Binding(
                        get: { UserSettings.shared.kilnHeatupRate260to540 },
                        set: { UserSettings.shared.kilnHeatupRate260to540 = $0 }
                    ),
                    placeholder: "222"
                )

                TemperatureRateRow(
                    label: "540°C - 815°C",
                    value: Binding(
                        get: { UserSettings.shared.kilnHeatupRate540to815 },
                        set: { UserSettings.shared.kilnHeatupRate540to815 = $0 }
                    ),
                    placeholder: "222"
                )

                TemperatureRateRow(
                    label: "815°C+",
                    value: Binding(
                        get: { UserSettings.shared.kilnHeatupRate815Plus },
                        set: { UserSettings.shared.kilnHeatupRate815Plus = $0 }
                    ),
                    placeholder: "222"
                )
            } header: {
                Text("Heat Up Rates (°C/hour)")
            } footer: {
                Text("Default: 222°C/hour (≈400°F/hour)")
            }

            Section {
                TemperatureRateRow(
                    label: "20°C - 260°C",
                    value: Binding(
                        get: { UserSettings.shared.kilnCooldownRate20to260 },
                        set: { UserSettings.shared.kilnCooldownRate20to260 = $0 }
                    ),
                    placeholder: "56"
                )

                TemperatureRateRow(
                    label: "260°C - 540°C",
                    value: Binding(
                        get: { UserSettings.shared.kilnCooldownRate260to540 },
                        set: { UserSettings.shared.kilnCooldownRate260to540 = $0 }
                    ),
                    placeholder: "167"
                )

                TemperatureRateRow(
                    label: "540°C - 815°C",
                    value: Binding(
                        get: { UserSettings.shared.kilnCooldownRate540to815 },
                        set: { UserSettings.shared.kilnCooldownRate540to815 = $0 }
                    ),
                    placeholder: "167"
                )

                TemperatureRateRow(
                    label: "815°C+",
                    value: Binding(
                        get: { UserSettings.shared.kilnCooldownRate815Plus },
                        set: { UserSettings.shared.kilnCooldownRate815Plus = $0 }
                    ),
                    placeholder: "167"
                )
            } header: {
                Text("Cool Down Rates (°C/hour)")
            } footer: {
                Text("Defaults: 56°C/hour (≈100°F/hour) for 20-260°C, 167°C/hour (≈300°F/hour) for higher ranges")
            }
        }
        .navigationTitle("Kiln Max Rates")
    }
}

struct TemperatureRateRow: View {
    let label: String
    @Binding var value: Decimal
    let placeholder: String
    @State private var textValue: String = ""

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: $textValue)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 100)
                .multilineTextAlignment(.trailing)
                .onChange(of: textValue) { _, newValue in
                    if let decimal = Decimal(string: newValue), decimal > 0 {
                        value = decimal
                    }
                }
                .onAppear {
                    textValue = value.description
                }
        }
    }
}

// MARK: - Terminology Settings View

struct TerminologySettingsView: View {
    @ObservedObject var settings = GlassTerminologySettings.shared

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Customize how different rod sizes are labeled in the app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Large Rods")
                        Text("12mm+ diameter")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 140, alignment: .leading)
                    Spacer()
                    TextField("Bar", text: $settings.bigRodDisplayName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 150)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Standard Rods")
                        Text("5-6mm diameter")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 140, alignment: .leading)
                    Spacer()
                    TextField("Rod", text: $settings.rodDisplayName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 150)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Display Names")
            } footer: {
                Text("Customize how different rod sizes are labeled throughout the app.")
            }

            Section {
                Button {
                    settings.resetToDefaults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Defaults")
                    }
                }
            } footer: {
                Text("Reset display names to \"Bar\" and \"Rod\"")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Changing display names only affects how products are labeled in the interface.")
                                .font(.callout)
                                .foregroundStyle(.primary)

                            Text("Your stored inventory data will not be affected, so you can safely customize terminology at any time.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Glass Terminology")
    }
}

// MARK: - Image Quality Settings View
struct ImageQualitySettingsView: View {
    @State private var cacheSize: Int64 = 0
    @State private var showingClearCacheAlert = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(
                    get: { UserSettings.shared.downloadFullSizeImages },
                    set: { UserSettings.shared.downloadFullSizeImages = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Download Full-Size Images")
                            .font(.body)
                        Text("Use original high-resolution images instead of thumbnails")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } footer: {
                if UserSettings.shared.downloadFullSizeImages {
                    Text("Full-size images provide better quality but use significantly more storage space. A typical full-size image is 200-500 KB vs 20-50 KB for thumbnails.")
                } else {
                    Text("Thumbnails (400px) are optimized for mobile viewing and use less storage space.")
                }
            }

            Section {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(formatBytes(cacheSize))
                        .foregroundColor(.secondary)
                }

                Button(role: .destructive) {
                    showingClearCacheAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Image Cache")
                    }
                }
                .disabled(cacheSize == 0)
            } header: {
                Text("Storage Management")
            } footer: {
                Text("Clearing the cache will free up storage space. Images will be re-downloaded as needed when you view items.")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Image Quality vs Storage")
                                .font(.callout)
                                .foregroundStyle(.primary)

                            Text("Enabling full-size images will download higher resolution versions (typically 10x larger than thumbnails). This is recommended only if you have sufficient storage space and want the best image quality.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Image Quality & Cache")
        .task {
            updateCacheSize()
        }
        .alert("Clear Image Cache?", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Cache", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will delete all downloaded images (\(formatBytes(cacheSize))). Images will be re-downloaded as needed.")
        }
    }

    private func updateCacheSize() {
        cacheSize = ImageDownloadService.getCacheSize()
    }

    private func clearCache() {
        ImageDownloadService.clearAllCache()
        updateCacheSize()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
