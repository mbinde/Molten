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
    @State private var netChange: Int = 0  // Track +/- changes this session
    @State private var inventoryRecords: [InventoryModel] = []  // Local copy we can mutate
    @State private var availableLocations: [String] = []
    @State private var selectedLocation: String? = nil  // nil = "No location specified"
    @State private var isCreatingNewLocation = false
    @State private var newLocationName = ""
    @State private var isLoading = true
    @State private var actionInProgress = false

    // Sheet breakdown state
    @State private var showingSheetBreakdown = false
    @State private var breakdownPieces: [SheetBreakdownPiece] = []

    private let newLocationSentinel = "__NEW_LOCATION__"

    init(
        item: CompleteInventoryItemModel,
        inventoryType: String? = nil,
        inventorySubtype: String? = nil,
        inventorySubsubtype: String? = nil,
        onViewDetails: @escaping () -> Void,
        deps: AppDependencies = .shared
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
                // Hero image at top
                HeroHeader(item: item.glassItem)

                // View Item Details button below hero
                viewItemDetailsButton
                    .padding(.vertical, DesignSystem.Spacing.md)

                // Type badge and +/- controls
                VStack(spacing: DesignSystem.Spacing.md) {
                    if let typeName = typeDisplayName {
                        Text(typeName)
                            .font(DesignSystem.Typography.listItemTitle)
                            .foregroundColor(DesignSystem.Colors.accentPrimary)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.tintPrimary)
                            .clipShape(Capsule())
                    }

                    // Main +/- controls
                    quantityControls
                }
                .padding(.top, DesignSystem.Spacing.md)

                Divider()

                // Optional location picker
                if !isLoading {
                    locationPicker
                }

                Spacer()

                // Done button
                Button {
                    // Commit any pending new location before dismissing
                    commitPendingNewLocation()

                    // Post notification if changes were made
                    if netChange != 0 {
                        NotificationCenter.default.post(name: .inventoryChanged, object: nil)
                    }
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.accentPrimary)
                .padding()
            }
            .navigationTitle("Manage Inventory")
            .navigationBarTitleDisplayMode(.inline)
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
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                Text("View Item Details")
                    .font(DesignSystem.Typography.listItemTitle)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding()
            .foregroundColor(DesignSystem.Colors.moltenTeal)
        }
        .background(DesignSystem.Colors.tintTeal)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .padding(.horizontal)
    }

    private var typeDisplayName: String? {
        guard let type = inventoryType else { return nil }
        return InventoryTypeEncoder.displayName(type: type, subtype: inventorySubtype, subsubtype: inventorySubsubtype)
    }

    // MARK: - Quantity Controls

    private var quantityControls: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.xl) {
                // Minus button - for sheets, this triggers breakdown UI
                Button {
                    if SheetBreakdownHelper.supportsBreakdown(type: inventoryType, subtype: inventorySubtype) {
                        initiateSheetBreakdown()
                    } else {
                        Task { await decrementInventory() }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.bold())
                        .frame(width: 60, height: 60)
                }
                .buttonStyle(.bordered)
                .tint(DesignSystem.Colors.accentDanger)
                .disabled(actionInProgress || currentQuantity == 0 || showingSheetBreakdown)

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
                .disabled(actionInProgress || showingSheetBreakdown)
            }

            // Net change indicator
            if netChange != 0 && !showingSheetBreakdown {
                Text(netChange > 0 ? "+\(netChange)" : "\(netChange)")
                    .font(DesignSystem.Typography.listItemTitle)
                    .foregroundColor(netChange > 0 ? DesignSystem.Colors.accentSuccess : DesignSystem.Colors.accentDanger)
            }

            // Sheet breakdown UI
            if showingSheetBreakdown {
                sheetBreakdownView
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
    }

    // MARK: - Sheet Breakdown UI

    private var sheetBreakdownView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Text("Break down into:")
                    .font(DesignSystem.Typography.listItemTitle)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Spacer()
                Button("Cancel") {
                    showingSheetBreakdown = false
                    breakdownPieces = []
                }
                .font(DesignSystem.Typography.listItemCaption)
            }
            .padding(.horizontal)

            // Breakdown options
            ForEach($breakdownPieces) { $piece in
                SheetBreakdownRow(
                    piece: $piece,
                    availableLocations: availableLocations
                )
            }

            // Confirm button
            Button {
                Task { await confirmSheetBreakdown() }
            } label: {
                Text("Confirm Breakdown")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.accentPrimary)
            .disabled(actionInProgress)
            .padding(.horizontal)
        }
        .padding()
        .background(DesignSystem.Colors.tintPrimary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .padding(.horizontal)
    }

    /// Initialize breakdown UI with available smaller sizes
    private func initiateSheetBreakdown() {
        let smallerSizes = SheetBreakdownHelper.smallerSubtypes(than: inventorySubtype)
        breakdownPieces = smallerSizes.map { subtype in
            SheetBreakdownPiece(
                subtype: subtype,
                displayName: SheetBreakdownHelper.displayNames[subtype] ?? subtype.capitalized,
                quantity: 0,
                location: selectedLocation  // Default to source location
            )
        }
        showingSheetBreakdown = true
    }

    /// Execute the sheet breakdown: decrement source and add pieces
    @MainActor
    private func confirmSheetBreakdown() async {
        actionInProgress = true
        defer { actionInProgress = false }

        // First decrement the source sheet
        do {
            let result = try await inventoryService.decrementInventoryLIFO(
                forItem: item.glassItem.stable_id,
                type: inventoryType ?? "sheet",
                subtype: inventorySubtype,
                subsubtype: inventorySubsubtype,
                atLocation: selectedLocation
            )

            // Update local records cache
            if let updatedRecord = result {
                if let index = inventoryRecords.firstIndex(where: { $0.id == updatedRecord.id }) {
                    inventoryRecords[index] = updatedRecord
                }
            } else {
                inventoryRecords = try await inventoryService.fetchInventory(forItem: item.glassItem.stable_id)
            }

            currentQuantity = max(0, currentQuantity - 1)
            netChange -= 1

            // Now add the breakdown pieces
            for piece in breakdownPieces where piece.quantity > 0 {
                for _ in 0..<piece.quantity {
                    let newRecord = try await inventoryService.incrementInventory(
                        forItem: item.glassItem.stable_id,
                        type: "sheet",
                        subtype: piece.subtype,
                        subsubtype: nil,
                        atLocation: piece.location
                    )

                    // Update local records
                    if let index = inventoryRecords.firstIndex(where: { $0.id == newRecord.id }) {
                        inventoryRecords[index] = newRecord
                    } else {
                        inventoryRecords.append(newRecord)
                    }
                }
            }

            // Reset breakdown UI
            showingSheetBreakdown = false
            breakdownPieces = []

        } catch {
            print("❌ QRScanInventoryView: Failed to breakdown sheet: \(error)")
        }
    }

    // MARK: - Location Picker

    private var locationPicker: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Location")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            if isCreatingNewLocation {
                // Auto-complete field for new location
                HStack {
                    LocationAutoCompleteField(
                        location: $newLocationName,
                        storageLocationDefinitionRepository: storageLocationDefinitionRepository,
                        placeholder: "Enter new location"
                    )

                    Button("Add") {
                        if !newLocationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let trimmed = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !availableLocations.contains(trimmed) {
                                availableLocations.append(trimmed)
                                availableLocations.sort()
                            }
                            selectedLocation = trimmed
                            newLocationName = ""
                            isCreatingNewLocation = false
                            // Save as last used location
                            UserDefaults.standard.set(trimmed, forKey: Self.lastQRScanLocationKey)
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
                    Text("No location specified").tag(nil as String?)

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
                        // Save as last used location (if not nil)
                        if let loc = newValue {
                            UserDefaults.standard.set(loc, forKey: Self.lastQRScanLocationKey)
                        }
                    }
                }
            }
        }
        .padding()
    }

    // UserDefaults key for last used QR scan location
    private static let lastQRScanLocationKey = "lastQRScanLocation"

    // MARK: - Data Loading

    @MainActor
    private func loadData() async {
        isLoading = true

        // Initialize local copy of inventory records
        inventoryRecords = item.inventory

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

        // Auto-select location based on item's inventory
        selectDefaultLocation()

        recalculateQuantity()
        isLoading = false
    }

    private func selectDefaultLocation() {
        // Get locations that have inventory for this item (matching type if specified)
        let matchingRecords = getMatchingInventoryRecords()
        let itemLocations = Set(matchingRecords.compactMap { $0.location })

        // If only one location, select it
        if itemLocations.count == 1, let onlyLocation = itemLocations.first {
            selectedLocation = onlyLocation
            return
        }

        // If multiple locations, try last used location first
        if let lastUsed = UserDefaults.standard.string(forKey: Self.lastQRScanLocationKey),
           itemLocations.contains(lastUsed) {
            selectedLocation = lastUsed
            return
        }

        // Otherwise, select location with highest count
        if !itemLocations.isEmpty {
            // Group by location and sum quantities
            var locationCounts: [String: Double] = [:]
            for record in matchingRecords {
                if let loc = record.location {
                    locationCounts[loc, default: 0] += record.quantity
                }
            }

            // Find max count, then sort alphabetically among ties
            if let maxCount = locationCounts.values.max() {
                let topLocations = locationCounts
                    .filter { $0.value == maxCount }
                    .keys
                    .sorted()

                if let bestLocation = topLocations.first {
                    selectedLocation = bestLocation
                    return
                }
            }
        }

        // Default: no location specified
        selectedLocation = nil
    }

    private func recalculateQuantity() {
        let matchingRecords = getMatchingInventoryRecords()
        currentQuantity = matchingRecords.reduce(0) { $0 + Int($1.quantity) }
    }

    private func getMatchingInventoryRecords() -> [InventoryModel] {
        inventoryRecords.filter { inv in
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

    // MARK: - Helper Methods

    /// Commits a pending new location name if the user was in the middle of creating one
    private func commitPendingNewLocation() {
        guard isCreatingNewLocation else { return }

        let trimmed = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // Empty location name - just cancel
            isCreatingNewLocation = false
            newLocationName = ""
            return
        }

        // Add to available locations if not already present
        if !availableLocations.contains(trimmed) {
            availableLocations.append(trimmed)
            availableLocations.sort()
        }

        // Select the new location
        selectedLocation = trimmed

        // Save as last used location
        UserDefaults.standard.set(trimmed, forKey: Self.lastQRScanLocationKey)

        // Reset state
        newLocationName = ""
        isCreatingNewLocation = false

        // Recalculate quantity for new location
        recalculateQuantity()
    }

    // MARK: - Inventory Actions

    @MainActor
    private func incrementInventory() async {
        actionInProgress = true
        defer { actionInProgress = false }

        // Commit any pending new location before adding inventory
        commitPendingNewLocation()

        do {
            // Use date-aware increment: finds/creates record for TODAY's date
            let result = try await inventoryService.incrementInventory(
                forItem: item.glassItem.stable_id,
                type: inventoryType ?? "rod",
                subtype: inventorySubtype,
                subsubtype: inventorySubsubtype,
                atLocation: selectedLocation
            )

            // Update local records cache
            if let index = inventoryRecords.firstIndex(where: { $0.id == result.id }) {
                inventoryRecords[index] = result
            } else {
                inventoryRecords.append(result)
            }

            currentQuantity += 1
            netChange += 1
        } catch {
            print("❌ QRScanInventoryView: Failed to increment: \(error)")
        }
    }

    @MainActor
    private func decrementInventory() async {
        actionInProgress = true
        defer { actionInProgress = false }

        // Commit any pending new location before removing inventory
        commitPendingNewLocation()

        // Check if there's any inventory to decrement
        guard currentQuantity > 0 else { return }

        do {
            // Use LIFO decrement: removes from newest record first
            let result = try await inventoryService.decrementInventoryLIFO(
                forItem: item.glassItem.stable_id,
                type: inventoryType ?? "rod",
                subtype: inventorySubtype,
                subsubtype: inventorySubsubtype,
                atLocation: selectedLocation
            )

            // Update local records cache
            if let updatedRecord = result {
                // Record was updated (quantity > 0)
                if let index = inventoryRecords.firstIndex(where: { $0.id == updatedRecord.id }) {
                    inventoryRecords[index] = updatedRecord
                }
            } else {
                // Record was deleted (hit zero) - need to find and remove it
                // Reload from service to sync local state
                inventoryRecords = try await inventoryService.fetchInventory(forItem: item.glassItem.stable_id)
            }

            currentQuantity = max(0, currentQuantity - 1)
            netChange -= 1
        } catch {
            print("❌ QRScanInventoryView: Failed to decrement: \(error)")
        }
    }
}

// MARK: - Sheet Breakdown Support

/// Represents a piece in the sheet breakdown UI
struct SheetBreakdownPiece: Identifiable {
    let id = UUID()
    let subtype: String
    let displayName: String
    var quantity: Int = 0
    var location: String?
}

/// Helper to get smaller sheet subtypes for breakdown
enum SheetBreakdownHelper {
    /// All sheet subtypes in size order (largest to smallest)
    static let sizeOrder = ["full", "half", "12x12", "10x10", "4x4", "other"]

    /// Display names for sheet subtypes
    static let displayNames: [String: String] = [
        "full": "Full Sheet",
        "half": "Half Sheet",
        "12x12": "12×12",
        "10x10": "10×10",
        "4x4": "4×4",
        "other": "Other"
    ]

    /// Get subtypes smaller than the given subtype
    static func smallerSubtypes(than subtype: String?) -> [String] {
        let normalizedSubtype = subtype?.lowercased() ?? "full"
        guard let index = sizeOrder.firstIndex(of: normalizedSubtype) else {
            // Unknown subtype, offer all options
            return sizeOrder
        }
        // Return everything after the current size
        return Array(sizeOrder.dropFirst(index + 1))
    }

    /// Check if this is a sheet type that supports breakdown
    static func supportsBreakdown(type: String?, subtype: String?) -> Bool {
        guard type?.lowercased() == "sheet" else { return false }
        let normalizedSubtype = subtype?.lowercased() ?? "full"
        // "other" can't be broken down further
        return normalizedSubtype != "other"
    }
}

/// Row component for a single breakdown piece option
struct SheetBreakdownRow: View {
    @Binding var piece: SheetBreakdownPiece
    let availableLocations: [String]

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Size label
            Text(piece.displayName)
                .font(DesignSystem.Typography.listItemTitle)
                .frame(width: 80, alignment: .leading)

            // Quantity stepper
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    if piece.quantity > 0 {
                        piece.quantity -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(piece.quantity > 0 ? DesignSystem.Colors.accentDanger : .gray)
                }
                .disabled(piece.quantity == 0)

                Text("\(piece.quantity)")
                    .font(.system(.title3, design: .rounded).bold())
                    .frame(minWidth: 30)

                Button {
                    piece.quantity += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.accentSuccess)
                }
            }

            Spacer()

            // Location picker (compact)
            if !availableLocations.isEmpty {
                Picker("", selection: $piece.location) {
                    Text("—").tag(nil as String?)
                    ForEach(availableLocations, id: \.self) { location in
                        Text(location).tag(location as String?)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 100)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

#Preview {
    Text("QRScanInventoryView Preview")
}
