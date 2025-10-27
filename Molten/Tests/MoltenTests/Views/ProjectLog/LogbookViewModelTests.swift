//
//  LogbookViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  TDD tests for LogbookViewModel - Protocol-based testability
//

import Foundation
import Testing
@testable import Molten

@Suite("LogbookViewModel Tests - Protocol-Based Design")
@MainActor
struct LogbookViewModelTests {

    // MARK: - Mock-Based Tests (Protocol-Based Design)

    @Test("Mock: Should initialize with empty state")
    func testMockEmptyState() async throws {
        // Arrange & Act
        let viewModel = MockLogbookViewModel(scenario: .empty)

        // Assert
        #expect(viewModel.logEntries.isEmpty)
        #expect(viewModel.filteredEntries.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.hasData)
    }

    @Test("Mock: Should initialize with loaded data")
    func testMockLoadedState() async throws {
        // Arrange & Act
        let viewModel = MockLogbookViewModel(scenario: .loaded)

        // Assert
        #expect(viewModel.logEntries.count == 3)
        #expect(viewModel.filteredEntries.count == 3)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasData)
    }

    @Test("Mock: Should initialize with loading state")
    func testMockLoadingState() async throws {
        // Arrange & Act
        let viewModel = MockLogbookViewModel(scenario: .loading)

        // Assert
        #expect(viewModel.isLoading)
        #expect(!viewModel.hasData)
    }

    @Test("Mock: Should initialize with error state")
    func testMockErrorState() async throws {
        // Arrange & Act
        let viewModel = MockLogbookViewModel(scenario: .error)

        // Assert
        #expect(viewModel.hasError)
        #expect(viewModel.errorMessage == "Failed to load logbook entries")
        #expect(!viewModel.hasData)
    }

    @Test("Mock: Should initialize with filtered scenario")
    func testMockFilteredState() async throws {
        // Arrange & Act
        let viewModel = MockLogbookViewModel(scenario: .filtered)

        // Assert
        #expect(viewModel.logEntries.count == 3)
        #expect(viewModel.filteredEntries.count == 1)
        #expect(viewModel.searchText == "Vase")
    }

    @Test("Mock: Should search entries correctly")
    func testMockSearchEntries() async throws {
        // Arrange
        let viewModel = MockLogbookViewModel(scenario: .loaded)

        // Act
        viewModel.searchEntries(text: "Vase")

        // Assert
        #expect(viewModel.searchEntriesCalled)
        #expect(viewModel.searchText == "Vase")
        #expect(viewModel.filteredEntries.count >= 1)
        #expect(viewModel.filteredEntries.allSatisfy { $0.title.contains("Vase") || $0.notes?.contains("vase") == true })
    }

    @Test("Mock: Should search titles only when enabled")
    func testMockSearchTitlesOnly() async throws {
        // Arrange
        let viewModel = MockLogbookViewModel(scenario: .loaded)
        viewModel.searchTitlesOnly = true

        // Act
        viewModel.searchEntries(text: "Vase")

        // Assert
        #expect(viewModel.filteredEntries.count >= 1)
        #expect(viewModel.filteredEntries.allSatisfy { $0.title.contains("Vase") })
    }

    @Test("Mock: Should clear search correctly")
    func testMockClearSearch() async throws {
        // Arrange
        let viewModel = MockLogbookViewModel(scenario: .filtered)
        #expect(viewModel.searchText == "Vase")
        #expect(viewModel.filteredEntries.count == 1)

        // Act
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.clearSearchCalled)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.searchTitlesOnly == false)
        #expect(viewModel.filteredEntries.count == 3)
    }

    @Test("Mock: Should track load and refresh operations")
    func testMockLoadAndRefresh() async throws {
        // Arrange
        let viewModel = MockLogbookViewModel(scenario: .empty)

        // Act
        await viewModel.loadLogEntries()
        await viewModel.refreshLogEntries()

        // Assert
        #expect(viewModel.loadLogEntriesCalled)
        #expect(viewModel.refreshLogEntriesCalled)
    }

    @Test("Mock: Should compute filtered count correctly")
    func testMockFilteredCount() async throws {
        // Arrange
        let viewModel = MockLogbookViewModel(scenario: .loaded)

        // Assert
        #expect(viewModel.filteredEntriesCount == 3)

        // Act - filter with specific search
        viewModel.searchEntries(text: "Pendant")

        // Assert after filtering (only one entry contains "Pendant")
        #expect(viewModel.filteredEntriesCount == 1)
        #expect(viewModel.filteredEntries.first?.title.contains("Pendant") == true)
    }

    // MARK: - Integration Tests (Real Repository)

    @Test("Integration: Should load entries from repository")
    func testLoadEntriesIntegration() async throws {
        // Arrange
        let mockRepo = MockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)

        // Add test data
        let entry = LogbookModel(
            title: "Test Entry",
            tags: ["test"],
            notes: "Test notes",
            status: .inProgress
        )
        _ = try await mockRepo.createLog(entry)

        // Act
        await viewModel.loadLogEntries()

        // Assert
        #expect(viewModel.logEntries.count >= 1)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasData)
    }

    @Test("Integration: Should filter entries by search text")
    func testSearchFilterIntegration() async throws {
        // Arrange
        let mockRepo = MockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)

        // Add test data with different titles
        let entry1 = LogbookModel(title: "Glass Vase", status: .inProgress)
        let entry2 = LogbookModel(title: "Pendant", status: .inProgress)
        _ = try await mockRepo.createLog(entry1)
        _ = try await mockRepo.createLog(entry2)

        await viewModel.loadLogEntries()

        // Act
        viewModel.searchEntries(text: "Vase")

        // Assert
        #expect(viewModel.filteredEntries.count >= 1)
        #expect(viewModel.filteredEntries.allSatisfy { $0.title.contains("Vase") })
    }

    @Test("Integration: Should search titles only when enabled")
    func testSearchTitlesOnlyIntegration() async throws {
        // Arrange
        let mockRepo = MockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)

        // Add entry with search term in notes but not title
        let entry = LogbookModel(title: "Project", notes: "Used a beautiful vase design", status: .inProgress)
        _ = try await mockRepo.createLog(entry)

        await viewModel.loadLogEntries()
        viewModel.searchTitlesOnly = true

        // Act
        viewModel.searchEntries(text: "vase")

        // Assert - should not find it when searching titles only
        #expect(viewModel.filteredEntries.isEmpty)
    }

    @Test("Integration: Should clear search and show all entries")
    func testClearSearchIntegration() async throws {
        // Arrange
        let mockRepo = MockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)

        // Add test data
        let entry1 = LogbookModel(title: "Glass Vase", status: .inProgress)
        let entry2 = LogbookModel(title: "Pendant", status: .inProgress)
        _ = try await mockRepo.createLog(entry1)
        _ = try await mockRepo.createLog(entry2)

        await viewModel.loadLogEntries()
        viewModel.searchEntries(text: "Vase")
        let filteredCount = viewModel.filteredEntries.count

        // Act
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.filteredEntries.count > filteredCount)
        #expect(viewModel.filteredEntries.count == viewModel.logEntries.count)
    }

    @Test("Integration: Should search in tags")
    func testSearchInTagsIntegration() async throws {
        // Arrange
        let mockRepo = MockLogbookRepository()
        let viewModel = LogbookViewModel(logbookRepository: mockRepo)

        // Add entry with specific tag
        let entry = LogbookModel(title: "Project", tags: ["blue", "dichroic"], status: .inProgress)
        _ = try await mockRepo.createLog(entry)

        await viewModel.loadLogEntries()

        // Act
        viewModel.searchEntries(text: "dichroic")

        // Assert
        #expect(viewModel.filteredEntries.count == 1)
        #expect(viewModel.filteredEntries.first?.tags.contains("dichroic") == true)
    }
}
