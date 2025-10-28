//
//  KilnScheduleService.swift
//  Molten
//
//  Service for managing kiln firing schedules
//  Orchestrates KilnScheduleRepository operations
//

import Foundation

/// Service for managing kiln firing schedules
/// Coordinates KilnScheduleRepository operations
/// Follows clean architecture: orchestrates repository, delegates business logic to models
actor KilnScheduleService {

    // MARK: - Dependencies

    private let _repository: KilnScheduleRepository

    // MARK: - Exposed Dependencies for Advanced Operations

    /// Direct access to kiln schedule repository for advanced operations
    nonisolated var repository: KilnScheduleRepository {
        return _repository
    }

    // MARK: - Initialization

    init(repository: KilnScheduleRepository) {
        self._repository = repository
    }

    // MARK: - CRUD Operations

    /// Create a new kiln schedule
    /// - Parameter schedule: The schedule to create
    /// - Returns: The created schedule
    func createSchedule(_ schedule: KilnSchedule) async throws -> KilnSchedule {
        return try await _repository.createSchedule(schedule)
    }

    /// Get a schedule by ID
    /// - Parameter id: The schedule ID
    /// - Returns: The schedule if found, nil otherwise
    func getSchedule(id: UUID) async throws -> KilnSchedule? {
        return try await _repository.getSchedule(id: id)
    }

    /// Get all schedules
    /// - Returns: All schedules sorted by creation date (newest first)
    func getAllSchedules() async throws -> [KilnSchedule] {
        return try await _repository.getAllSchedules()
    }

    /// Update an existing schedule
    /// - Parameter schedule: The schedule with updated values
    func updateSchedule(_ schedule: KilnSchedule) async throws {
        // Update the dateModified before saving
        let updatedSchedule = KilnSchedule(
            id: schedule.id,
            name: schedule.name,
            technique: schedule.technique,
            dateCreated: schedule.dateCreated,
            dateModified: Date(), // Update modification date
            segments: schedule.segments,
            notes: schedule.notes,
            startTemperature: schedule.startTemperature,
            temperatureUnit: schedule.temperatureUnit
        )
        try await _repository.updateSchedule(updatedSchedule)
    }

    /// Delete a schedule
    /// - Parameter id: The schedule ID to delete
    func deleteSchedule(id: UUID) async throws {
        try await _repository.deleteSchedule(id: id)
    }

    // MARK: - Query Operations

    /// Get schedules filtered by technique
    /// - Parameter technique: The technique to filter by
    /// - Returns: Schedules matching the technique, sorted by name
    func getSchedules(technique: KilnTechnique) async throws -> [KilnSchedule] {
        return try await _repository.getSchedules(technique: technique)
    }

    /// Get all schedules sorted by name
    /// - Returns: All schedules sorted alphabetically by name
    func getSchedulesSortedByName() async throws -> [KilnSchedule] {
        return try await _repository.getSchedulesSortedByName()
    }

    // MARK: - Search Operations

    /// Search schedules by name, notes, or technique
    /// - Parameter query: Search text
    /// - Returns: Schedules matching the search query
    func searchSchedules(query: String) async throws -> [KilnSchedule] {
        guard !query.isEmpty else {
            return try await getAllSchedules()
        }
        return try await _repository.searchSchedules(query: query)
    }

    // MARK: - Business Operations

    /// Get schedules grouped by technique
    /// - Returns: Dictionary mapping techniques to their schedules
    func getSchedulesGroupedByTechnique() async throws -> [KilnTechnique: [KilnSchedule]] {
        let allSchedules = try await getAllSchedules()
        var grouped: [KilnTechnique: [KilnSchedule]] = [:]

        for schedule in allSchedules {
            if grouped[schedule.technique] == nil {
                grouped[schedule.technique] = []
            }
            grouped[schedule.technique]?.append(schedule)
        }

        // Sort schedules within each group by name
        for (technique, schedules) in grouped {
            grouped[technique] = schedules.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return grouped
    }

    /// Duplicate a schedule with a new name
    /// - Parameters:
    ///   - scheduleId: ID of the schedule to duplicate
    ///   - newName: Name for the duplicated schedule
    /// - Returns: The newly created duplicate schedule
    func duplicateSchedule(scheduleId: UUID, newName: String) async throws -> KilnSchedule {
        guard let original = try await getSchedule(id: scheduleId) else {
            throw KilnScheduleRepositoryError.scheduleNotFound
        }

        let duplicate = KilnSchedule(
            id: UUID(), // New ID
            name: newName,
            technique: original.technique,
            dateCreated: Date(),
            dateModified: Date(),
            segments: original.segments, // Reuse same segments
            notes: original.notes,
            startTemperature: original.startTemperature,
            temperatureUnit: original.temperatureUnit
        )

        return try await createSchedule(duplicate)
    }
}
