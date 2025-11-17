//
//  LabelPresetRepository.swift
//  Molten
//
//  Protocol defining operations for managing label presets
//

import Foundation

/// Repository protocol for managing label presets
protocol LabelPresetRepository: Sendable {

    // MARK: - Fetch Operations

    /// Fetch all user presets (excludes built-in presets which are code-based)
    func fetchAllPresets() async throws -> [LabelBuilderPreset]

    /// Fetch a specific preset by ID
    func fetchPreset(byId id: UUID) async throws -> LabelBuilderPreset?

    /// Fetch presets matching a predicate
    func fetchPresets(matching predicate: NSPredicate?) async throws -> [LabelBuilderPreset]

    // MARK: - Write Operations

    /// Create a new preset
    func createPreset(_ preset: LabelBuilderPreset) async throws -> LabelBuilderPreset

    /// Update an existing preset
    func updatePreset(_ preset: LabelBuilderPreset) async throws -> LabelBuilderPreset

    /// Delete a preset by ID
    func deletePreset(id: UUID) async throws

    /// Delete multiple presets
    func deletePresets(ids: [UUID]) async throws
}
