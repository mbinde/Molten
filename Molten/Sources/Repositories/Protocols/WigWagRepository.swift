//
//  WigWagRepository.swift
//  Molten
//
//  Protocols for cane pattern persistence - twist canes, wigwag patterns, and glass palettes
//

import Foundation

// MARK: - TwistCaneRepository

nonisolated protocol TwistCaneRepository: Sendable {
    // MARK: - CRUD Operations

    func create(_ cane: TwistCaneModel) async throws -> TwistCaneModel
    func get(id: UUID) async throws -> TwistCaneModel?
    func getAll() async throws -> [TwistCaneModel]
    func update(_ cane: TwistCaneModel) async throws
    func delete(id: UUID) async throws

    // MARK: - Queries

    /// Get canes sorted by name
    func getAllSortedByName() async throws -> [TwistCaneModel]

    /// Get canes sorted by most recently updated
    func getAllSortedByDate() async throws -> [TwistCaneModel]
}

// MARK: - TwistPatternRepository

nonisolated protocol TwistPatternRepository: Sendable {
    // MARK: - CRUD Operations

    func create(_ pattern: TwistPatternModel) async throws -> TwistPatternModel
    func get(id: UUID) async throws -> TwistPatternModel?
    func getAll() async throws -> [TwistPatternModel]
    func update(_ pattern: TwistPatternModel) async throws
    func delete(id: UUID) async throws

    // MARK: - Queries

    /// Get patterns sorted by name
    func getAllSortedByName() async throws -> [TwistPatternModel]

    /// Get patterns sorted by most recently updated
    func getAllSortedByDate() async throws -> [TwistPatternModel]
}

// MARK: - GlassPaletteRepository

nonisolated protocol GlassPaletteRepository: Sendable {
    // MARK: - CRUD Operations

    func create(_ palette: GlassPaletteModel) async throws -> GlassPaletteModel
    func get(id: UUID) async throws -> GlassPaletteModel?
    func getAll() async throws -> [GlassPaletteModel]
    func update(_ palette: GlassPaletteModel) async throws
    func delete(id: UUID) async throws

    // MARK: - Queries

    /// Get palettes of a specific type (e.g., "wigwag")
    func getByType(_ type: String) async throws -> [GlassPaletteModel]

    /// Get palettes filtered by COE
    func getByCOE(_ coe: Int16) async throws -> [GlassPaletteModel]

    /// Get palettes sorted by name
    func getAllSortedByName() async throws -> [GlassPaletteModel]

    /// Get palettes sorted by most recently updated
    func getAllSortedByDate() async throws -> [GlassPaletteModel]
}

// MARK: - Errors

enum WigWagRepositoryError: LocalizedError {
    case caneNotFound
    case patternNotFound
    case paletteNotFound
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .caneNotFound:
            return "Twist cane not found"
        case .patternNotFound:
            return "Twist pattern not found"
        case .paletteNotFound:
            return "Glass palette not found"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}
