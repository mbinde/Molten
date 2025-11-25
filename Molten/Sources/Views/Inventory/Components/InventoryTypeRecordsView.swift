//
//  InventoryTypeRecordsView.swift
//  Molten
//
//  View showing inventory records for a specific type (e.g., all "rod" records)
//  Allows editing individual records
//

import SwiftUI

/// View showing inventory records for a specific type
/// Displayed when user taps on a type row with multiple records in InventoryStatusCard
struct InventoryTypeRecordsView: View {
    let records: [InventoryModel]
    let type: String
    let itemName: String

    @Environment(\.dismiss) private var dismiss
    @State private var editingRecord: InventoryModel?

    private let inventoryRepository: InventoryRepository

    init(
        records: [InventoryModel],
        type: String,
        itemName: String,
        deps: AppDependencies = AppDependencies()
    ) {
        self.records = records
        self.type = type
        self.itemName = itemName
        self.inventoryRepository = deps.inventoryRepository
    }

    private var displayType: String {
        GlassTerminologySettings.shared.displayName(for: type).capitalized
    }

    private var totalQuantity: Double {
        records.reduce(0.0) { $0 + $1.quantity }
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
                            style: .large
                        )
                    }
                }

                // Individual records by location
                Section {
                    ForEach(records, id: \.id) { record in
                        Button(action: {
                            editingRecord = record
                        }) {
                            HStack {
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

                                InventoryCountBadge.forInventory(
                                    type: type,
                                    quantity: record.quantity,
                                    style: .compact
                                )

                                Image(systemName: "chevron.right")
                                    .font(DesignSystem.Typography.listItemCaption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
            .sheet(item: $editingRecord) { record in
                InventoryEditView(
                    record: record,
                    inventoryRepository: inventoryRepository
                )
            }
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
