//
//  MockUserNotesRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import Foundation

/// Mock implementation of UserNotesRepository for testing
/// Provides in-memory storage for user notes with realistic behavior
class MockUserNotesRepository: @unchecked Sendable, UserNotesRepository {

    // MARK: - Test Data Storage

    private var notes: [String: UserNotesModel] = [:] // itemNaturalKey -> UserNotesModel
    private let queue = DispatchQueue(label: "mock.usernotes.repository", attributes: .concurrent)

    // MARK: - Test Configuration

    /// Controls whether operations should simulate network delays
    var simulateLatency: Bool = false

    /// Controls whether operations should randomly fail for error testing
    var shouldRandomlyFail: Bool = false

    /// Controls the probability of random failures (0.0 to 1.0)
    var failureProbability: Double = 0.1

    // MARK: - Test State Management

    /// Clear all stored data (useful for test setup)
    nonisolated func clearAllData() {
        queue.async(flags: .barrier) {
            self.notes.removeAll()
        }
    }

    /// Get count of stored notes (for testing)
    nonisolated func getStoredNotesCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.notes.count)
            }
        }
    }

    /// Pre-populate with test data
    func populateWithTestData() async throws {
        let testNotes = [
            UserNotesModel(item_natural_key: "cim-874-0", notes: "This is a nice gray color that works well for backgrounds"),
            UserNotesModel(item_natural_key: "bullseye-001-0", notes: "Clear glass - perfect for overlays"),
            UserNotesModel(item_natural_key: "spectrum-96-0", notes: "White base glass, very opaque")
        ]

        for note in testNotes {
            _ = try await createNotes(note)
        }
    }

    // MARK: - Basic CRUD Operations

    func createNotes(_ notes: UserNotesModel) async throws -> UserNotesModel {
        return try await simulateOperation {
            guard notes.isValid else {
                throw MockUserNotesRepositoryError.invalidData(notes.validationErrors.joined(separator: ", "))
            }

            // Check if notes already exist for this item
            let existing = await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.notes[notes.item_natural_key])
                }
            }

            if existing != nil {
                throw MockUserNotesRepositoryError.notesAlreadyExist(notes.item_natural_key)
            }

            // Create new notes
            let newNotes = UserNotesModel(
                id: notes.id.isEmpty ? UUID().uuidString : notes.id,
                item_natural_key: notes.item_natural_key,
                notes: notes.notes
            )

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.notes[newNotes.item_natural_key] = newNotes
                    continuation.resume()
                }
            }

            return newNotes
        }
    }

    func fetchNotes(forItem itemNaturalKey: String) async throws -> UserNotesModel? {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.notes[itemNaturalKey])
                }
            }
        }
    }

    func updateNotes(_ notes: UserNotesModel) async throws -> UserNotesModel {
        return try await simulateOperation {
            guard notes.isValid else {
                throw MockUserNotesRepositoryError.invalidData(notes.validationErrors.joined(separator: ", "))
            }

            let existing = await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.notes[notes.item_natural_key])
                }
            }

            guard existing != nil else {
                throw MockUserNotesRepositoryError.notesNotFound(notes.item_natural_key)
            }

            let updatedNotes = UserNotesModel(
                id: notes.id,
                item_natural_key: notes.item_natural_key,
                notes: notes.notes
            )

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.notes[updatedNotes.item_natural_key] = updatedNotes
                    continuation.resume()
                }
            }

            return updatedNotes
        }
    }

    func deleteNotes(forItem itemNaturalKey: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.notes.removeValue(forKey: itemNaturalKey)
                    continuation.resume()
                }
            }
        }
    }

    func deleteNotes(byId id: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Find and remove notes by ID
                    if let key = self.notes.first(where: { $0.value.id == id })?.key {
                        self.notes.removeValue(forKey: key)
                    }
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Query Operations

    func fetchAllNotes() async throws -> [UserNotesModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let allNotes = Array(self.notes.values)
                        .sorted { $0.item_natural_key < $1.item_natural_key }
                    continuation.resume(returning: allNotes)
                }
            }
        }
    }

    func fetchNotes(forItems itemNaturalKeys: [String]) async throws -> [String: UserNotesModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    var result: [String: UserNotesModel] = [:]
                    for key in itemNaturalKeys {
                        if let note = self.notes[key] {
                            result[key] = note
                        }
                    }
                    continuation.resume(returning: result)
                }
            }
        }
    }

    func searchNotes(containing searchText: String) async throws -> [UserNotesModel] {
        return try await simulateOperation {
            let lowercaseSearch = searchText.lowercased()

            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let matchingNotes = self.notes.values.filter { note in
                        note.matchesSearchText(lowercaseSearch)
                    }.sorted { $0.item_natural_key < $1.item_natural_key }

                    continuation.resume(returning: Array(matchingNotes))
                }
            }
        }
    }

    func notesExist(forItem itemNaturalKey: String) async throws -> Bool {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.notes[itemNaturalKey] != nil)
                }
            }
        }
    }

    // MARK: - Batch Operations

    func setNotes(_ notes: UserNotesModel) async throws -> UserNotesModel {
        return try await simulateOperation {
            guard notes.isValid else {
                throw MockUserNotesRepositoryError.invalidData(notes.validationErrors.joined(separator: ", "))
            }

            let notesModel = UserNotesModel(
                id: notes.id.isEmpty ? UUID().uuidString : notes.id,
                item_natural_key: notes.item_natural_key,
                notes: notes.notes
            )

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.notes[notesModel.item_natural_key] = notesModel
                    continuation.resume()
                }
            }

            return notesModel
        }
    }

    func deleteAllNotes() async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.notes.removeAll()
                    continuation.resume()
                }
            }
        }
    }

    func getNotesCount() async throws -> Int {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.notes.count)
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    /// Simulate latency and random failures for realistic testing
    private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
        // Simulate random failure if enabled
        if shouldRandomlyFail && Double.random(in: 0...1) < failureProbability {
            throw MockUserNotesRepositoryError.simulatedFailure
        }

        // Simulate network latency if enabled
        if simulateLatency {
            let delay = Double.random(in: 0.01...0.05) // 10-50ms
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        return try await operation()
    }
}

// MARK: - Mock Repository Errors

enum MockUserNotesRepositoryError: Error, LocalizedError {
    case invalidData(String)
    case notesAlreadyExist(String)
    case notesNotFound(String)
    case simulatedFailure

    var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return "Invalid notes data: \(message)"
        case .notesAlreadyExist(let itemKey):
            return "Notes already exist for item: \(itemKey)"
        case .notesNotFound(let itemKey):
            return "Notes not found for item: \(itemKey)"
        case .simulatedFailure:
            return "Simulated repository failure for testing"
        }
    }
}
