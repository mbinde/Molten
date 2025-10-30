//
//  KilnSchedulesViewModelProtocol.swift
//  Molten
//
//  Protocol for KilnSchedulesViewModel - enables testability
//

import Foundation

/// Protocol defining the contract for KilnSchedulesViewModel
/// Enables dependency injection and testing
@MainActor
protocol KilnSchedulesViewModelProtocol: AnyObject, Observable {
    // MARK: - State
    var schedules: [KilnSchedule] { get }
    var filteredSchedules: [KilnSchedule] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // MARK: - Search & Filter
    var searchText: String { get set }
    var selectedTechnique: TechniqueType? { get set }
    var sortOption: KilnScheduleSortOption { get set }

    // MARK: - Computed Properties
    var hasData: Bool { get }
    var hasError: Bool { get }
    var groupedSchedules: [TechniqueType?: [KilnSchedule]] { get }
    var availableTechniques: [TechniqueType?] { get }

    // MARK: - Actions
    func loadSchedules() async
    func createSchedule(_ schedule: KilnSchedule) async throws
    func updateSchedule(_ schedule: KilnSchedule) async throws
    func deleteSchedule(_ schedule: KilnSchedule) async throws
    func duplicateSchedule(_ schedule: KilnSchedule, newName: String) async throws -> KilnSchedule
}

/// Sort options for kiln schedules
enum KilnScheduleSortOption: String, CaseIterable {
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case durationShortest = "Duration (Shortest)"
    case durationLongest = "Duration (Longest)"
    case dateCreatedNewest = "Created (Newest)"
    case dateCreatedOldest = "Created (Oldest)"
    case technique = "Technique"

    var displayName: String {
        rawValue
    }
}
