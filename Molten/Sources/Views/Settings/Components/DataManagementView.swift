//
//  DataManagementView.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

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
                .accessibilityIdentifier("data_management_clear_inventory")

                Button {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete All Catalog Data", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .disabled(catalogItemsCount == 0)
                .accessibilityIdentifier("data_management_delete_catalog")
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
