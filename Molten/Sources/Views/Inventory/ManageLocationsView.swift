//
//  ManageLocationsView.swift
//  Molten
//
//  View for managing storage locations - edit, rename, and delete.
//

import SwiftUI

struct ManageLocationsView: View {
    @Environment(\.dismiss) private var dismiss

    let storageLocationDefinitionRepository: StorageLocationDefinitionRepository
    let storageLocationRepository: StorageLocationRepository
    let inventoryTrackingService: InventoryTrackingService

    /// Callback when locations are modified (renamed, deleted, merged, or added)
    var onLocationsChanged: (() -> Void)?

    @State private var locations: [StorageLocationDefinitionModel] = []
    @State private var isLoading = true

    /// Tracks whether any changes were made during this session
    @State private var hasChanges = false

    // Edit state
    @State private var editingLocationId: UUID?
    @State private var editingName: String = ""

    // Delete state
    @State private var showingDeleteConfirmation = false
    @State private var locationToDelete: StorageLocationDefinitionModel?
    @State private var inventoryCountForDelete: Int = 0
    @State private var reassignDestination: String = ""  // Empty string = "No location"

    // Merge state (when renaming to existing name)
    @State private var showingMergeConfirmation = false
    @State private var mergeSourceLocation: StorageLocationDefinitionModel?
    @State private var mergeTargetName: String = ""
    @State private var mergeItemCount: Int = 0

    // Add state
    @State private var showingAddLocation = false
    @State private var newLocationName = ""

    /// Other locations available for reassignment (excludes the one being deleted)
    private var otherLocations: [String] {
        guard let toDelete = locationToDelete else { return locations.map { $0.name } }
        return locations.filter { $0.id != toDelete.id }.map { $0.name }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading locations...")
                } else if locations.isEmpty {
                    ContentUnavailableView(
                        "No Locations",
                        systemImage: "mappin.slash",
                        description: Text("Add locations to organize your inventory.")
                    )
                } else {
                    locationsList
                }
            }
            .navigationTitle("Manage Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        if hasChanges {
                            onLocationsChanged?()
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddLocation = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await loadLocations()
            }
            .alert("Add Location", isPresented: $showingAddLocation) {
                TextField("Location name", text: $newLocationName)
                Button("Cancel", role: .cancel) {
                    newLocationName = ""
                }
                Button("Add") {
                    Task {
                        await addLocation()
                    }
                }
                .disabled(newLocationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Enter a name for the new location.")
            }
            .confirmationDialog(
                deleteDialogTitle,
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                deleteDialogButtons
            } message: {
                if inventoryCountForDelete > 0 {
                    Text("There \(inventoryCountForDelete == 1 ? "is" : "are") \(inventoryCountForDelete) inventory item\(inventoryCountForDelete == 1 ? "" : "s") assigned to this location. Choose where to move them:")
                }
            }
            .alert(mergeDialogTitle, isPresented: $showingMergeConfirmation) {
                Button("Merge", role: .destructive) {
                    Task { await confirmMerge() }
                }
                Button("Cancel", role: .cancel) {
                    // Stay in editing mode so user can change the name
                }
            } message: {
                if mergeItemCount > 0 {
                    Text("This will move \(mergeItemCount) inventory item\(mergeItemCount == 1 ? "" : "s") to \"\(mergeTargetName)\" and delete \"\(mergeSourceLocation?.name ?? "")\".")
                } else {
                    Text("This will delete \"\(mergeSourceLocation?.name ?? "")\".")
                }
            }
        }
    }

    private var mergeDialogTitle: String {
        "Merge with \"\(mergeTargetName)\"?"
    }

    private var deleteDialogTitle: String {
        if let location = locationToDelete {
            return "Delete \"\(location.name)\"?"
        }
        return "Delete Location?"
    }

    @ViewBuilder
    private var deleteDialogButtons: some View {
        if inventoryCountForDelete > 0 {
            // Has inventory - show reassignment options
            Button("No location") {
                reassignDestination = ""
                Task { await confirmDelete() }
            }

            ForEach(otherLocations, id: \.self) { location in
                Button(location) {
                    reassignDestination = location
                    Task { await confirmDelete() }
                }
            }

            Button("Cancel", role: .cancel) {
                locationToDelete = nil
            }
        } else {
            // No inventory - simple delete
            Button("Delete", role: .destructive) {
                Task { await confirmDelete() }
            }

            Button("Cancel", role: .cancel) {
                locationToDelete = nil
            }
        }
    }

    private var locationsList: some View {
        List {
            ForEach(locations, id: \.id) { location in
                locationRow(location)
            }
        }
    }

    @ViewBuilder
    private func locationRow(_ location: StorageLocationDefinitionModel) -> some View {
        HStack {
            if editingLocationId == location.id {
                // Editing mode
                TextField("Location name", text: $editingName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await saveEdit(location) }
                    }

                Button {
                    Task { await saveEdit(location) }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.accentSuccess)
                }
                .buttonStyle(.plain)

                Button {
                    cancelEdit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                // Display mode
                Text(location.name)
                    .font(DesignSystem.Typography.rowTitle)

                Spacer()

                Button {
                    startEditing(location)
                } label: {
                    Image(systemName: "pencil")
                        .foregroundColor(DesignSystem.Colors.accentSecondary)
                }
                .buttonStyle(.plain)

                Button {
                    prepareDelete(location)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(DesignSystem.Colors.accentDanger)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Edit Actions

    private func startEditing(_ location: StorageLocationDefinitionModel) {
        editingLocationId = location.id
        editingName = location.name
    }

    private func cancelEdit() {
        editingLocationId = nil
        editingName = ""
    }

    private func saveEdit(_ location: StorageLocationDefinitionModel) async {
        let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate
        guard !trimmedName.isEmpty else {
            cancelEdit()
            return
        }

        // If name didn't change, just cancel
        guard trimmedName != location.name else {
            cancelEdit()
            return
        }

        // Check if new name already exists (case-insensitive)
        let existingLocation = locations.first {
            $0.id != location.id && $0.name.lowercased() == trimmedName.lowercased()
        }

        if existingLocation != nil {
            // Name conflict - show merge dialog
            mergeSourceLocation = location
            mergeTargetName = trimmedName

            // Count items that will be moved (count StorageLocation records at this definition)
            do {
                let storageLocations = try await storageLocationRepository.fetchLocations(atLocationDefinition: location.id)
                mergeItemCount = storageLocations.count
            } catch {
                mergeItemCount = 0
            }

            showingMergeConfirmation = true
            return
        }

        // No conflict - proceed with rename
        await performRename(location: location, newName: trimmedName)
    }

    private func performRename(location: StorageLocationDefinitionModel, newName: String) async {
        do {
            // Update the location definition name
            var updatedLocation = location
            updatedLocation.name = newName
            _ = try await storageLocationDefinitionRepository.update(updatedLocation)

            // Update cached locationName in all StorageLocation records pointing to this definition
            let storageLocations = try await storageLocationRepository.fetchLocations(atLocationDefinition: location.id)
            for storageLocation in storageLocations {
                let updatedStorageLocation = StorageLocationModel(
                    id: storageLocation.id,
                    inventoryId: storageLocation.inventoryId,
                    storageLocationId: storageLocation.storageLocationId,
                    locationName: newName,  // Update cached name
                    quantity: storageLocation.quantity,
                    containerCount: storageLocation.containerCount,
                    dateAdded: storageLocation.dateAdded,
                    dateModified: Date(),
                    isTransfer: storageLocation.isTransfer
                )
                _ = try await storageLocationRepository.updateLocation(updatedStorageLocation)
            }

            // Also update Inventory.location for backward compatibility with legacy code
            let allInventory = try await inventoryTrackingService.fetchAllInventory(matching: nil)
            let affectedItems = allInventory.filter { $0.location == location.name }
            for item in affectedItems {
                let updatedItem = InventoryModel(
                    id: item.id,
                    item_stable_id: item.item_stable_id,
                    type: item.type,
                    dimensions: item.dimensions,
                    quantity: item.quantity,
                    containerCount: item.containerCount,
                    location: newName,
                    date_added: item.date_added,
                    date_modified: Date(),
                    workspace_id: item.workspace_id
                )
                // Use repository directly to avoid triggering another StorageLocation sync
                _ = try await inventoryTrackingService.inventoryRepository.updateInventory(updatedItem)
            }

            hasChanges = true
            await loadLocations()
        } catch {
            print("Failed to save location: \(error)")
        }

        cancelEdit()
    }

    private func confirmMerge() async {
        guard let sourceLocation = mergeSourceLocation else { return }

        do {
            // Find the target location definition
            let targetLocation = locations.first { $0.name.lowercased() == mergeTargetName.lowercased() }

            // Update all StorageLocation records to point to target definition
            let storageLocations = try await storageLocationRepository.fetchLocations(atLocationDefinition: sourceLocation.id)
            for storageLocation in storageLocations {
                let updatedStorageLocation = StorageLocationModel(
                    id: storageLocation.id,
                    inventoryId: storageLocation.inventoryId,
                    storageLocationId: targetLocation?.id,  // Point to new definition
                    locationName: mergeTargetName,  // Update cached name
                    quantity: storageLocation.quantity,
                    containerCount: storageLocation.containerCount,
                    dateAdded: storageLocation.dateAdded,
                    dateModified: Date(),
                    isTransfer: storageLocation.isTransfer
                )
                _ = try await storageLocationRepository.updateLocation(updatedStorageLocation)
            }

            // Also update Inventory.location for backward compatibility
            let allInventory = try await inventoryTrackingService.fetchAllInventory(matching: nil)
            let affectedItems = allInventory.filter { $0.location == sourceLocation.name }
            for item in affectedItems {
                let updatedItem = InventoryModel(
                    id: item.id,
                    item_stable_id: item.item_stable_id,
                    type: item.type,
                    dimensions: item.dimensions,
                    quantity: item.quantity,
                    containerCount: item.containerCount,
                    location: mergeTargetName,
                    date_added: item.date_added,
                    date_modified: Date(),
                    workspace_id: item.workspace_id
                )
                _ = try await inventoryTrackingService.inventoryRepository.updateInventory(updatedItem)
            }

            // Delete the source location definition
            try await storageLocationDefinitionRepository.softDelete(id: sourceLocation.id)

            hasChanges = true
            await loadLocations()
        } catch {
            print("Failed to merge locations: \(error)")
        }

        mergeSourceLocation = nil
        mergeTargetName = ""
        cancelEdit()
    }

    // MARK: - Delete Actions

    private func prepareDelete(_ location: StorageLocationDefinitionModel) {
        locationToDelete = location
        reassignDestination = ""

        Task {
            do {
                // Count StorageLocation records at this definition
                let storageLocations = try await storageLocationRepository.fetchLocations(atLocationDefinition: location.id)
                inventoryCountForDelete = storageLocations.count
                showingDeleteConfirmation = true
            } catch {
                inventoryCountForDelete = 0
                showingDeleteConfirmation = true
            }
        }
    }

    private func confirmDelete() async {
        guard let location = locationToDelete else { return }

        do {
            let newLocationName: String? = reassignDestination.isEmpty ? nil : reassignDestination

            // Find the reassignment target location definition (if any)
            let targetLocation = newLocationName.flatMap { name in
                locations.first { $0.name.lowercased() == name.lowercased() }
            }

            // Update all StorageLocation records
            let storageLocations = try await storageLocationRepository.fetchLocations(atLocationDefinition: location.id)
            for storageLocation in storageLocations {
                if let newName = newLocationName {
                    // Reassign to another location
                    let updatedStorageLocation = StorageLocationModel(
                        id: storageLocation.id,
                        inventoryId: storageLocation.inventoryId,
                        storageLocationId: targetLocation?.id,
                        locationName: newName,
                        quantity: storageLocation.quantity,
                        containerCount: storageLocation.containerCount,
                        dateAdded: storageLocation.dateAdded,
                        dateModified: Date(),
                        isTransfer: storageLocation.isTransfer
                    )
                    _ = try await storageLocationRepository.updateLocation(updatedStorageLocation)
                } else {
                    // No location - delete the StorageLocation record
                    try await storageLocationRepository.deleteLocation(storageLocation)
                }
            }

            // Also update Inventory.location for backward compatibility
            let allInventory = try await inventoryTrackingService.fetchAllInventory(matching: nil)
            let affectedItems = allInventory.filter { $0.location == location.name }
            for item in affectedItems {
                let updatedItem = InventoryModel(
                    id: item.id,
                    item_stable_id: item.item_stable_id,
                    type: item.type,
                    dimensions: item.dimensions,
                    quantity: item.quantity,
                    containerCount: item.containerCount,
                    location: newLocationName,
                    date_added: item.date_added,
                    date_modified: Date(),
                    workspace_id: item.workspace_id
                )
                _ = try await inventoryTrackingService.inventoryRepository.updateInventory(updatedItem)
            }

            // Soft-delete the location definition
            try await storageLocationDefinitionRepository.softDelete(id: location.id)

            hasChanges = true
            await loadLocations()
        } catch {
            print("Failed to delete location: \(error)")
        }

        locationToDelete = nil
    }

    // MARK: - Load/Add

    private func loadLocations() async {
        isLoading = true
        do {
            let allLocations = try await storageLocationDefinitionRepository.fetchAll()
            locations = allLocations.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            print("Failed to load locations: \(error)")
            locations = []
        }
        isLoading = false
    }

    private func addLocation() async {
        let trimmedName = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // Check if location already exists
        let existingNames = Set(locations.map { $0.name.lowercased() })
        guard !existingNames.contains(trimmedName.lowercased()) else {
            newLocationName = ""
            return
        }

        do {
            let newLocation = StorageLocationDefinitionModel(name: trimmedName)
            _ = try await storageLocationDefinitionRepository.create(newLocation)
            hasChanges = true
            await loadLocations()
        } catch {
            print("Failed to add location: \(error)")
        }
        newLocationName = ""
    }
}
