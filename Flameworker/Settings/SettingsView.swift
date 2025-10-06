//
//  SettingsView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

// MARK: - Manufacturer Filter Preference Management

/// Manages user preferences for manufacturer filtering
class ManufacturerFilterPreference {
    
    /// Storage key for UserDefaults
    static let storageKey = "selectedManufacturerFilter"
    
    /// UserDefaults instance (can be overridden for testing)
    private static var userDefaults: UserDefaults = .standard
    
    /// Selected manufacturers (multi-selection)
    static var selectedManufacturers: Set<String> {
        if let data = userDefaults.data(forKey: storageKey),
           let manufacturers = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return manufacturers
        }
        
        // Default: all manufacturers selected
        return Set(GlassManufacturers.allCodes)
    }
    
    /// Add a manufacturer to the multi-selection
    static func addManufacturer(_ manufacturer: String) {
        var current = selectedManufacturers
        current.insert(manufacturer)
        saveSelectedManufacturers(current)
        NotificationCenter.default.post(name: .manufacturerSelectionChanged, object: nil)
    }
    
    /// Remove a manufacturer from the multi-selection
    static func removeManufacturer(_ manufacturer: String) {
        var current = selectedManufacturers
        current.remove(manufacturer)
        saveSelectedManufacturers(current)
        NotificationCenter.default.post(name: .manufacturerSelectionChanged, object: nil)
    }
    
    /// Set the complete multi-selection
    static func setSelectedManufacturers(_ manufacturers: Set<String>) {
        saveSelectedManufacturers(manufacturers)
        NotificationCenter.default.post(name: .manufacturerSelectionChanged, object: nil)
    }
    
    /// Save selected manufacturers to UserDefaults
    private static func saveSelectedManufacturers(_ manufacturers: Set<String>) {
        if let data = try? JSONEncoder().encode(manufacturers) {
            userDefaults.set(data, forKey: storageKey)
        }
    }
    
    /// Reset to default (all manufacturers selected)
    static func resetToDefault() {
        userDefaults.removeObject(forKey: storageKey)
    }
    
    /// Set UserDefaults instance (for testing)
    static func setUserDefaults(_ defaults: UserDefaults) {
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
    
    private init() {}
    
    /// Check if a specific manufacturer is enabled
    func isManufacturerEnabled(_ manufacturer: String) -> Bool {
        return ManufacturerFilterPreference.selectedManufacturers.contains(manufacturer)
    }
    
    /// Get all currently enabled manufacturers
    var enabledManufacturers: Set<String> {
        return ManufacturerFilterPreference.selectedManufacturers
    }
    
    /// Check if a catalog item should be shown based on manufacturer filter
    func shouldShowItem(manufacturer: String?) -> Bool {
        guard let manufacturer = manufacturer else { return true }
        return isManufacturerEnabled(manufacturer)
    }
}

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isAdvancedFeaturesEnabled = false

struct SettingsView: View {
    @AppStorage("showDebugInfo") private var showDebugInfo = false
    @AppStorage("defaultSortOption") private var defaultSortOptionRawValue = SortOption.name.rawValue
    @AppStorage("defaultInventorySortOption") private var defaultInventorySortOptionRawValue = "Name"
    @AppStorage("defaultUnits") private var defaultUnitsRawValue = DefaultUnits.pounds.rawValue
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CatalogItem.manufacturer, ascending: true)],
        animation: .default
    )
    private var catalogItems: FetchedResults<CatalogItem>
    
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
                Section("Display") {
                    Toggle("Show Debug Information", isOn: $showDebugInfo)
                        .help("Show additional debug information in the catalog view")
                    
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
                
                // Advanced filtering settings - feature gated for release
                // Note: This legacy section is replaced by the new Manufacturer Filter section above
                /*
                if isAdvancedFeaturesEnabled {
                    // Legacy manufacturer filtering code removed
                }
                */
                
                Section("Data Management") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("Data Management", systemImage: "externaldrive")
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
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isLoadingData = false
    @State private var showingDeleteAlert = false
    @StateObject private var errorState = ErrorAlertState()
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)],
        animation: .default
    )
    private var catalogItems: FetchedResults<CatalogItem>
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total Items")
                    Spacer()
                    Text("\(catalogItems.count)")
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
                    showingDeleteAlert = true
                } label: {
                    Label("Delete All Data", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .disabled(catalogItems.isEmpty)
            } header: {
                Text("Danger Zone")
            }
        }
        .navigationTitle("Data Management")
        .errorAlert(errorState)
        .alert("Delete All Items", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllItems()
            }
        } message: {
            Text("This will permanently delete all \(catalogItems.count) catalog items. This action cannot be undone.")
        }
    }
    
    // MARK: - Actions
    private func loadJSONData() {
        guard !isLoadingData else { return }
        
        isLoadingData = true
        
        Task {
            let result = await ErrorHandler.shared.executeAsync(context: "Loading JSON data") {
                try await DataLoadingService.shared.loadCatalogItemsFromJSON(into: viewContext)
            }
            
            await MainActor.run {
                isLoadingData = false
                switch result {
                case .success:
                    print("✅ JSON loading completed successfully")
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
                try await DataLoadingService.shared.loadCatalogItemsFromJSONWithMerge(into: viewContext)
            }
            
            await MainActor.run {
                isLoadingData = false
                switch result {
                case .success:
                    print("✅ Smart merge completed successfully")
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
                try await DataLoadingService.shared.loadCatalogItemsFromJSONIfEmpty(into: viewContext)
            }
            
            await MainActor.run {
                isLoadingData = false
                switch result {
                case .success:
                    print("✅ Conditional JSON loading completed")
                case .failure(let error):
                    errorState.show(error: error, context: "Conditional JSON loading failed")
                }
            }
        }
    }
    
    private func deleteAllItems() {
        withAnimation {
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
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CatalogItem.manufacturer, ascending: true)],
        animation: .default
    )
    private var catalogItems: FetchedResults<CatalogItem>
    
    // All unique manufacturers from both catalog items and GlassManufacturers, sorted by COE first, then alphabetically
    private var allManufacturers: [String] {
        // Get manufacturers from database
        let databaseManufacturers = catalogItems.compactMap { item in
            item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    // Load enabled manufacturers from ManufacturerFilterPreference
    private func loadEnabledManufacturers() {
        let currentManufacturers = Set(allManufacturers)
        let selectedFromPreference = ManufacturerFilterPreference.selectedManufacturers
        
        // Sync with local state, ensuring only valid manufacturers are included
        localEnabledManufacturers = selectedFromPreference.intersection(currentManufacturers)
        
        // If no valid manufacturers are selected, default to all
        if localEnabledManufacturers.isEmpty {
            localEnabledManufacturers = currentManufacturers
            ManufacturerFilterPreference.setSelectedManufacturers(currentManufacturers)
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
                if allManufacturers.isEmpty {
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
                Text("\(ManufacturerFilterHelpers.manufacturerFilterSectionFooter) \(localEnabledManufacturers.count) of \(allManufacturers.count) manufacturers selected.")
            }
        }
        .navigationTitle("Manufacturer Filter")
        .onAppear {
            loadEnabledManufacturers()
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
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
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
    static let coeSelectionChanged = Notification.Name("coeSelectionChanged")
    static let manufacturerSelectionChanged = Notification.Name("manufacturerSelectionChanged")
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
