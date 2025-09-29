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
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("showManufacturerColors") private var showManufacturerColors = false
    @AppStorage("defaultSortOption") private var defaultSortOptionRawValue = SortOption.name.rawValue
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
    
    // All unique manufacturers from catalog items
    private var allManufacturers: [String] {
        let manufacturers = catalogItems.compactMap { item in
            item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        
        return Array(Set(manufacturers)).sorted()
    }
    
    // Load enabled manufacturers from storage
    private func loadEnabledManufacturers() {
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: enabledManufacturersData) {
            localEnabledManufacturers = decoded
        } else {
            localEnabledManufacturers = Set(allManufacturers) // Default to all enabled
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
                        Text("Default Sort Order")
                        Spacer()
                        Picker("Default Sort Order", selection: defaultSortOptionBinding) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("Interaction") {
                    Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                        .help("Enable haptic feedback for interactions")
                }
                
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
            .onChange(of: allManufacturers) { _ in
                // When manufacturers list changes, ensure our local state includes new manufacturers
                let currentEnabled = localEnabledManufacturers
                let newManufacturers = Set(allManufacturers)
                
                // Add any new manufacturers to enabled set (default behavior)
                let missingManufacturers = newManufacturers.subtracting(currentEnabled)
                if !missingManufacturers.isEmpty {
                    localEnabledManufacturers.formUnion(missingManufacturers)
                    saveEnabledManufacturers()
                }
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
    
    var body: some View {
        HStack {
            if showManufacturerColors {
                Circle()
                    .fill(CatalogColorHelper.colorForManufacturer(manufacturer))
                    .frame(width: 12, height: 12)
            }
            
            Text(manufacturer)
            
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
        guard !isLoadingData else { return }
        
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
        guard !isLoadingData else { return }
        
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
        case .startDate:
            return "Start Date"
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}