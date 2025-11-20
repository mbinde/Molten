//
//  UserPreferencesRepository.swift
//  Molten
//
//  Repository protocol for user preferences persistence
//  Following CLAUDE.md: "Repositories persist. CRUD operations only."
//

import Foundation

/// Protocol for persisting user preferences (e.g., manufacturer filter)
@MainActor
protocol UserPreferencesRepository {
    /// Get saved manufacturer filter selection
    func getManufacturerFilter() async throws -> Set<String>?

    /// Save manufacturer filter selection
    func saveManufacturerFilter(_ manufacturers: Set<String>) async throws

    /// Clear manufacturer filter (reset to default)
    func clearManufacturerFilter() async throws
}
