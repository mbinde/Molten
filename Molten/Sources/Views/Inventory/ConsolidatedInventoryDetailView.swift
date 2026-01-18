//
//  ConsolidatedInventoryDetailView.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//  Repository-based detail view for consolidated inventory items
//  Updated for GlassItem architecture - 10/14/25
//

import SwiftUI

/// Detail view for a consolidated inventory item using new GlassItem architecture
struct ConsolidatedInventoryDetailView: View {
    let glassItem: GlassItemModel
    let inventoryTrackingService: InventoryTrackingService
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var inventoryToDelete: InventoryModel?
    @State private var detailedSummary: DetailedInventorySummaryModel?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    init(glassItem: GlassItemModel, inventoryTrackingService: InventoryTrackingService) {
        self.glassItem = glassItem
        self.inventoryTrackingService = inventoryTrackingService
    }
    
    var body: some View {
        NavigationStack {
            if isLoading {
                LoadingStateView(message: "Loading inventory...")
            } else if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Error loading inventory")
                        .font(.headline)
                    Text(errorMessage)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        loadInventorySummary()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("consolidated_inventory_retry")
                }
                .padding()
            } else {
                List {
                    // Glass Item Info Section
                    Section("Glass Item") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(glassItem.name)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            HStack {
                                Text("Stable ID:")
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Text(glassItem.stable_id)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Manufacturer:")
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Text(GlassManufacturers.fullName(for: glassItem.manufacturer) ?? glassItem.manufacturer)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("COE:")
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Text("\(glassItem.coe)")
                                    .fontWeight(.medium)
                            }

                            // Bundled catalog flags
                            BundledFlagsChipsView(itemStableId: glassItem.stable_id)

                            if let mfr_notes = glassItem.mfr_notes, !mfr_notes.isEmpty {
                                Text(mfr_notes)
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Inventory Summary Section
                    if let detailed = detailedSummary {
                        let summary = detailed.summary
                        Section("Inventory Summary") {
                            HStack(spacing: 24) {
                                InventoryStatView(
                                    title: "Total Quantity", 
                                    count: summary.totalQuantity,
                                    color: .blue,
                                    icon: "archivebox.fill"
                                )
                                
                                InventoryStatView(
                                    title: "Types", 
                                    count: Double(summary.inventoryByType.count),
                                    color: .orange,
                                    icon: "square.stack.3d.up"
                                )
                            }
                        }
                        
                        // Individual Inventory Items Section
                        if summary.inventories.count > 0 {
                            Section("Inventory by Type (\(summary.inventories.count))") {
                                ForEach(summary.inventoryByType.sorted(by: { $0.key < $1.key }), id: \.key) { type, _ in
                                    let inventoryRecords = detailed.inventoryByType[type] ?? []
                                    InventoryTypeRow(type: type, inventoryRecords: inventoryRecords)
                                }
                            }
                        }
                    } else {
                        Section("Inventory") {
                            Text("No inventory found")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .italic()
                        }
                    }
                }
                .navigationTitle("Inventory Details")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                        .accessibilityIdentifier("consolidated_inventory_done")
                    }
                }
            }
        }
        .task {
            loadInventorySummary()
        }
    }
    
    @MainActor
    private func loadInventorySummary() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let detailed = try await inventoryTrackingService.getInventorySummary(for: glassItem.stable_id)
                await MainActor.run {
                    self.detailedSummary = detailed
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InventoryStatView: View {
    let title: String
    let count: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Text(formatQuantity(count))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
    
    private func formatQuantity(_ quantity: Double) -> String {
        if quantity == Double(Int(quantity)) {
            return String(Int(quantity))
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

struct InventoryTypeRow: View {
    let type: String
    let inventoryRecords: [InventoryModel]

    /// Total quantity display combining all records
    private var totalQuantityDisplay: String {
        // If all records are weight-based, aggregate properly
        guard let firstRecord = inventoryRecords.first else { return "0" }

        if firstRecord.isWeightBasedType {
            // Aggregate jars and weight separately
            let totalJars = inventoryRecords.compactMap { $0.containerCount }.reduce(0, +)
            let totalWeight = inventoryRecords.reduce(0.0) { $0 + $1.quantity }
            let hasJars = totalJars > 0
            let hasWeight = totalWeight > 0

            if hasJars && hasWeight {
                let jarText = formatJarCount(totalJars)
                let weightText = formatWeight(totalWeight)
                if ContainerInputModePreference.current == .jars {
                    return "\(jarText) (~\(weightText))"
                } else {
                    return "\(weightText) (\(jarText))"
                }
            } else if hasJars {
                return formatJarCount(totalJars)
            } else if hasWeight {
                return formatWeight(totalWeight)
            } else {
                return "0"
            }
        } else {
            // Non-weight type: sum quantities
            let total = inventoryRecords.reduce(0.0) { $0 + $1.quantity }
            return formatQuantity(total)
        }
    }

    /// Unique locations from inventory records
    private var locations: [String] {
        let allLocations = inventoryRecords.compactMap { $0.location }
        return Array(Set(allLocations)).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.capitalized)
                        .font(.headline)

                    if !locations.isEmpty {
                        Text("\(locations.count) location\(locations.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(totalQuantityDisplay)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.accentColor)
                }
            }

            // Show location breakdown if available
            if !locations.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(locations, id: \.self) { location in
                        let recordsAtLocation = inventoryRecords.filter { $0.location == location }
                        HStack {
                            Text("• \(location)")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text(formatRecordsQuantity(recordsAtLocation))
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatRecordsQuantity(_ records: [InventoryModel]) -> String {
        guard let firstRecord = records.first else { return "0" }

        if firstRecord.isWeightBasedType {
            let totalJars = records.compactMap { $0.containerCount }.reduce(0, +)
            let totalWeight = records.reduce(0.0) { $0 + $1.quantity }
            let hasJars = totalJars > 0
            let hasWeight = totalWeight > 0

            if hasJars && hasWeight {
                let jarText = formatJarCount(totalJars)
                let weightText = formatWeight(totalWeight)
                if ContainerInputModePreference.current == .jars {
                    return "\(jarText) (~\(weightText))"
                } else {
                    return "\(weightText) (\(jarText))"
                }
            } else if hasJars {
                return formatJarCount(totalJars)
            } else if hasWeight {
                return formatWeight(totalWeight)
            } else {
                return "0"
            }
        } else {
            let total = records.reduce(0.0) { $0 + $1.quantity }
            return formatQuantity(total)
        }
    }

    private func formatJarCount(_ count: Double) -> String {
        let countStr = count.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", count)
            : String(format: "%.1f", count)
        let label = count == 1 ? "jar" : "jars"
        return "\(countStr) \(label)"
    }

    private func formatWeight(_ grams: Double) -> String {
        let preferredUnit = WeightUnitPreference.current
        let value: Double
        let unitSymbol: String
        if preferredUnit == .ounces {
            value = grams / 28.3495
            unitSymbol = "oz"
        } else {
            value = grams
            unitSymbol = "g"
        }
        let valueStr = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(valueStr)\(unitSymbol)"
    }

    private func formatQuantity(_ quantity: Double) -> String {
        if quantity == Double(Int(quantity)) {
            return String(Int(quantity))
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleGlassItem = GlassItemModel(
        stable_id: "bullseye-rgr-001-0",
        name: "Red Glass Rod",
        sku: "rgr-001",
        manufacturer: "bullseye",
        mfr_notes: "Beautiful red glass rods perfect for flame working",
        coe: 104,
        url: "https://bullseyeglass.com/products/red-glass-rods",
        mfr_status: "available"
    )

    let deps = AppDependencies(persistenceController: .createTestController())

    ConsolidatedInventoryDetailView(
        glassItem: sampleGlassItem,
        inventoryTrackingService: deps.inventoryTrackingService
    )
}
