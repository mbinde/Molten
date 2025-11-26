//
//  MockStorageLocationDefinitionRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of StorageLocationDefinitionRepository for testing
//

import Foundation

/// Mock implementation of StorageLocationDefinitionRepository for testing
/// Stores storage location definitions in memory using a dictionary
@MainActor
final class MockStorageLocationDefinitionRepository: StorageLocationDefinitionRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var definitions: [UUID: StorageLocationDefinitionModel] = [:]

    // MARK: - Fetch Operations

    func fetchAll() async throws -> [StorageLocationDefinitionModel] {
        return definitions.values
            .filter { $0.deletedAt == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func fetchAllIncludingDeleted() async throws -> [StorageLocationDefinitionModel] {
        return Array(definitions.values)
    }

    func fetch(byId id: UUID) async throws -> StorageLocationDefinitionModel? {
        return definitions[id]
    }

    func fetch(byName name: String) async throws -> StorageLocationDefinitionModel? {
        let lowercaseName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return definitions.values.first {
            $0.name.lowercased() == lowercaseName && $0.deletedAt == nil
        }
    }

    // MARK: - Create/Update Operations

    func create(_ definition: StorageLocationDefinitionModel) async throws -> StorageLocationDefinitionModel {
        definitions[definition.id] = definition
        return definition
    }

    func update(_ definition: StorageLocationDefinitionModel) async throws -> StorageLocationDefinitionModel {
        guard definitions[definition.id] != nil else {
            throw NSError(domain: "MockStorageLocationDefinitionRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Definition not found"])
        }
        definitions[definition.id] = definition
        return definition
    }

    // MARK: - Delete Operations

    func softDelete(id: UUID) async throws {
        guard var definition = definitions[id] else {
            throw NSError(domain: "MockStorageLocationDefinitionRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Definition not found"])
        }
        definition.deletedAt = Date()
        definitions[id] = definition
    }

    func hardDelete(id: UUID) async throws {
        definitions.removeValue(forKey: id)
    }

    func restore(id: UUID) async throws {
        guard var definition = definitions[id] else {
            throw NSError(domain: "MockStorageLocationDefinitionRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Definition not found"])
        }
        definition.deletedAt = nil
        definitions[id] = definition
    }

    // MARK: - Query Operations

    func getOrCreate(name: String) async throws -> StorageLocationDefinitionModel {
        if let existing = try await fetch(byName: name) {
            return existing
        }
        let newDefinition = StorageLocationDefinitionModel(name: name)
        return try await create(newDefinition)
    }

    func nameExists(_ name: String) async throws -> Bool {
        return try await fetch(byName: name) != nil
    }

    func getUsageCount(for id: UUID) async throws -> Int {
        // In mock, return 0 by default (can be customized for specific tests)
        return 0
    }

    // MARK: - Test Helpers

    /// Populate repository with sample test data
    func populateWithTestData() async throws {
        let testDefinitions = [
            StorageLocationDefinitionModel(name: "Workshop Shelf A"),
            StorageLocationDefinitionModel(name: "Workshop Shelf B"),
            StorageLocationDefinitionModel(name: "Bin 1"),
            StorageLocationDefinitionModel(name: "Bin 2"),
            StorageLocationDefinitionModel(name: "Storage Room")
        ]
        for def in testDefinitions {
            _ = try await create(def)
        }
    }

    /// Get count of stored definitions (test helper)
    func getDefinitionCount() async -> Int {
        return definitions.count
    }

    /// Clear all definitions (test helper)
    func clearAll() async {
        definitions.removeAll()
    }

    /// Clear all data (test helper, alias for clearAll for consistency with other mocks)
    nonisolated func clearAllData() {
        definitions.removeAll()
    }
}
