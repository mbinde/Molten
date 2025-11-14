//
//  MockUserNotesRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of UserNotesRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of UserNotesRepository for testing
/// Stores notes in memory using a dictionary
final class MockUserNotesRepository: UserNotesRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var notes: [String: UserNotesModel] = [:] // Key: itemStableId

    // MARK: - CRUD Operations

    func createNotes(_ notes: UserNotesModel) async throws -> UserNotesModel {
        let key = notes.item_stable_id
        self.notes[key] = notes
        return notes
    }

    func fetchNotes(forItem itemStableId: String) async throws -> UserNotesModel? {
        return notes[itemStableId]
    }

    func updateNotes(_ notes: UserNotesModel) async throws -> UserNotesModel {
        let key = notes.item_stable_id
        guard self.notes[key] != nil else {
            throw NSError(domain: "MockUserNotesRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Notes not found for item: \(key)"
            ])
        }
        self.notes[key] = notes
        return notes
    }

    func deleteNotes(forItem itemStableId: String) async throws {
        notes.removeValue(forKey: itemStableId)
    }

    func deleteNotes(byId id: String) async throws {
        // Find and delete by id
        if let foundKey = notes.first(where: { (pair: (key: String, value: UserNotesModel)) in pair.value.id == id })?.key {
            notes.removeValue(forKey: foundKey)
        } else {
            throw NSError(domain: "MockUserNotesRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Notes not found with id: \(id)"
            ])
        }
    }

    // MARK: - Query Operations

    func fetchAllNotes() async throws -> [UserNotesModel] {
        return Array(notes.values)
    }

    func fetchNotes(forItems itemStableIds: [String]) async throws -> [String: UserNotesModel] {
        var result: [String: UserNotesModel] = [:]
        for stableId in itemStableIds {
            if let note = notes[stableId] {
                result[stableId] = note
            }
        }
        return result
    }

    func searchNotes(containing searchText: String) async throws -> [UserNotesModel] {
        return notes.values.filter { $0.matchesSearchText(searchText) }
    }

    func notesExist(forItem itemStableId: String) async throws -> Bool {
        return notes[itemStableId] != nil
    }

    // MARK: - Batch Operations

    func setNotes(_ notes: UserNotesModel) async throws -> UserNotesModel {
        // Upsert: create or update
        let key = notes.item_stable_id
        self.notes[key] = notes
        return notes
    }

    func deleteAllNotes() async throws {
        notes.removeAll()
    }

    func getNotesCount() async throws -> Int {
        return notes.count
    }

    // MARK: - Test Helpers

    /// Clear all notes (test helper)
    func clearAll() async {
        notes.removeAll()
    }
}
