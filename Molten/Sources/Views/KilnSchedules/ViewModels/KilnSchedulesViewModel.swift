//
//  KilnSchedulesViewModel.swift
//  Molten
//
//  ViewModel for the Kiln Schedules view
//

import Foundation
import SwiftUI

/// ViewModel for the Kiln Schedules view
///
/// Manages presentation logic for:
/// - Loading and displaying kiln schedules
/// - Searching and filtering by technique
/// - Sorting schedules
/// - Creating, updating, and deleting schedules
@MainActor
@Observable
class KilnSchedulesViewModel: KilnSchedulesViewModelProtocol {

    // MARK: - Dependencies

    private let kilnScheduleService: KilnScheduleService

    // MARK: - Published State

    var schedules: [KilnSchedule] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Search & Filter State

    var searchText = "" {
        didSet {
            if searchText != oldValue {
                applyFilters()
            }
        }
    }

    var selectedTechnique: KilnTechnique? = nil {
        didSet {
            if selectedTechnique != oldValue {
                applyFilters()
            }
        }
    }

    var sortOption: KilnScheduleSortOption = .nameAscending {
        didSet {
            if sortOption != oldValue {
                applyFilters()
            }
        }
    }

    // MARK: - Filtered State (computed internally)

    private var _filteredSchedules: [KilnSchedule] = []

    var filteredSchedules: [KilnSchedule] {
        _filteredSchedules
    }

    // MARK: - Initialization

    init(kilnScheduleService: KilnScheduleService) {
        self.kilnScheduleService = kilnScheduleService
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        !schedules.isEmpty
    }

    var hasError: Bool {
        errorMessage != nil
    }

    var groupedSchedules: [KilnTechnique: [KilnSchedule]] {
        Dictionary(grouping: filteredSchedules) { $0.technique }
    }

    var availableTechniques: [KilnTechnique] {
        let techniques = Set(schedules.map { $0.technique })
        return Array(techniques).sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Data Loading

    func loadSchedules() async {
        isLoading = true
        errorMessage = nil

        do {
            schedules = try await kilnScheduleService.getAllSchedules()
            applyFilters()
        } catch {
            errorMessage = "Failed to load schedules: \(error.localizedDescription)"
            schedules = []
            _filteredSchedules = []
        }

        isLoading = false
    }

    // MARK: - CRUD Operations

    func createSchedule(_ schedule: KilnSchedule) async throws {
        _ = try await kilnScheduleService.createSchedule(schedule)
        await loadSchedules()
    }

    func updateSchedule(_ schedule: KilnSchedule) async throws {
        try await kilnScheduleService.updateSchedule(schedule)
        await loadSchedules()
    }

    func deleteSchedule(_ schedule: KilnSchedule) async throws {
        try await kilnScheduleService.deleteSchedule(id: schedule.id)
        await loadSchedules()
    }

    func duplicateSchedule(_ schedule: KilnSchedule, newName: String) async throws -> KilnSchedule {
        let duplicated = try await kilnScheduleService.duplicateSchedule(
            scheduleId: schedule.id,
            newName: newName
        )
        await loadSchedules()
        return duplicated
    }

    // MARK: - Filtering & Sorting

    private func applyFilters() {
        var results = schedules

        // Apply technique filter
        if let technique = selectedTechnique {
            results = results.filter { $0.technique == technique }
        }

        // Apply search filter
        if !searchText.isEmpty {
            results = results.filter { schedule in
                schedule.name.localizedCaseInsensitiveContains(searchText) ||
                schedule.technique.displayName.localizedCaseInsensitiveContains(searchText) ||
                (schedule.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Apply sorting
        results = sortSchedules(results, by: sortOption)

        _filteredSchedules = results
    }

    private func sortSchedules(_ schedules: [KilnSchedule], by option: KilnScheduleSortOption) -> [KilnSchedule] {
        switch option {
        case .nameAscending:
            return schedules.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return schedules.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .durationShortest:
            return schedules.sorted { $0.totalDuration < $1.totalDuration }
        case .durationLongest:
            return schedules.sorted { $0.totalDuration > $1.totalDuration }
        case .dateCreatedNewest:
            return schedules.sorted { $0.dateCreated > $1.dateCreated }
        case .dateCreatedOldest:
            return schedules.sorted { $0.dateCreated < $1.dateCreated }
        case .technique:
            return schedules.sorted {
                if $0.technique == $1.technique {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.technique.displayName < $1.technique.displayName
            }
        }
    }

    // MARK: - Helper Methods

    func clearFilters() {
        searchText = ""
        selectedTechnique = nil
        sortOption = .nameAscending
    }
}
