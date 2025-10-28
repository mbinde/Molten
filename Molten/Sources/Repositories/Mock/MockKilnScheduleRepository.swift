//
//  MockKilnScheduleRepository.swift
//  Molten
//
//  Mock implementation of KilnScheduleRepository for testing
//

import Foundation

/// Mock implementation of KilnScheduleRepository for testing
actor MockKilnScheduleRepository: KilnScheduleRepository {
    private var schedules: [UUID: KilnSchedule] = [:]

    init() {}

    // MARK: - CRUD Operations

    func createSchedule(_ schedule: KilnSchedule) async throws -> KilnSchedule {
        schedules[schedule.id] = schedule
        return schedule
    }

    func getSchedule(id: UUID) async throws -> KilnSchedule? {
        return schedules[id]
    }

    func getAllSchedules() async throws -> [KilnSchedule] {
        return Array(schedules.values).sorted { $0.dateCreated > $1.dateCreated }
    }

    func updateSchedule(_ schedule: KilnSchedule) async throws {
        guard schedules[schedule.id] != nil else {
            throw KilnScheduleRepositoryError.scheduleNotFound
        }
        schedules[schedule.id] = schedule
    }

    func deleteSchedule(id: UUID) async throws {
        guard schedules[id] != nil else {
            throw KilnScheduleRepositoryError.scheduleNotFound
        }
        schedules.removeValue(forKey: id)
    }

    // MARK: - Business Queries

    func getSchedules(technique: KilnTechnique) async throws -> [KilnSchedule] {
        return Array(schedules.values)
            .filter { $0.technique == technique }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func getSchedulesSortedByName() async throws -> [KilnSchedule] {
        return Array(schedules.values)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Search

    func searchSchedules(query: String) async throws -> [KilnSchedule] {
        let lowercaseQuery = query.lowercased()
        let allSchedules = Array(schedules.values)

        let matches = allSchedules.filter { schedule in
            // Search name
            if schedule.name.lowercased().contains(lowercaseQuery) {
                return true
            }

            // Search notes
            if let notes = schedule.notes, notes.lowercased().contains(lowercaseQuery) {
                return true
            }

            // Search technique
            if schedule.technique.displayName.lowercased().contains(lowercaseQuery) {
                return true
            }

            return false
        }

        return matches.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Test Helpers

    func reset() {
        schedules.removeAll()
    }

    func getScheduleCount() async -> Int {
        return schedules.count
    }
}
