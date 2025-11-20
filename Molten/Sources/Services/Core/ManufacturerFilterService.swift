//
//  ManufacturerFilterService.swift
//  Molten
//
//  Service for orchestrating manufacturer filter operations
//  Following CLAUDE.md: "Services orchestrate. NO business logic (delegate to models)."
//

import Foundation
import Combine

/// Service for managing manufacturer filter state and persistence
/// Orchestrates between ManufacturerFilterModel (business logic) and UserPreferencesRepository (persistence)
@MainActor
@Observable
final class ManufacturerFilterService {

    // MARK: - Properties

    private let repository: UserPreferencesRepository
    private var model: ManufacturerFilterModel

    /// Published notification for UI updates
    let filterChanged = PassthroughSubject<Void, Never>()

    // MARK: - Initialization

    /// Initialize with repository and available manufacturers
    /// - Parameters:
    ///   - repository: Repository for persisting preferences
    ///   - availableManufacturers: All manufacturers available in catalog
    init(
        repository: UserPreferencesRepository,
        availableManufacturers: [String]
    ) {
        self.repository = repository

        // Initialize model with empty selection (will load from repository)
        self.model = ManufacturerFilterModel(
            availableManufacturers: availableManufacturers,
            selectedManufacturers: Set()
        )

        // Load saved preferences asynchronously
        Task {
            await loadFromRepository()
        }
    }

    // MARK: - Public API

    /// Currently selected manufacturers
    var selectedManufacturers: Set<String> {
        model.selectedManufacturers
    }

    /// Check if a manufacturer is enabled
    nonisolated func isManufacturerEnabled(_ manufacturer: String) -> Bool {
        return model.isManufacturerEnabled(manufacturer)
    }

    /// Enable a manufacturer
    func enableManufacturer(_ manufacturer: String) async {
        model.enable(manufacturer)
        await persistAndNotify()
    }

    /// Disable a manufacturer
    func disableManufacturer(_ manufacturer: String) async {
        model.disable(manufacturer)
        await persistAndNotify()
    }

    /// Select all manufacturers
    func selectAll() async {
        model.selectAll()
        await persistAndNotify()
    }

    /// Select none (clear all)
    func selectNone() async {
        model.selectNone()
        await persistAndNotify()
    }

    /// Check if an item should be shown based on manufacturer filter
    nonisolated func shouldShowItem(manufacturer: String?) -> Bool {
        return model.shouldShowItem(manufacturer: manufacturer)
    }

    /// Update available manufacturers (e.g., after catalog update)
    func updateAvailableManufacturers(_ manufacturers: [String]) async {
        model.updateAvailableManufacturers(manufacturers)
        await persistAndNotify()
    }

    /// Number of enabled manufacturers
    nonisolated var enabledCount: Int {
        model.enabledCount
    }

    /// Total number of available manufacturers
    nonisolated var totalCount: Int {
        model.totalCount
    }

    /// Check if all manufacturers are selected
    nonisolated var isAllSelected: Bool {
        model.isAllSelected
    }

    /// Check if no manufacturers are selected
    nonisolated var isNoneSelected: Bool {
        model.isNoneSelected
    }

    // MARK: - Private Helpers

    /// Load saved preferences from repository
    private func loadFromRepository() async {
        do {
            let savedSelection = try await repository.getManufacturerFilter()
            model = ManufacturerFilterModel(
                availableManufacturers: model.availableManufacturers,
                selectedManufacturers: savedSelection
            )
            filterChanged.send()
        } catch {
            // If loading fails, keep default (all manufacturers enabled)
            print("Failed to load manufacturer filter preferences: \(error)")
        }
    }

    /// Persist current selection and notify observers
    private func persistAndNotify() async {
        do {
            try await repository.saveManufacturerFilter(model.selectedManufacturers)
            filterChanged.send()
        } catch {
            print("Failed to save manufacturer filter preferences: \(error)")
        }
    }
}
