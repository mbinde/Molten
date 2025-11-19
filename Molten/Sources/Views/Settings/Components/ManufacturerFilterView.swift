//
//  ManufacturerFilterView.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

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
                    LoadingStateView(message: "Loading manufacturers...")
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
