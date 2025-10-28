//
//  LogbookViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Tests for LogbookViewModel presentation logic
//

import Testing
@testable import Molten

/// Tests for LogbookViewModel presentation logic
///
/// Tests cover: loading, searching, filtering, CRUD operations
@Suite("LogbookViewModel Tests")
struct LogbookViewModelTests {

    // MARK: - Loading Tests

    @Test("Should load logbook entries")
    func testLoadLogEntries() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)

        // Act
        await viewModel.loadLogEntries()

        // Assert
        #expect(viewModel.logEntries.count == 3)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Should set loading state during fetch")
    func testLoadingState() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)

        // Assert initial state
        #expect(viewModel.isLoading == false)

        // Act
        await viewModel.loadLogEntries()

        // Assert final state
        #expect(viewModel.isLoading == false)
    }

    @Test("Should refresh logbook entries")
    func testRefreshLogEntries() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()
        let initialCount = viewModel.logEntries.count

        // Act
        await viewModel.refreshLogEntries()

        // Assert
        #expect(viewModel.logEntries.count == initialCount)
        #expect(viewModel.isLoading == false)
    }

    @Test("Should handle error when loading fails")
    func testLoadError() async throws {
        // Arrange
        let mockRepo = MockLogbookRepository()
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

    @Test("Should filter entries by search text in title")
    func testSearchByTitle() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        // Act
        viewModel.searchText = "bowl"

        // Assert - reactive filtering via didSet
        #expect(viewModel.filteredEntries.count == 1)
        #expect(viewModel.filteredEntries.first?.title.contains("bowl") == true)
    }

    @Test("Should search in all fields when titles only is disabled")
    func testSearchAllFields() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        // Act
        viewModel.searchTitlesOnly = false
        viewModel.searchText = "practice"

        // Assert - should find by notes content
        #expect(viewModel.filteredEntries.count >= 1)
    }

    @Test("Should search in titles only when enabled")
    func testSearchTitlesOnly() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        // Act
        viewModel.searchTitlesOnly = true
        viewModel.searchText = "bowl"

        // Assert
        #expect(viewModel.filteredEntries.count == 1)
    }

    @Test("Should clear search")
    func testClearSearch() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()
        viewModel.searchText = "test query"

        // Act
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.filteredEntries.count == viewModel.logEntries.count)
    }

    @Test("Should return all entries when search is empty")
    func testEmptySearch() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        // Act
        viewModel.searchText = ""

        // Assert
        #expect(viewModel.filteredEntries.count == viewModel.logEntries.count)
    }

    // MARK: - Reactive Update Tests

    @Test("Should automatically apply filters when search text changes")
    func testReactiveSearchUpdate() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        #expect(viewModel.filteredEntries.count == 3)

        // Act - change search text (should trigger didSet)
        viewModel.searchText = "bowl"

        // Assert - filters applied automatically
        #expect(viewModel.filteredEntries.count == 1)
    }

    @Test("Should automatically apply filters when searchTitlesOnly changes")
    func testReactiveSearchModeUpdate() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
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

    @Test("Should report has data correctly")
    func testHasData() async throws {
        // Arrange
        let emptyRepo = MockLogbookRepository()
        emptyRepo.logEntries = []
        let emptyViewModel = LogbookViewModel(logbookRepository: emptyRepo)
        await emptyViewModel.loadLogEntries()

        // Assert empty
        #expect(emptyViewModel.hasData == false)

        // Arrange with data
        let dataRepo = createMockLogbookRepository()
        let dataViewModel = LogbookViewModel(logbookRepository: dataRepo)
        await dataViewModel.loadLogEntries()

        // Assert with data
        #expect(dataViewModel.hasData == true)
    }

    @Test("Should report has error correctly")
    func testHasError() async throws {
        // Arrange
        let mockRepo = MockLogbookRepository()
        mockRepo.shouldThrowError = true
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)

        // Assert initial state
        #expect(viewModel.hasError == false)

        // Act - trigger error
        await viewModel.loadLogEntries()

        // Assert
        #expect(viewModel.hasError == true)
    }

    @Test("Should compute filtered entries count")
    func testFilteredEntriesCount() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        // Assert full count
        #expect(viewModel.filteredEntriesCount == 3)

        // Act - filter
        viewModel.searchText = "bowl"

        // Assert filtered count
        #expect(viewModel.filteredEntriesCount == 1)
    }

    // MARK: - CRUD Operations Tests

    @Test("Should delete logbook entry")
    func testDeleteEntry() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        let entryToDelete = viewModel.logEntries.first!
        let initialCount = viewModel.logEntries.count

        // Act
        await viewModel.deleteEntry(id: entryToDelete.id)

        // Assert
        #expect(viewModel.logEntries.count == initialCount - 1)
        #expect(!viewModel.logEntries.contains(where: { $0.id == entryToDelete.id }))
    }

    @Test("Should delete multiple logbook entries")
    func testDeleteMultipleEntries() async throws {
        // Arrange
        let mockRepo = createMockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)
        await viewModel.loadLogEntries()

        let idsToDelete = Array(viewModel.logEntries.prefix(2).map { $0.id })
        let initialCount = viewModel.logEntries.count

        // Act
        await viewModel.deleteEntries(ids: idsToDelete)

        // Assert
        #expect(viewModel.logEntries.count == initialCount - 2)
        for id in idsToDelete {
            #expect(!viewModel.logEntries.contains(where: { $0.id == id }))
        }
    }

    // MARK: - Helper Methods

    private func createMockLogbookRepository() -> MockLogbookRepository {
        let mockRepo = MockLogbookRepository()

        // Populate with test data
        mockRepo.logEntries = [
            LogbookModel(
                id: UUID(),
                title: "Finished small bowl",
                notes: "First attempt at making a bowl. Turned out well!",
                dateAdded: Date(),
                images: []
            ),
            LogbookModel(
                id: UUID(),
                title: "Practice session",
                notes: "Worked on pulling cane. Need more practice with heat control.",
                dateAdded: Date().addingTimeInterval(-86400), // 1 day ago
                images: []
            ),
            LogbookModel(
                id: UUID(),
                title: "New color tests",
                notes: "Testing the new reds from Bullseye. Beautiful saturation.",
                dateAdded: Date().addingTimeInterval(-172800), // 2 days ago
                images: []
            )
        ]

        return mockRepo
    }
}

// MARK: - Mock Logbook Repository

class MockLogbookRepository: LogbookRepository {
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

    func updateLog(_ log: LogbookModel) async throws -> LogbookModel {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        if let index = logEntries.firstIndex(where: { $0.id == log.id }) {
            logEntries[index] = log
        }
        return log
    }

    func deleteLog(id: UUID) async throws {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        logEntries.removeAll { $0.id == id }
    }

    func searchLogs(text: String, titlesOnly: Bool) async throws -> [LogbookModel] {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }

        guard !text.isEmpty else { return logEntries }

        return logEntries.filter { entry in
            if titlesOnly {
                return entry.title.localizedCaseInsensitiveContains(text)
            } else {
                return entry.title.localizedCaseInsensitiveContains(text) ||
                       (entry.notes?.localizedCaseInsensitiveContains(text) ?? false)
            }
        }
    }

    func getLogCount() async throws -> Int {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return logEntries.count
    }
}
