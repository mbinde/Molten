//
//  InventoryTypeRecordsView.swift
//  Molten
//
//  View showing inventory records for a specific type (e.g., all "rod" records)
//  Supports inline editing of quantities and deletion
//

import SwiftUI

/// View showing inventory records for a specific type
/// Displayed when user taps on a type row with multiple records in InventoryStatusCard
struct InventoryTypeRecordsView: View {
    let initialRecords: [InventoryModel]
    let type: String
    let itemName: String

    @Environment(\.dismiss) private var dismiss
    @State private var records: [InventoryModel]
    @State private var quantities: [UUID: Double]  // Track editable quantities separately
    @State private var recordToDelete: InventoryModel?
    @State private var showingDeleteConfirmation = false

    private let inventoryRepository: InventoryRepository

    init(
        records: [InventoryModel],
        type: String,
        itemName: String,
        inventoryRepository: InventoryRepository
    ) {
        self.initialRecords = records
        self.type = type
        self.itemName = itemName
        self.inventoryRepository = inventoryRepository
        self._records = State(initialValue: records)
        // Initialize quantities from records
        var initialQuantities: [UUID: Double] = [:]
        for record in records {
            initialQuantities[record.id] = record.quantity
        }
        self._quantities = State(initialValue: initialQuantities)
    }

    /// Convenience init using AppDependencies
    init(
        records: [InventoryModel],
        type: String,
        itemName: String,
        deps: AppDependencies = .shared
    ) {
        self.init(
            records: records,
            type: type,
            itemName: itemName,
            inventoryRepository: deps.inventoryRepository
        )
    }

    private var displayType: String {
        GlassTerminologySettings.shared.displayName(for: type).capitalized
    }

    private var totalQuantity: Double {
        quantities.values.reduce(0.0, +)
    }

    private var totalContainerCount: Double {
        records.compactMap { $0.containerCount }.reduce(0.0, +)
    }

    var body: some View {
        NavigationStack {
            List {
                // Total summary
                Section {
                    HStack {
                        Text("Total \(displayType)")
                            .font(DesignSystem.Typography.formLabel)
                            .fontWeight(DesignSystem.FontWeight.medium)
                        Spacer()
                        InventoryCountBadge.forInventory(
                            type: type,
                            quantity: totalQuantity,
                            containerCount: totalContainerCount > 0 ? totalContainerCount : nil,
                            style: .large
                        )
                    }
                }

                // Individual records by location
                Section {
                    ForEach(records, id: \.id) { record in
                        InventoryRecordEditRow(
                            record: record,
                            quantity: quantities[record.id] ?? record.quantity,
                            type: type,
                            onQuantityChanged: { newQuantity in
                                updateQuantity(for: record, to: newQuantity)
                            },
                            onDelete: {
                                recordToDelete = record
                                showingDeleteConfirmation = true
                            }
                        )
                    }
                } header: {
                    Text("By Location")
                }
            }
            .navigationTitle(displayType)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Record?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    recordToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let record = recordToDelete {
                        deleteRecord(record)
                    }
                }
            } message: {
                if let record = recordToDelete {
                    Text("Delete \(formatQuantity(quantities[record.id] ?? record.quantity)) \(displayType.lowercased()) from \(record.location ?? "unknown location")?")
                }
            }
        }
    }

    // MARK: - Actions

    private func updateQuantity(for record: InventoryModel, to newQuantity: Double) {
        quantities[record.id] = newQuantity

        // Create updated model and save
        let updatedRecord = InventoryModel(
            id: record.id,
            item_stable_id: record.item_stable_id,
            type: record.type,
            subtype: record.subtype,
            subsubtype: record.subsubtype,
            dimensions: record.dimensions,
            quantity: newQuantity,
            location: record.location,
            date_added: record.date_added,
            date_modified: Date()
        )

        Task {
            do {
                try await inventoryRepository.updateInventory(updatedRecord)
            } catch {
                print("Error saving record: \(error)")
            }
        }
    }

    private func deleteRecord(_ record: InventoryModel) {
        Task {
            do {
                try await inventoryRepository.deleteInventory(id: record.id)
                await MainActor.run {
                    records.removeAll { $0.id == record.id }
                    quantities.removeValue(forKey: record.id)
                    recordToDelete = nil

                    // Dismiss if no records left
                    if records.isEmpty {
                        dismiss()
                    }
                }
            } catch {
                print("Error deleting record: \(error)")
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

// MARK: - Inline Edit Row

/// A row that allows inline editing of quantity with +/- buttons and delete
private struct InventoryRecordEditRow: View {
    let record: InventoryModel
    let quantity: Double
    let type: String
    let onQuantityChanged: (Double) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Location and subtype info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(record.location ?? "No location")
                    .font(DesignSystem.Typography.formLabel)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if let subtype = record.subtype, !subtype.isEmpty {
                    Text(subtype.capitalized)
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            // Quantity controls
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Decrement button
                Button(action: {
                    adjustQuantity(by: -1)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(quantity > 0 ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(quantity <= 0)

                // Quantity display
                Text(formatQuantity(quantity))
                    .font(DesignSystem.Typography.prominentNumber)
                    .fontWeight(DesignSystem.FontWeight.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(minWidth: 40)
                    .multilineTextAlignment(.center)

                // Increment button
                Button(action: {
                    adjustQuantity(by: 1)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                }
                .buttonStyle(.plain)
            }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.accentDanger)
            }
            .buttonStyle(.plain)
            .padding(.leading, DesignSystem.Spacing.sm)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private func adjustQuantity(by amount: Double) {
        let newQuantity = max(0, quantity + amount)
        onQuantityChanged(newQuantity)
    }

    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

// MARK: - Preview

#Preview("Multiple Locations") {
    let sampleRecords = [
        InventoryModel(id: UUID(), item_stable_id: "test", type: "rod", subtype: "standard", quantity: 5, location: "Studio"),
        InventoryModel(id: UUID(), item_stable_id: "test", type: "rod", subtype: "stringer", quantity: 7, location: "Garage"),
        InventoryModel(id: UUID(), item_stable_id: "test", type: "rod", quantity: 3, location: "Cabinet 1")
    ]

    InventoryTypeRecordsView(
        records: sampleRecords,
        type: "rod",
        itemName: "Bullseye Red"
    )
}
