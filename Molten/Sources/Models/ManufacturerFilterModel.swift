//
//  ManufacturerFilterModel.swift
//  Molten
//
//  Business logic for manufacturer filtering
//  Following CLAUDE.md: "Business logic lives in Models"
//

import Foundation

/// Business rules for manufacturer filtering
/// NO dependencies on Services or Repositories
struct ManufacturerFilterModel: Sendable {

    // MARK: - Properties

    /// All available manufacturers in the catalog
    private(set) var availableManufacturers: [String]

    /// Currently selected (enabled) manufacturers
    private(set) var selectedManufacturers: Set<String>

    // MARK: - Initialization

    /// Initialize with available manufacturers and optional selection
    /// - Parameters:
    ///   - availableManufacturers: All manufacturers available in catalog
    ///   - selectedManufacturers: Currently selected manufacturers (nil = default to all)
    init(availableManufacturers: [String], selectedManufacturers: Set<String>?) {
        self.availableManufacturers = availableManufacturers

        if let selected = selectedManufacturers {
            self.selectedManufacturers = selected
        } else {
            // Default: all manufacturers enabled
            self.selectedManufacturers = Set(availableManufacturers)
        }
    }

    // MARK: - Business Logic

    /// Check if a manufacturer is currently enabled
    nonisolated func isManufacturerEnabled(_ manufacturer: String) -> Bool {
        return selectedManufacturers.contains(manufacturer)
    }

    /// Enable a specific manufacturer
    mutating func enable(_ manufacturer: String) {
        selectedManufacturers.insert(manufacturer)
    }

    /// Disable a specific manufacturer
    mutating func disable(_ manufacturer: String) {
        selectedManufacturers.remove(manufacturer)
    }

    /// Select all available manufacturers
    mutating func selectAll() {
        selectedManufacturers = Set(availableManufacturers)
    }

    /// Deselect all manufacturers (clear selection)
    mutating func selectNone() {
        selectedManufacturers.removeAll()
    }

    /// Check if an item should be shown based on its manufacturer
    /// - Parameter manufacturer: The item's manufacturer (nil = always show)
    /// - Returns: True if the item should be visible
    nonisolated func shouldShowItem(manufacturer: String?) -> Bool {
        guard let manufacturer = manufacturer else { return true }
        return isManufacturerEnabled(manufacturer)
    }

    /// Update the list of available manufacturers (e.g., catalog updated)
    /// New manufacturers are enabled by default
    /// Removed manufacturers are cleaned from selection
    mutating func updateAvailableManufacturers(_ manufacturers: [String]) {
        self.availableManufacturers = manufacturers

        let currentSet = Set(manufacturers)
        let newManufacturers = currentSet.subtracting(selectedManufacturers)

        // Remove obsolete manufacturers from selection
        selectedManufacturers = selectedManufacturers.intersection(currentSet)

        // Add new manufacturers (enabled by default)
        selectedManufacturers.formUnion(newManufacturers)
    }

    // MARK: - Computed Properties

    /// Number of currently enabled manufacturers
    nonisolated var enabledCount: Int {
        return selectedManufacturers.count
    }

    /// Total number of available manufacturers
    nonisolated var totalCount: Int {
        return availableManufacturers.count
    }

    /// Check if all manufacturers are selected
    nonisolated var isAllSelected: Bool {
        return selectedManufacturers.count == availableManufacturers.count
    }

    /// Check if no manufacturers are selected
    nonisolated var isNoneSelected: Bool {
        return selectedManufacturers.isEmpty
    }
}
