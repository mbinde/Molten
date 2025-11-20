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
    private let manufacturerFilterService: ManufacturerFilterService

    init(
        catalogService: CatalogService = AppDependencies.shared.catalogService,
        manufacturerFilterService: ManufacturerFilterService = AppDependencies.shared.manufacturerFilterService
    ) {
        self.catalogService = catalogService
        self.manufacturerFilterService = manufacturerFilterService
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

    // Load enabled manufacturers from service
    private func loadEnabledManufacturers() {
        localEnabledManufacturers = manufacturerFilterService.selectedManufacturers

        // Update service with current manufacturer list (handles new/removed manufacturers)
        Task {
            await manufacturerFilterService.updateAvailableManufacturers(allManufacturers)
            await MainActor.run {
                localEnabledManufacturers = manufacturerFilterService.selectedManufacturers
            }
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
                        localEnabledManufacturers: $localEnabledManufacturers,
                        service: manufacturerFilterService
                    )

                    ForEach(allManufacturers, id: \.self) { manufacturer in
                        ManufacturerToggleRow(
                            manufacturer: manufacturer,
                            isEnabled: localEnabledManufacturers.contains(manufacturer),
                            service: manufacturerFilterService
                        ) { isEnabled in
                            Task {
                                if isEnabled {
                                    await manufacturerFilterService.enableManufacturer(manufacturer)
                                    await MainActor.run {
                                        localEnabledManufacturers.insert(manufacturer)
                                    }
                                } else {
                                    await manufacturerFilterService.disableManufacturer(manufacturer)
                                    await MainActor.run {
                                        localEnabledManufacturers.remove(manufacturer)
                                    }
                                }
                            }
                        }
                    }

                }
            } footer: {
                if !isLoading {
                    Text("Select which manufacturers to show in the catalog. This filter works alongside the COE filter to refine your search results. \(localEnabledManufacturers.count) of \(allManufacturers.count) manufacturers selected.")
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
