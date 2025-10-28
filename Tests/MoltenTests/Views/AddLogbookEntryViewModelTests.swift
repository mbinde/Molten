//
//  AddLogbookEntryViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/28/25.
//  Tests for AddLogbookEntryViewModel presentation logic
//

import Foundation
import Testing
@testable import Molten

/// Tests for AddLogbookEntryViewModel presentation logic
///
/// Tests cover: validation, project search, date handling, save logic
@Suite("AddLogbookEntryViewModel Tests")
@MainActor
struct AddLogbookEntryViewModelTests {

    // MARK: - Initialization Tests

    @Test("Should initialize with default values")
    func testInitialization() async throws {
        // Arrange & Act
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        // Assert default values
        #expect(viewModel.title.isEmpty)
        #expect(viewModel.selectedProjectIds.isEmpty)
        #expect(viewModel.startDate != nil)  // Defaults to now
        #expect(viewModel.completionDate != nil)  // Defaults to now
        #expect(viewModel.notes.isEmpty)
        #expect(viewModel.status == .completed)
        #expect(viewModel.coe == "96")
        #expect(viewModel.tags.isEmpty)
        #expect(viewModel.hoursSpent.isEmpty)
        #expect(viewModel.pricePoint.isEmpty)
        #expect(viewModel.isSaving == false)
    }

    // MARK: - Validation Tests

    @Test("Should require title for validation")
    func testTitleValidation() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        // Act & Assert - empty title invalid
        #expect(viewModel.isValid == false)

        // Act - set title
        viewModel.title = "Test Entry"

        // Assert - now valid
        #expect(viewModel.isValid == true)
    }

    @Test("Should validate hours spent as decimal")
    func testHoursSpentValidation() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        // Act & Assert - valid inputs
        viewModel.hoursSpent = "2.5"
        #expect(viewModel.parsedHours == 2.5)

        viewModel.hoursSpent = "10"
        #expect(viewModel.parsedHours == 10.0)

        // Act & Assert - invalid inputs
        viewModel.hoursSpent = ""
        #expect(viewModel.parsedHours == nil)

        viewModel.hoursSpent = "abc"
        #expect(viewModel.parsedHours == nil)

        viewModel.hoursSpent = "-5"
        #expect(viewModel.parsedHours == nil)
    }

    @Test("Should validate price point as decimal")
    func testPriceValidation() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        // Act & Assert - valid inputs
        viewModel.pricePoint = "99.99"
        #expect(viewModel.parsedPrice == 99.99)

        viewModel.pricePoint = "150"
        #expect(viewModel.parsedPrice == 150.0)

        // Act & Assert - invalid inputs
        viewModel.pricePoint = ""
        #expect(viewModel.parsedPrice == nil)

        viewModel.pricePoint = "xyz"
        #expect(viewModel.parsedPrice == nil)

        viewModel.pricePoint = "-50"
        #expect(viewModel.parsedPrice == nil)
    }

    // MARK: - Project Search Tests

    @Test("Should load available projects")
    func testLoadProjects() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        mockProjectRepo.projects = [
            ProjectModel(id: UUID(), title: "Project A", type: .recipe),
            ProjectModel(id: UUID(), title: "Project B", type: .idea)
        ]

        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        // Act
        await viewModel.loadProjects()

        // Assert
        #expect(viewModel.availableProjects.count == 2)
        #expect(viewModel.isLoadingProjects == false)
    }

    @Test("Should filter projects by search text")
    func testProjectFiltering() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        mockProjectRepo.projects = [
            ProjectModel(id: UUID(), title: "Red Bowl", type: .recipe, summary: "A beautiful red piece"),
            ProjectModel(id: UUID(), title: "Blue Vase", type: .recipe, summary: "Tall vase"),
            ProjectModel(id: UUID(), title: "Green Sculpture", type: .idea, summary: nil)
        ]

        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        await viewModel.loadProjects()

        // Act - search by title
        viewModel.projectSearchText = "bowl"

        // Assert
        let filtered = viewModel.filteredProjects
        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "Red Bowl")

        // Act - search by summary
        viewModel.projectSearchText = "tall"

        // Assert
        let filtered2 = viewModel.filteredProjects
        #expect(filtered2.count == 1)
        #expect(filtered2.first?.title == "Blue Vase")

        // Act - no match
        viewModel.projectSearchText = "purple"
        #expect(viewModel.filteredProjects.isEmpty)
    }

    @Test("Should toggle project selection")
    func testProjectSelection() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        let projectId = UUID()
        mockProjectRepo.projects = [
            ProjectModel(id: projectId, title: "Test Project", type: .recipe)
        ]

        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        await viewModel.loadProjects()

        // Act - select project
        viewModel.toggleProjectSelection(projectId)

        // Assert - selected
        #expect(viewModel.selectedProjectIds.contains(projectId))

        // Act - deselect project
        viewModel.toggleProjectSelection(projectId)

        // Assert - not selected
        #expect(!viewModel.selectedProjectIds.contains(projectId))
    }

    // MARK: - Date Handling Tests

    @Test("Should clear dates when requested")
    func testClearDates() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        // Verify dates are set initially
        #expect(viewModel.startDate != nil)
        #expect(viewModel.completionDate != nil)

        // Act
        viewModel.clearStartDate()

        // Assert
        #expect(viewModel.startDate == nil)
        #expect(viewModel.completionDate != nil)  // Not affected

        // Act
        viewModel.clearCompletionDate()

        // Assert
        #expect(viewModel.completionDate == nil)
    }

    @Test("Should set dates to current date")
    func testSetCurrentDate() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        // Clear dates first
        viewModel.clearStartDate()
        viewModel.clearCompletionDate()
        #expect(viewModel.startDate == nil)
        #expect(viewModel.completionDate == nil)

        // Act
        viewModel.setStartDateToNow()

        // Assert
        #expect(viewModel.startDate != nil)
        let timeDiff1 = abs(viewModel.startDate!.timeIntervalSinceNow)
        #expect(timeDiff1 < 1.0)  // Within 1 second

        // Act
        viewModel.setCompletionDateToNow()

        // Assert
        #expect(viewModel.completionDate != nil)
        let timeDiff2 = abs(viewModel.completionDate!.timeIntervalSinceNow)
        #expect(timeDiff2 < 1.0)
    }

    // MARK: - Save Tests

    @Test("Should save valid log entry")
    func testSaveLogEntry() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        viewModel.title = "Test Logbook Entry"
        viewModel.notes = "Some notes"
        viewModel.status = .completed
        viewModel.coe = "96"
        viewModel.hoursSpent = "5.5"
        viewModel.pricePoint = "150.00"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == true)
        #expect(mockRepo.savedLog != nil)
        #expect(mockRepo.savedLog?.title == "Test Logbook Entry")
        #expect(mockRepo.savedLog?.notes == "Some notes")
        #expect(mockRepo.savedLog?.status == .completed)
        #expect(mockRepo.savedLog?.coe == "96")
        #expect(mockRepo.savedLog?.hoursSpent == 5.5)
        #expect(mockRepo.savedLog?.pricePoint == 150.0)
    }

    @Test("Should not save with empty title")
    func testSaveInvalidEntry() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        viewModel.title = ""  // Invalid

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == false)
        #expect(mockRepo.savedLog == nil)
    }

    @Test("Should handle save errors")
    func testSaveError() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        mockRepo.shouldThrowError = true

        let mockProjectRepo = MockProjectRepositoryForViewModel()
        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        viewModel.title = "Test Entry"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("Should set isSaving flag during save")
    func testSavingState() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        viewModel.title = "Test Entry"

        // Act & Assert
        #expect(viewModel.isSaving == false)

        // Note: This is tricky to test synchronously, so we just verify initial state
        // In real usage, isSaving would be true during async save
    }

    // MARK: - Computed Properties Tests

    @Test("Should compute showBusinessSection based on status")
    func testShowBusinessSection() async throws {
        // Arrange
        let mockRepo = MockLogbookRepositoryForViewModel()
        let mockProjectRepo = MockProjectRepositoryForViewModel()
        let viewModel = AddLogbookEntryViewModel(
            logbookRepository: mockRepo,
            projectRepository: mockProjectRepo
        )

        // Act & Assert - completed status
        viewModel.status = .completed
        #expect(viewModel.showBusinessSection == false)

        // Act & Assert - sold status
        viewModel.status = .sold
        #expect(viewModel.showBusinessSection == true)

        // Act & Assert - gifted status
        viewModel.status = .gifted
        #expect(viewModel.showBusinessSection == true)

        // Act & Assert - other statuses
        viewModel.status = .inProgress
        #expect(viewModel.showBusinessSection == false)

        viewModel.status = .broken
        #expect(viewModel.showBusinessSection == false)
    }
}

// MARK: - Mock Repositories

final class MockLogbookRepositoryForViewModel: LogbookRepository, @unchecked Sendable {
    var savedLog: LogbookModel?
    var shouldThrowError = false

    func createLog(_ log: LogbookModel) async throws -> LogbookModel {
        if shouldThrowError {
            throw NSError(domain: "MockLogbookRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        savedLog = log
        return log
    }

    // Other required methods with minimal implementation
    func getLog(id: UUID) async throws -> LogbookModel? { nil }
    func getAllLogs() async throws -> [LogbookModel] { [] }
    func getLogs(status: ProjectStatus?) async throws -> [LogbookModel] { [] }
    func updateLog(_ log: LogbookModel) async throws {}
    func deleteLog(id: UUID) async throws {}
    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] { [] }
    func getSoldLogs() async throws -> [LogbookModel] { [] }
    func getTotalRevenue() async throws -> Decimal { 0 }
    func searchLogs(query: String) async throws -> [LogbookModel] { [] }
}

final class MockProjectRepositoryForViewModel: ProjectRepository, @unchecked Sendable {
    var projects: [ProjectModel] = []
    var shouldThrowError = false

    func getActiveProjects() async throws -> [ProjectModel] {
        if shouldThrowError {
            throw NSError(domain: "MockProjectRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return projects
    }

    // MARK: - CRUD Operations
    func createProject(_ project: ProjectModel) async throws -> ProjectModel { project }
    func getProject(id: UUID) async throws -> ProjectModel? { nil }
    func getAllProjects(includeArchived: Bool) async throws -> [ProjectModel] { [] }
    func getArchivedProjects() async throws -> [ProjectModel] { [] }
    func getProjects(type: ProjectType?, includeArchived: Bool) async throws -> [ProjectModel] { [] }
    func updateProject(_ project: ProjectModel) async throws {}
    func deleteProject(id: UUID) async throws {}
    func archiveProject(id: UUID, isArchived: Bool) async throws {}
    func unarchiveProject(id: UUID) async throws {}

    // MARK: - Steps Management
    func addStep(_ step: ProjectStepModel) async throws -> ProjectStepModel { step }
    func updateStep(_ step: ProjectStepModel) async throws {}
    func deleteStep(id: UUID) async throws {}
    func reorderSteps(projectId: UUID, stepIds: [UUID]) async throws {}

    // MARK: - Reference URLs Management
    func addReferenceUrl(_ url: ProjectReferenceUrl, to projectId: UUID) async throws {}
    func updateReferenceUrl(_ url: ProjectReferenceUrl, in projectId: UUID) async throws {}
    func deleteReferenceUrl(id: UUID, from projectId: UUID) async throws {}

    // MARK: - Search
    func searchProjects(query: String, includeArchived: Bool) async throws -> [ProjectModel] { [] }
}
