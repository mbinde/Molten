//
//  InventoryStorageDetailView.swift
//  Molten
//
//  View showing all inventory records for an item
//  Allows toggling between grouping by location or by type
//

import SwiftUI

/// View showing all inventory records for an item
/// Allows toggling between grouping by location or by type
struct InventoryStorageDetailView: View {
    let item: CompleteInventoryItemModel
    let inventoryType: String

    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementService.self) private var entitlementService
    @State private var groupByLocation = true  // true = group by location, false = group by type
    @State private var showingAddInventory = false
    @State private var showingUpgradePrompt = false
    @State private var inventoryItemCount = 0
    @State private var inventoryItemLimit = 0
    @State private var editingRecord: InventoryModel?

    private let inventoryRepository: InventoryRepository
    private let inventoryTrackingService: InventoryTrackingService

    init(item: CompleteInventoryItemModel, inventoryType: String, deps: AppDependencies = AppDependencies()) {
        self.item = item
        self.inventoryType = inventoryType
        self.inventoryRepository = deps.inventoryRepository
        self.inventoryTrackingService = deps.inventoryTrackingService
    }

    var body: some View {
        NavigationStack {
            Group {
                if item.inventory.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No inventory found")
                            .font(.headline)
                        Text("Showing \(item.glassItem.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        // Show total summary
                        Section {
                            HStack {
                                Text("Total Inventory")
                                    .font(.headline)
                                Spacer()
                                Text(formatQuantity(totalQuantity))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                            }
                        }

                        if groupByLocation {
                            groupedByLocationView
                        } else {
                            groupedByTypeView
                        }
                    }
                }
            }
            .navigationTitle(item.glassItem.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("inventory_storage_done")
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            checkLimitAndShowAddInventory()
                        }) {
                            Label("Add Inventory", systemImage: "plus.circle")
                        }
                        .accessibilityIdentifier("inventory_storage_add")

                        Button(action: {
                            withAnimation {
                                groupByLocation.toggle()
                            }
                        }) {
                            Label(groupByLocation ? "Group by Type" : "Group by Location",
                                  systemImage: groupByLocation ? "list.bullet" : "location")
                        }
                        .accessibilityIdentifier("inventory_storage_toggle_grouping")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("inventory_storage_menu")
                }
            }
            .sheet(item: $editingRecord) { record in
                InventoryEditView(
                    record: record,
                    inventoryRepository: inventoryRepository
                )
            }
            .sheet(isPresented: $showingAddInventory) {
                // Present add inventory view (simplified quick-add form)
                QuickAddInventoryView(
                    itemStableId: item.glassItem.stable_id,
                    itemName: item.glassItem.name,
                    inventoryRepository: inventoryRepository
                )
            }
            .sheet(isPresented: $showingUpgradePrompt) {
                UpgradePromptView(
                    feature: "inventory",
                    currentCount: inventoryItemCount,
                    limit: inventoryItemLimit
                )
            }
        }
    }

    /// Check inventory limit and show either the add form or upgrade prompt
    private func checkLimitAndShowAddInventory() {
        Task {
            do {
                // Count unique items with inventory (not individual inventory records)
                let allItemsWithInventory = try await inventoryTrackingService.searchItems(
                    text: "",
                    hasInventory: true
                )
                let currentInventoryCount = allItemsWithInventory.count
                let canAdd = entitlementService.canAddInventoryItem(currentCount: currentInventoryCount)

                await MainActor.run {
                    if !canAdd {
                        // Hit the limit - show upgrade prompt immediately
                        let limit = entitlementService.getInventoryLimit() ?? 0
                        inventoryItemCount = currentInventoryCount
                        inventoryItemLimit = limit
                        showingUpgradePrompt = true
                    } else {
                        // Under limit - show add inventory form
                        showingAddInventory = true
                    }
                }
            } catch {
                // If we can't check the limit, allow the add to proceed
                print("⚠️ Failed to check inventory limit: \(error)")
                await MainActor.run {
                    showingAddInventory = true
                }
            }
        }
    }

    @ViewBuilder
    private var groupedByLocationView: some View {
        ForEach(Array(item.inventoryByLocation.keys.sorted()), id: \.self) { locationKey in
            let records = item.inventory.filter { ($0.location ?? "No location") == locationKey }
            let locationQuantity = records.reduce(0.0) { $0 + $1.quantity }

            Section(header: Text(locationKey)) {
                ForEach(records, id: \.id) { record in
                    InventoryRecordRow(
                        record: record,
                        onDelete: {
                            deleteRecord(record)
                        },
                        showType: true,  // Show type when grouped by location
                        onTap: {
                            editingRecord = record
                        }
                    )
                }

                // Summary for this location
                HStack {
                    Text("Subtotal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatQuantity(locationQuantity))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var groupedByTypeView: some View {
        ForEach(Array(item.inventoryByType.keys.sorted()), id: \.self) { type in
            let records = item.inventory.filter { $0.type == type }
            let typeQuantity = records.reduce(0.0) { $0 + $1.quantity }

            Section(header: Text(type.capitalized)) {
                ForEach(records, id: \.id) { record in
                    InventoryRecordRow(
                        record: record,
                        onDelete: {
                            deleteRecord(record)
                        },
                        showLocation: true,  // Show location when grouped by type
                        onTap: {
                            editingRecord = record
                        }
                    )
                }

                // Summary for this type
                HStack {
                    Text("Subtotal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatQuantity(typeQuantity))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var totalQuantity: Double {
        item.inventory.reduce(0.0) { $0 + $1.quantity }
    }

    private func deleteRecord(_ record: InventoryModel) {
        Task {
            do {
                try await inventoryRepository.deleteInventory(id: record.id)
                print("✅ Deleted inventory record: \(record.id)")
                // Parent view will refresh on sheet dismiss via onDisappear callback
            } catch {
                print("Error deleting inventory record: \(error)")
            }
        }
    }

    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}
