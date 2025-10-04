//
//  SettingsView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @AppStorage("showDebugInfo") private var showDebugInfo = false
    @AppStorage("showManufacturerColors") private var showManufacturerColors = false
    @AppStorage("defaultSortOption") private var defaultSortOptionRawValue = SortOption.name.rawValue
    @AppStorage("defaultUnits") private var defaultUnitsRawValue = DefaultUnits.pounds.rawValue
    @AppStorage("enabledManufacturers") private var enabledManufacturersData: Data = Data()
    
    @State private var localEnabledManufacturers: Set<String> = []
    
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
    
    private var defaultUnitsBinding: Binding<DefaultUnits> {
        Binding(
            get: { DefaultUnits(rawValue: defaultUnitsRawValue) ?? .pounds },
            set: { defaultUnitsRawValue = $0.rawValue }
        )
    }
    
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
    
    // Load enabled manufacturers from storage, enabling new manufacturers by default
    private func loadEnabledManufacturers() {
        let currentManufacturers = Set(allManufacturers)
        
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: enabledManufacturersData) {
            // Start with previously saved enabled manufacturers
            var enabledSet = decoded
            
            // Add any new manufacturers that weren't in the saved settings (enable by default)
            let newManufacturers = currentManufacturers.subtracting(decoded)
            enabledSet.formUnion(newManufacturers)
            
            // Remove any manufacturers that no longer exist
            enabledSet = enabledSet.intersection(currentManufacturers)
            
            localEnabledManufacturers = enabledSet
            
            // Save the updated set if we made changes
            if !newManufacturers.isEmpty || enabledSet.count != decoded.count {
                saveEnabledManufacturers()
            }
        } else {
            // No saved settings, default to all manufacturers enabled
            localEnabledManufacturers = currentManufacturers
            saveEnabledManufacturers()
        }
    }
    
    // Save enabled manufacturers to storage
    private func saveEnabledManufacturers() {
        if let encoded = try? JSONEncoder().encode(localEnabledManufacturers) {
            enabledManufacturersData = encoded
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Display") {
                    Toggle("Show Debug Information", isOn: $showDebugInfo)
                        .help("Show additional debug information in the catalog view")
                    
                    Toggle("Show Manufacturer Colors", isOn: $showManufacturerColors)
                        .help("Show colored indicators for different manufacturers")
                    
                    HStack {
                        Picker("Default Sort Order", selection: defaultSortOptionBinding) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
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
                
                Section {
                    if allManufacturers.isEmpty {
                        Text("No manufacturers found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(allManufacturers, id: \.self) { manufacturer in
                            ManufacturerCheckboxRow(
                                manufacturer: manufacturer,
                                isEnabled: localEnabledManufacturers.contains(manufacturer)
                            ) { isEnabled in
                                if isEnabled {
                                    localEnabledManufacturers.insert(manufacturer)
                                } else {
                                    localEnabledManufacturers.remove(manufacturer)
                                }
                                saveEnabledManufacturers()
                            }
                        }
                        
                        // Quick actions for all manufacturers
                        HStack {
                            Button("Select All") {
                                localEnabledManufacturers = Set(allManufacturers)
                                saveEnabledManufacturers()
                            }
                            .buttonStyle(.bordered)
                            .disabled(localEnabledManufacturers.count == allManufacturers.count)
                            
                            Spacer()
                            
                            Button("Select None") {
                                localEnabledManufacturers.removeAll()
                                saveEnabledManufacturers()
                            }
                            .buttonStyle(.bordered)
                            .disabled(localEnabledManufacturers.isEmpty)
                        }
                        .padding(.top, 8)
                    }
                } header: {
                    Text("Enabled Manufacturers")
                } footer: {
                    Text("Select which manufacturers to show in the catalog. \(localEnabledManufacturers.count) of \(allManufacturers.count) manufacturers enabled.")
                }
                
                Section("Data Management") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("Data Management", systemImage: "externaldrive")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadEnabledManufacturers()
            }
            .onChange(of: allManufacturers) { _, _ in
                // When manufacturers list changes, reload to handle new/removed manufacturers
                loadEnabledManufacturers()
            }
        }
    }
}

// MARK: - Manufacturer Checkbox Row
struct ManufacturerCheckboxRow: View {
    let manufacturer: String
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    @AppStorage("showManufacturerColors") private var showManufacturerColors = false
    
    private var displayText: String {
        let fullName = GlassManufacturers.fullName(for: manufacturer) ?? manufacturer
        
        if let coeValues = GlassManufacturers.coeValues(for: manufacturer) {
            let coeString = coeValues.map(String.init).joined(separator: ", ")
            return "\(fullName) (\(coeString))"
        } else {
            return fullName
        }
    }
    
    var body: some View {
        HStack {
            if showManufacturerColors {
                Circle()
                    .fill(GlassManufacturers.colorForManufacturer(manufacturer))
                    .frame(width: 12, height: 12)
            }
            
            Text(displayText)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
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
