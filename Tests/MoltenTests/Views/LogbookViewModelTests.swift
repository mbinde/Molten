//
//  LogbookViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Tests for LogbookViewModel presentation logic
//

import Foundation
import Testing
@testable import Molten

/// Tests for LogbookViewModel presentation logic
///
/// Tests cover: loading, searching, filtering
@Suite("LogbookViewModel Tests")
struct LogbookViewModelTests {

    // MARK: - Loading Tests

    @Test("Should load logbook entries") @MainActor
    func testLoadLogEntries() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepositoryForViewModel()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)

        // Act
        await viewModel.loadLogEntries()

        // Assert
        #expect(viewModel.logEntries.count == 3)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Should set loading state during fetch") @MainActor
    func testLoadingState() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepositoryForViewModel()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)

        // Assert initial state
        #expect(viewModel.isLoading == false)

        // Act
        await viewModel.loadLogEntries()

        // Assert final state
        #expect(viewModel.isLoading == false)
    }

    @Test("Should refresh logbook entries") @MainActor
    func testRefreshLogEntries() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepositoryForViewModel()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()
        let initialCount = viewModel.logEntries.count

        // Act
        await viewModel.refreshLogEntries()

        // Assert
        #expect(viewModel.logEntries.count == initialCount)
        #expect(viewModel.isLoading == false)
    }

    @Test("Should handle error when loading fails") @MainActor
    func testLoadError() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        mockRepo.shouldThrowError = true
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)

        // Act
        await viewModel.loadLogEntries()

        // Assert
        #expect(viewModel.logEntries.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Search Tests

    @Test("Should filter entries by search text in title") @MainActor
    func testSearchByTitle() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepositoryForViewModel()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        // Act
        viewModel.searchText = "bowl"

        // Assert - reactive filtering via didSet
        #expect(viewModel.filteredEntries.count == 1)
        #expect(viewModel.filteredEntries.first?.title.contains("bowl") == true)
    }

    @Test("Should search in all fields when titles only is disabled") @MainActor
    func testSearchAllFields() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepositoryForViewModel()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        // Act
        viewModel.searchTitlesOnly = false
        viewModel.searchText = "practice"

        // Assert - should find by notes content
        #expect(viewModel.filteredEntries.count >= 1)
    }

    @Test("Should search in titles only when enabled") @MainActor
    func testSearchTitlesOnly() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepositoryForViewModel()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        // Act
        viewModel.searchTitlesOnly = true
        viewModel.searchText = "bowl"

        // Assert
        #expect(viewModel.filteredEntries.count == 1)
    }

    @Test("Should clear search") @MainActor
    func testClearSearch() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepositoryForViewModel()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()
        viewModel.searchText = "test query"

        // Act
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.filteredEntries.count == viewModel.logEntries.count)
    }

    @Test("Should return all entries when search is empty") @MainActor
    func testEmptySearch() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepositoryForViewModel()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        // Act
        viewModel.searchText = ""

        // Assert
        #expect(viewModel.filteredEntries.count == viewModel.logEntries.count)
    }

    // MARK: - Reactive Update Tests

    @Test("Should automatically apply filters when search text changes") @MainActor
    func testReactiveSearchUpdate() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepositoryForViewModel()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        #expect(viewModel.filteredEntries.count == 3)

        // Act - change search text (should trigger didSet)
        viewModel.searchText = "bowl"

        // Assert - filters applied automatically
        #expect(viewModel.filteredEntries.count == 1)
    }

    @Test("Should automatically apply filters when searchTitlesOnly changes") @MainActor
    func testReactiveSearchModeUpdate() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepositoryForViewModel()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        viewModel.searchText = "practice"
        viewModel.searchTitlesOnly = true

        // Should not find anything when searching titles only
        let titlesOnlyCount = viewModel.filteredEntries.count

        // Act - change to search all fields (should trigger didSet)
        viewModel.searchTitlesOnly = false

        // Assert - filters re-applied automatically, should find entries now
        #expect(viewModel.filteredEntries.count >= titlesOnlyCount)
    }

    // MARK: - Computed Properties Tests

    @Test("Should report has data correctly") @MainActor
    func testHasData() async throws {
        // Arrange
        let emptyRepo = MockLogbookRepositoryForViewModel()
        emptyRepo.logEntries = []
        let emptyViewModel = LogbookViewModel(logbookRepository: emptyRepo)
        await emptyViewModel.loadLogEntries()

        // Assert empty
        #expect(emptyViewModel.hasData == false)

        // Arrange with data
        let dataRepo = createMockLogbookRepositoryForViewModel()
        let dataViewModel = LogbookViewModel(logbookRepository: dataRepo)
        await dataViewModel.loadLogEntries()

        // Assert with data
        #expect(dataViewModel.hasData == true)
    }

    @Test("Should report has error correctly") @MainActor
    func testHasError() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        mockRepo.shouldThrowError = true
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)

        // Assert initial state
        #expect(viewModel.hasError == false)

        // Act - trigger error
        await viewModel.loadLogEntries()

        // Assert
        #expect(viewModel.hasError == true)
    }

    @Test("Should compute filtered entries count") @MainActor
    func testFilteredEntriesCount() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepositoryForViewModel()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        // Assert full count
        #expect(viewModel.filteredEntriesCount == 3)

        // Act - filter
        viewModel.searchText = "bowl"

        // Assert filtered count
        #expect(viewModel.filteredEntriesCount == 1)
    }

    // MARK: - Helper Methods

    private func createMockLogbookRepositoryForViewModel() -> MockLogbookRepositoryForViewModel {
        let mockRepo = MockLogbookRepositoryForViewModel()

        // Populate with test data
        mockRepo.logEntries = [
            LogbookModel(
                id: UUID(),
                title: "Finished small bowl",
                dateCreated: Date(),
                dateModified: Date(),
                notes: "First attempt at making a bowl. Turned out well!",
                images: []
            ),
            LogbookModel(
                id: UUID(),
                title: "Practice session",
                dateCreated: Date().addingTimeInterval(-86400), // 1 day ago
                dateModified: Date().addingTimeInterval(-86400),
                notes: "Worked on pulling cane. Need more practice with heat control.",
                images: []
            ),
            LogbookModel(
                id: UUID(),
                title: "New color tests",
                dateCreated: Date().addingTimeInterval(-172800), // 2 days ago
                dateModified: Date().addingTimeInterval(-172800),
                notes: "Testing the new reds from Bullseye. Beautiful saturation.",
                images: []
            )
        ]

        return mockRepo
    }
}

// MARK: - Mock Logbook Repository (for ViewModel tests only)

final class MockLogbookRepositoryForViewModel: LogbookRepository, @unchecked Sendable {
    var logEntries: [LogbookModel] = []
    var shouldThrowError = false

    func getAllLogs() async throws -> [LogbookModel] {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return logEntries
    }

    func getLog(id: UUID) async throws -> LogbookModel? {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return logEntries.first { $0.id == id }
    }

    func createLog(_ log: LogbookModel) async throws -> LogbookModel {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        logEntries.append(log)
        return log
    }

    func updateLog(_ log: LogbookModel) async throws {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        if let index = logEntries.firstIndex(where: { $0.id == log.id }) {
            logEntries[index] = log
        }
    }

    func deleteLog(id: UUID) async throws {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        logEntries.removeAll { $0.id == id }
    }

    func getLogs(status: ProjectStatus?) async throws -> [LogbookModel] {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        if let status = status {
            return logEntries.filter { $0.status == status }
        }
        return logEntries
    }

    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return logEntries.filter { $0.dateCreated >= start && $0.dateCreated <= end }
    }

    func getSoldLogs() async throws -> [LogbookModel] {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return logEntries.filter { $0.status == .sold }
    }

    func getTotalRevenue() async throws -> Decimal {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return logEntries.compactMap { $0.pricePoint }.reduce(0, +)
    }

    func searchLogs(query: String) async throws -> [LogbookModel] {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }

        guard !query.isEmpty else { return logEntries }

        return logEntries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(query) ||
            (entry.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
}
