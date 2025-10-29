//
//  KilnScheduleServiceTests.swift
//  MoltenTests
//
//  Tests for KilnScheduleService
//

import Testing
import Foundation
@testable import Molten

/// Test suite for kiln schedule service operations
@Suite("Kiln Schedule Service Tests")
struct KilnScheduleServiceTests {

    // MARK: - Test Data Helpers

    private func createTestSchedule(
        name: String = "Test Schedule",
        technique: TechniqueType = .fusing
    ) -> KilnSchedule {
        let segments = [
            KilnSegment(targetTemperature: 1000, rampRate: 300),
            KilnSegment(targetTemperature: 1000, holdTime: 15),
            KilnSegment(targetTemperature: 1450, rampRate: 150),
            KilnSegment(targetTemperature: 1450, holdTime: 30)
        ]

        return KilnSchedule(
            name: name,
            technique: technique,
            segments: segments,
            description: "Test notes",
        )
    }

    // MARK: - Service Creation Tests

    @Test("Should create service with repository")
    func testCreateService() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()

        // Act
        let service = KilnScheduleService(repository: repository)

        // Assert
        #expect(service.repository != nil)
    }

    // MARK: - CRUD Operation Tests

    @Test("Should create schedule through service")
    func testCreateSchedule() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let service = KilnScheduleService(repository: repository)
        let schedule = createTestSchedule()

        // Act
        let created = try await service.createSchedule(schedule)

        // Assert
        #expect(created.id == schedule.id)
        #expect(created.name == schedule.name)
    }

    @Test("Should get schedule by ID through service")
    func testGetScheduleById() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let service = KilnScheduleService(repository: repository)
        let schedule = createTestSchedule()
        _ = try await service.createSchedule(schedule)

        // Act
        let retrieved = try await service.getSchedule(id: schedule.id)

        // Assert
        #expect(retrieved != nil)
        #expect(retrieved?.name == "Test Schedule")
    }

    @Test("Should get all schedules through service")
    func testGetAllSchedules() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let service = KilnScheduleService(repository: repository)

        let schedule1 = createTestSchedule(name: "Schedule 1", technique: .fusing)
        let schedule2 = createTestSchedule(name: "Schedule 2", technique: .fusing)
        let schedule3 = createTestSchedule(name: "Schedule 3", technique: .fusing)

        _ = try await service.createSchedule(schedule1)
        _ = try await service.createSchedule(schedule2)
        _ = try await service.createSchedule(schedule3)

        // Act
        let allSchedules = try await service.getAllSchedules()

        // Assert
        #expect(allSchedules.count == 3)
    }

    @Test("Should update schedule through service")
    func testUpdateSchedule() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let service = KilnScheduleService(repository: repository)
        let schedule = createTestSchedule()
        _ = try await service.createSchedule(schedule)

        // Modify the schedule
        let updatedSchedule = KilnSchedule(
            id: schedule.id,
            name: "Updated Schedule",
            technique: schedule.technique,
            segments: schedule.segments,
            description: "Updated notes",
        )

        // Act
        try await service.updateSchedule(updatedSchedule)
        let retrieved = try await service.getSchedule(id: schedule.id)

        // Assert
        #expect(retrieved?.name == "Updated Schedule")
        #expect(retrieved?.description == "Updated notes")
    }

    @Test("Should delete schedule through service")
    func testDeleteSchedule() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let service = KilnScheduleService(repository: repository)
        let schedule = createTestSchedule()
        _ = try await service.createSchedule(schedule)

        // Act
        try await service.deleteSchedule(id: schedule.id)
        let retrieved = try await service.getSchedule(id: schedule.id)

        // Assert
        #expect(retrieved == nil)
    }

    // MARK: - Query Tests

    @Test("Should get schedules by technique through service")
    func testGetSchedulesByTechnique() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let service = KilnScheduleService(repository: repository)

        let fusingSchedule1 = createTestSchedule(name: "Fusing 1", technique: .fusing)
        let fusingSchedule2 = createTestSchedule(name: "Fusing 2", technique: .fusing)
        let slumpingSchedule = createTestSchedule(name: "Slumping", technique: .fusing)

        _ = try await service.createSchedule(fusingSchedule1)
        _ = try await service.createSchedule(fusingSchedule2)
        _ = try await service.createSchedule(slumpingSchedule)

        // Act
        let fusingSchedules = try await service.getSchedules(technique: .fusing)

        // Assert
        #expect(fusingSchedules.count == 2)
        #expect(fusingSchedules.allSatisfy { $0.technique == .fusing })
    }

    @Test("Should get schedules sorted by name through service")
    func testGetSchedulesSortedByName() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let service = KilnScheduleService(repository: repository)

        let scheduleC = createTestSchedule(name: "Charlie Schedule", technique: .fusing)
        let scheduleA = createTestSchedule(name: "Alpha Schedule", technique: .fusing)
        let scheduleB = createTestSchedule(name: "Bravo Schedule", technique: .fusing)

        _ = try await service.createSchedule(scheduleC)
        _ = try await service.createSchedule(scheduleA)
        _ = try await service.createSchedule(scheduleB)

        // Act
        let sorted = try await service.getSchedulesSortedByName()

        // Assert
        #expect(sorted.count == 3)
        #expect(sorted[0].name == "Alpha Schedule")
        #expect(sorted[1].name == "Bravo Schedule")
        #expect(sorted[2].name == "Charlie Schedule")
    }

    // MARK: - Search Tests

    @Test("Should search schedules through service")
    func testSearchSchedules() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let service = KilnScheduleService(repository: repository)

        let schedule1 = createTestSchedule(name: "Full Fuse Schedule", technique: .fusing)
        let schedule2 = createTestSchedule(name: "Tack Fuse Schedule", technique: .fusing)
        let schedule3 = createTestSchedule(name: "Slumping Schedule", technique: .fusing)

        _ = try await service.createSchedule(schedule1)
        _ = try await service.createSchedule(schedule2)
        _ = try await service.createSchedule(schedule3)

        // Act
        let results = try await service.searchSchedules(query: "fuse")

        // Assert
        #expect(results.count == 2)
        #expect(results.contains { $0.name == "Full Fuse Schedule" })
        #expect(results.contains { $0.name == "Tack Fuse Schedule" })
    }

    @Test("Should return empty array for no search matches")
    func testSearchWithNoMatches() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let service = KilnScheduleService(repository: repository)
        let schedule = createTestSchedule()
        _ = try await service.createSchedule(schedule)

        // Act
        let results = try await service.searchSchedules(query: "nonexistent")

        // Assert
        #expect(results.isEmpty)
    }
}
