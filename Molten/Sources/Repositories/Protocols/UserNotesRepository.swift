//
//  UserNotesRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import Foundation

/// Repository protocol for UserNotes data persistence operations
/// Handles user-added notes for glass items
protocol UserNotesRepository {

    // MARK: - Basic CRUD Operations

    /// Create new user notes for an item
    /// - Parameter notes: The UserNotesModel to create
    /// - Returns: The created UserNotesModel with generated ID
    func createNotes(_ notes: UserNotesModel) async throws -> UserNotesModel

    /// Fetch notes for a specific item
    /// - Parameter itemNaturalKey: The natural key of the glass item
    /// - Returns: UserNotesModel if notes exist, nil otherwise
    func fetchNotes(forItem itemNaturalKey: String) async throws -> UserNotesModel?

    /// Update existing notes
    /// - Parameter notes: The updated UserNotesModel
    /// - Returns: The updated UserNotesModel
    func updateNotes(_ notes: UserNotesModel) async throws -> UserNotesModel

    /// Delete notes for a specific item
    /// - Parameter itemNaturalKey: The natural key of the glass item
    func deleteNotes(forItem itemNaturalKey: String) async throws

    /// Delete notes by ID
    /// - Parameter id: The ID of the notes to delete
    func deleteNotes(byId id: String) async throws

    // MARK: - Query Operations

    /// Fetch all user notes
    /// - Returns: Array of all UserNotesModel objects
    func fetchAllNotes() async throws -> [UserNotesModel]

    /// Fetch notes for multiple items
    /// - Parameter itemNaturalKeys: Array of natural keys
    /// - Returns: Dictionary mapping natural keys to their notes
    func fetchNotes(forItems itemNaturalKeys: [String]) async throws -> [String: UserNotesModel]

    /// Search notes by content
    /// - Parameter searchText: Text to search for in notes
    /// - Returns: Array of UserNotesModel objects matching the search
    func searchNotes(containing searchText: String) async throws -> [UserNotesModel]

    /// Check if notes exist for an item
    /// - Parameter itemNaturalKey: The natural key of the glass item
    /// - Returns: True if notes exist, false otherwise
    func notesExist(forItem itemNaturalKey: String) async throws -> Bool

    // MARK: - Batch Operations

    /// Create or update notes (upsert operation)
    /// - Parameter notes: The UserNotesModel to create or update
    /// - Returns: The created or updated UserNotesModel
    func setNotes(_ notes: UserNotesModel) async throws -> UserNotesModel

    /// Delete all notes
    func deleteAllNotes() async throws

    /// Get count of items with notes
    /// - Returns: Number of items that have user notes
    func getNotesCount() async throws -> Int
}
