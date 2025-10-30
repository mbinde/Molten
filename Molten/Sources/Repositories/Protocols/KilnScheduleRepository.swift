//
//  KilnScheduleRepository.swift
//  Molten
//
//  Protocol for kiln schedule data persistence operations
//

import Foundation

nonisolated protocol KilnScheduleRepository: Sendable {
    // MARK: - CRUD Operations

    func createSchedule(_ schedule: KilnSchedule) async throws -> KilnSchedule
    func getSchedule(id: UUID) async throws -> KilnSchedule?
    func getAllSchedules() async throws -> [KilnSchedule]
    func updateSchedule(_ schedule: KilnSchedule) async throws
    func deleteSchedule(id: UUID) async throws

    // MARK: - Business Queries

    /// Get schedules filtered by technique
    /// - Parameter technique: The technique to filter by
    /// - Returns: Schedules matching the technique
    func getSchedules(technique: TechniqueType) async throws -> [KilnSchedule]

    /// Get schedules sorted by name
    /// - Returns: All schedules sorted alphabetically by name
    func getSchedulesSortedByName() async throws -> [KilnSchedule]

    // MARK: - Search

    /// Search schedules by name and notes
    /// - Parameter query: Search text (searches name and notes fields)
    /// - Returns: Schedules matching the search query
    func searchSchedules(query: String) async throws -> [KilnSchedule]
}
