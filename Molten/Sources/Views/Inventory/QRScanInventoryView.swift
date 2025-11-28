//
//  QRScanInventoryView.swift
//  Molten
//
//  Focused inventory management view shown after scanning a QR code.
//  Simple +/- controls with optional location selection.
//

import SwiftUI

/// Focused inventory management view for QR code scans
/// Shows item info and simple +/- buttons with optional location picker
struct QRScanInventoryView: View {
    let item: CompleteInventoryItemModel
    let inventoryType: String?
    let inventorySubtype: String?
    let inventorySubsubtype: String?
    let onViewDetails: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Services
    private let deps: AppDependencies
    private let inventoryService: InventoryTrackingService
    private let storageLocationDefinitionRepository: StorageLocationDefinitionRepository

    // State
    @State private var currentQuantity: Int = 0
    @State private var availableLocations: [String] = []
    @State private var selectedLocation: String? = nil  // nil = "All locations"
    @State private var isCreatingNewLocation = false
    @State private var newLocationName = ""
    @State private var isLoading = true
    @State private var actionInProgress = false

    private let newLocationSentinel = "__NEW_LOCATION__"

    init(
        item: CompleteInventoryItemModel,
        inventoryType: String? = nil,
        inventorySubtype: String? = nil,
        inventorySubsubtype: String? = nil,
        onViewDetails: @escaping () -> Void,
        deps: AppDependencies = AppDependencies()
    ) {
        self.item = item
        self.inventoryType = inventoryType
        self.inventorySubtype = inventorySubtype
        self.inventorySubsubtype = inventorySubsubtype
        self.onViewDetails = onViewDetails
        self.deps = deps
        self.inventoryService = deps.inventoryTrackingService
        self.storageLocationDefinitionRepository = deps.storageLocationDefinitionRepository
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View Item Details button at top
                viewItemDetailsButton

                Divider()

                // Item header
                itemHeader

                Divider()

                // Main +/- controls (always show, don't wait for loading)
                quantityControls

                Divider()

                // Optional location picker
                if !isLoading {
                    locationPicker
                }

                Spacer()
            }
            .navigationTitle("Manage Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - View Item Details Button

    private var viewItemDetailsButton: some View {
        Button {
            onViewDetails()
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                ProductImageThumbnail(
                    itemCode: item.glassItem.stable_id,
                    manufacturer: item.glassItem.manufacturer,
                    stableId: item.glassItem.stable_id,
                    imagePath: item.glassItem.image_path,
                    imageThumbPath: item.glassItem.image_thumb_path,
                    dominantColors: item.glassItem.dominant_colors,
                    size: 32
                )

                Text("View Item Details")
                    .font(DesignSystem.Typography.listItemTitle)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.Spacing.md)
            .foregroundColor(DesignSystem.Colors.moltenTeal)
        }
        .background(DesignSystem.Colors.tintTeal)
    }

    // MARK: - Item Header

    private var itemHeader: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            ProductImageThumbnail(
                itemCode: item.glassItem.stable_id,
                manufacturer: item.glassItem.manufacturer,
                stableId: item.glassItem.stable_id,
                imagePath: item.glassItem.image_path,
                imageThumbPath: item.glassItem.image_thumb_path,
                dominantColors: item.glassItem.dominant_colors,
                size: 60
            )

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(item.glassItem.name)
                    .font(DesignSystem.Typography.sectionTitle)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(GlassManufacturers.fullName(for: item.glassItem.manufacturer) ?? item.glassItem.manufacturer)
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("•")
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("COE \(item.glassItem.coe)")
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                if let typeName = typeDisplayName {
                    Text(typeName)
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.tintPrimary)
                        .clipShape(Capsule())
                }
            }

            Spacer()
        }
        .padding()
        .background(DesignSystem.Colors.backgroundSecondary)
    }

    private var typeDisplayName: String? {
        guard let type = inventoryType else { return nil }
        return InventoryTypeEncoder.displayName(type: type, subtype: inventorySubtype, subsubtype: inventorySubsubtype)
    }

    // MARK: - Quantity Controls

    private var quantityControls: some View {
        HStack(spacing: DesignSystem.Spacing.xl) {
            // Minus button
            Button {
                Task { await decrementInventory() }
            } label: {
                Image(systemName: "minus")
                    .font(.title2.bold())
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.bordered)
            .tint(DesignSystem.Colors.accentDanger)
            .disabled(actionInProgress || currentQuantity == 0)

            // Quantity display
            Text("\(currentQuantity)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(minWidth: 80)

            // Plus button
            Button {
                Task { await incrementInventory() }
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.accentSuccess)
            .disabled(actionInProgress)
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
    }

    // MARK: - Location Picker

    private var locationPicker: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Location")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            if isCreatingNewLocation {
                // Text field for new location
                HStack {
                    TextField("Enter new location", text: $newLocationName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        if !newLocationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let trimmed = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
                            availableLocations.append(trimmed)
                            availableLocations.sort()
                            selectedLocation = trimmed
                            newLocationName = ""
                            isCreatingNewLocation = false
                            // Recalculate quantity for new location (will be 0)
                            recalculateQuantity()
                        }
                    }
                    .disabled(newLocationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Cancel") {
                        newLocationName = ""
                        isCreatingNewLocation = false
                    }
                }
            } else {
                // Picker for existing locations
                Picker("Location", selection: $selectedLocation) {
                    Text("All locations").tag(nil as String?)

                    ForEach(availableLocations, id: \.self) { location in
                        Text(location).tag(location as String?)
                    }

                    Divider()

                    Text("New location...").tag(newLocationSentinel as String?)
                }
                .pickerStyle(.menu)
                .onChange(of: selectedLocation) { _, newValue in
                    if newValue == newLocationSentinel {
                        selectedLocation = nil
                        isCreatingNewLocation = true
                    } else {
                        recalculateQuantity()
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Data Loading

    @MainActor
    private func loadData() async {
        isLoading = true

        // Load available locations from definitions
        if let definitions = try? await storageLocationDefinitionRepository.fetchAll() {
            availableLocations = definitions.map { $0.name }.sorted()
        }

        // Also add any locations from existing inventory that aren't in definitions
        let inventoryLocations = Set(item.inventory.compactMap { $0.location })
        for loc in inventoryLocations {
            if !availableLocations.contains(loc) {
                availableLocations.append(loc)
            }
        }
        availableLocations.sort()

        recalculateQuantity()
        isLoading = false
    }

    private func recalculateQuantity() {
        let matchingRecords = getMatchingInventoryRecords()
        currentQuantity = matchingRecords.reduce(0) { $0 + Int($1.quantity) }
    }

    private func getMatchingInventoryRecords() -> [InventoryModel] {
        item.inventory.filter { inv in
            // Filter by location if one is selected
            if let loc = selectedLocation {
                guard inv.location == loc else { return false }
            }

            // Filter by type if specified from QR code
            guard let type = inventoryType else { return true }
            guard inv.type.lowercased() == type.lowercased() else { return false }

            if let subtype = inventorySubtype {
                guard inv.subtype?.lowercased() == subtype.lowercased() else { return false }

                if let subsubtype = inventorySubsubtype {
                    guard inv.subsubtype?.lowercased() == subsubtype.lowercased() else { return false }
                }
            }

            return true
        }
    }

    // MARK: - Inventory Actions

    @MainActor
    private func incrementInventory() async {
        actionInProgress = true
        defer { actionInProgress = false }

        do {
            // Find existing record to increment, or create new one
            if let existing = getMatchingInventoryRecords().first {
                let updated = InventoryModel(
                    id: existing.id,
                    item_stable_id: existing.item_stable_id,
                    type: existing.type,
                    subtype: existing.subtype,
                    subsubtype: existing.subsubtype,
                    dimensions: existing.dimensions,
                    quantity: existing.quantity + 1,
                    containerCount: existing.containerCount,
                    location: existing.location,
                    date_added: existing.date_added,
                    date_modified: Date()
                )
                _ = try await inventoryService.updateInventory(updated)
            } else {
                // Create new inventory record
                let newInventory = InventoryModel(
                    id: UUID(),
                    item_stable_id: item.glassItem.stable_id,
                    type: inventoryType ?? "rod",
                    subtype: inventorySubtype,
                    subsubtype: inventorySubsubtype,
                    dimensions: nil,
                    quantity: 1,
                    containerCount: nil,
                    location: selectedLocation,
                    date_added: Date(),
                    date_modified: Date()
                )
                _ = try await inventoryService.createInventory(newInventory)
            }

            currentQuantity += 1
        } catch {
            print("❌ QRScanInventoryView: Failed to increment: \(error)")
        }
    }

    @MainActor
    private func decrementInventory() async {
        actionInProgress = true
        defer { actionInProgress = false }

        do {
            guard let existing = getMatchingInventoryRecords().first(where: { $0.quantity > 0 }) else {
                return
            }

            let updated = InventoryModel(
                id: existing.id,
                item_stable_id: existing.item_stable_id,
                type: existing.type,
                subtype: existing.subtype,
                subsubtype: existing.subsubtype,
                dimensions: existing.dimensions,
                quantity: max(0, existing.quantity - 1),
                containerCount: existing.containerCount,
                location: existing.location,
                date_added: existing.date_added,
                date_modified: Date()
            )
            _ = try await inventoryService.updateInventory(updated)

            currentQuantity = max(0, currentQuantity - 1)
        } catch {
            print("❌ QRScanInventoryView: Failed to decrement: \(error)")
        }
    }
}

#Preview {
    Text("QRScanInventoryView Preview")
}
