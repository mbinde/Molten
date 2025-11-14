//
//  MockKilnScheduleRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of KilnScheduleRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of KilnScheduleRepository for testing
/// Stores schedules in memory using a dictionary
@MainActor
final class MockKilnScheduleRepository: KilnScheduleRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var schedules: [UUID: KilnSchedule] = [:] // Key: id

    // MARK: - CRUD Operations

    func createSchedule(_ schedule: KilnSchedule) async throws -> KilnSchedule {
        schedules[schedule.id] = schedule
        return schedule
    }

    func getSchedule(id: UUID) async throws -> KilnSchedule? {
        return schedules[id]
    }

    func getAllSchedules() async throws -> [KilnSchedule] {
        return Array(schedules.values)
    }

    func updateSchedule(_ schedule: KilnSchedule) async throws {
        guard schedules[schedule.id] != nil else {
            throw NSError(domain: "MockKilnScheduleRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Schedule not found: \(schedule.id)"
            ])
        }
        schedules[schedule.id] = schedule
    }

    func deleteSchedule(id: UUID) async throws {
        guard schedules[id] != nil else {
            throw NSError(domain: "MockKilnScheduleRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Schedule not found: \(id)"
            ])
        }
        schedules.removeValue(forKey: id)
    }

    // MARK: - Business Queries

    func getSchedules(technique: TechniqueType) async throws -> [KilnSchedule] {
        var filtered: [KilnSchedule] = []

        for schedule in schedules.values {
            if schedule.technique == technique {
                filtered.append(schedule)
            }
        }

        return filtered
    }

    func getSchedulesSortedByName() async throws -> [KilnSchedule] {
        let schedulesArray = Array(schedules.values)

        // Extract names and pair with schedules for sorting
        var schedulesWithNames: [(schedule: KilnSchedule, name: String)] = []
        for schedule in schedulesArray {
            schedulesWithNames.append((schedule, schedule.name))
        }

        // Sort by name ascending
        schedulesWithNames.sort { $0.name < $1.name }

        return schedulesWithNames.map { $0.schedule }
    }

    // MARK: - Search

    func searchSchedules(query: String) async throws -> [KilnSchedule] {
        let lowercasedQuery = query.lowercased()
        var filtered: [KilnSchedule] = []

        for schedule in schedules.values {
            if schedule.name.lowercased().contains(lowercasedQuery) ||
               (schedule.description?.lowercased().contains(lowercasedQuery) ?? false) {
                filtered.append(schedule)
            }
        }

        return filtered
    }

    // MARK: - Test Helpers

    /// Populate repository with sample test data
    func populateWithTestData() async throws {
        let testSegments = [
            KilnSegment(targetTemperature: 500, rampRate: 100, holdTime: 30),
            KilnSegment(targetTemperature: 750, rampRate: 50, holdTime: 60),
            KilnSegment(targetTemperature: 100, rampRate: 200, holdTime: 0)
        ]

        let testSchedules = [
            KilnSchedule(
                id: UUID(),
                name: "Full Fuse",
                technique: .fusing,
                segments: testSegments,
                description: "Standard full fuse schedule"
            ),
            KilnSchedule(
                id: UUID(),
                name: "Tack Fuse",
                technique: .fusing,
                segments: testSegments,
                description: "Tack fuse schedule"
            ),
            KilnSchedule(
                id: UUID(),
                name: "Slumping",
                technique: .casting,
                segments: testSegments,
                description: "Standard slumping schedule"
            )
        ]

        for schedule in testSchedules {
            _ = try await createSchedule(schedule)
        }
    }

    /// Get count of stored schedules (test helper)
    func getScheduleCount() async -> Int {
        return schedules.count
    }

    /// Clear all schedules (test helper)
    func clearAll() async {
        schedules.removeAll()
    }

    /// Clear all data (test helper, alias for clearAll for consistency)
    nonisolated func clearAllData() {
        schedules.removeAll()
    }
}
