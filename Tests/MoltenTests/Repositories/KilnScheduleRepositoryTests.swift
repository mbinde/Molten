//
//  KilnScheduleRepositoryTests.swift
//  MoltenTests
//
//  Tests for KilnScheduleRepository implementations
//

import Testing
import Foundation
@testable import Molten

/// Test suite for kiln schedule repository operations
@Suite("Kiln Schedule Repository Tests")
struct KilnScheduleRepositoryTests {

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
            description: "Test description"
        )
    }

    // MARK: - CRUD Operation Tests

    @Test("Should create schedule")
    func testCreateSchedule() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let schedule = createTestSchedule()

        // Act
        let created = try await repository.createSchedule(schedule)

        // Assert
        #expect(created.id == schedule.id)
        #expect(created.name == schedule.name)
        #expect(await repository.getScheduleCount() == 1)
    }

    @Test("Should get schedule by ID")
    func testGetScheduleById() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let schedule = createTestSchedule()
        _ = try await repository.createSchedule(schedule)

        // Act
        let retrieved = try await repository.getSchedule(id: schedule.id)

        // Assert
        #expect(retrieved != nil)
        #expect(retrieved?.name == "Test Schedule")
    }

    @Test("Should return nil for non-existent schedule")
    func testGetNonExistentSchedule() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let randomId = UUID()

        // Act
        let retrieved = try await repository.getSchedule(id: randomId)

        // Assert
        #expect(retrieved == nil)
    }

    @Test("Should get all schedules")
    func testGetAllSchedules() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let schedule1 = createTestSchedule(name: "Schedule 1", technique: .fusing)
        let schedule2 = createTestSchedule(name: "Schedule 2", technique: .fusing)
        let schedule3 = createTestSchedule(name: "Schedule 3", technique: .fusing)

        _ = try await repository.createSchedule(schedule1)
        _ = try await repository.createSchedule(schedule2)
        _ = try await repository.createSchedule(schedule3)

        // Act
        let allSchedules = try await repository.getAllSchedules()

        // Assert
        #expect(allSchedules.count == 3)
    }

    @Test("Should update schedule")
    func testUpdateSchedule() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let schedule = createTestSchedule()
        _ = try await repository.createSchedule(schedule)

        // Modify the schedule
        let updatedSchedule = KilnSchedule(
            id: schedule.id,
            name: "Updated Schedule",
            technique: schedule.technique,
            dateCreated: schedule.dateCreated,
            dateModified: Date(),
            segments: schedule.segments,
            description: "Updated description"
        )

        // Act
        try await repository.updateSchedule(updatedSchedule)
        let retrieved = try await repository.getSchedule(id: schedule.id)

        // Assert
        #expect(retrieved?.name == "Updated Schedule")
        #expect(retrieved?.description == "Updated notes")
    }

    @Test("Should throw error when updating non-existent schedule")
    func testUpdateNonExistentSchedule() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let schedule = createTestSchedule()

        // Act & Assert
        await #expect(throws: KilnScheduleRepositoryError.scheduleNotFound) {
            try await repository.updateSchedule(schedule)
        }
    }

    @Test("Should delete schedule")
    func testDeleteSchedule() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let schedule = createTestSchedule()
        _ = try await repository.createSchedule(schedule)

        #expect(await repository.getScheduleCount() == 1)

        // Act
        try await repository.deleteSchedule(id: schedule.id)

        // Assert
        #expect(await repository.getScheduleCount() == 0)
        let retrieved = try await repository.getSchedule(id: schedule.id)
        #expect(retrieved == nil)
    }

    @Test("Should throw error when deleting non-existent schedule")
    func testDeleteNonExistentSchedule() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let randomId = UUID()

        // Act & Assert
        await #expect(throws: KilnScheduleRepositoryError.scheduleNotFound) {
            try await repository.deleteSchedule(id: randomId)
        }
    }

    // MARK: - Query Tests

    @Test("Should get schedules by technique")
    func testGetSchedulesByTechnique() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let fusingSchedule1 = createTestSchedule(name: "Fusing 1", technique: .fusing)
        let fusingSchedule2 = createTestSchedule(name: "Fusing 2", technique: .fusing)
        let slumpingSchedule = createTestSchedule(name: "Slumping", technique: .fusing)

        _ = try await repository.createSchedule(fusingSchedule1)
        _ = try await repository.createSchedule(fusingSchedule2)
        _ = try await repository.createSchedule(slumpingSchedule)

        // Act
        let fusingSchedules = try await repository.getSchedules(technique: .fusing)

        // Assert
        #expect(fusingSchedules.count == 2)
        #expect(fusingSchedules.allSatisfy { $0.technique == .fusing })
    }

    @Test("Should get schedules sorted by name")
    func testGetSchedulesSortedByName() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let scheduleC = createTestSchedule(name: "Charlie Schedule", technique: .fusing)
        let scheduleA = createTestSchedule(name: "Alpha Schedule", technique: .fusing)
        let scheduleB = createTestSchedule(name: "Bravo Schedule", technique: .fusing)

        _ = try await repository.createSchedule(scheduleC)
        _ = try await repository.createSchedule(scheduleA)
        _ = try await repository.createSchedule(scheduleB)

        // Act
        let sorted = try await repository.getSchedulesSortedByName()

        // Assert
        #expect(sorted.count == 3)
        #expect(sorted[0].name == "Alpha Schedule")
        #expect(sorted[1].name == "Bravo Schedule")
        #expect(sorted[2].name == "Charlie Schedule")
    }

    // MARK: - Search Tests

    @Test("Should search schedules by name")
    func testSearchSchedulesByName() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let schedule1 = createTestSchedule(name: "Full Fuse Schedule", technique: .fusing)
        let schedule2 = createTestSchedule(name: "Tack Fuse Schedule", technique: .fusing)
        let schedule3 = createTestSchedule(name: "Slumping Schedule", technique: .fusing)

        _ = try await repository.createSchedule(schedule1)
        _ = try await repository.createSchedule(schedule2)
        _ = try await repository.createSchedule(schedule3)

        // Act
        let results = try await repository.searchSchedules(query: "fuse")

        // Assert
        #expect(results.count == 2)
        #expect(results.contains { $0.name == "Full Fuse Schedule" })
        #expect(results.contains { $0.name == "Tack Fuse Schedule" })
    }

    @Test("Should search schedules by notes")
    func testSearchSchedulesByNotes() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let schedule1 = KilnSchedule(
            name: "Schedule 1",
            technique: .fusing,
            description: "Great for dichroic glass"
        )
        let schedule2 = KilnSchedule(
            name: "Schedule 2",
            technique: .fusing,
            description: "Perfect for bowls"
        )

        _ = try await repository.createSchedule(schedule1)
        _ = try await repository.createSchedule(schedule2)

        // Act
        let results = try await repository.searchSchedules(query: "dichroic")

        // Assert
        #expect(results.count == 1)
        #expect(results[0].name == "Schedule 1")
    }

    @Test("Should search schedules by technique")
    func testSearchSchedulesByTechnique() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let schedule1 = createTestSchedule(name: "Schedule 1", technique: .fusing)
        let schedule2 = createTestSchedule(name: "Schedule 2", technique: .fusing)

        _ = try await repository.createSchedule(schedule1)
        _ = try await repository.createSchedule(schedule2)

        // Act
        let results = try await repository.searchSchedules(query: "slumping")

        // Assert
        #expect(results.count == 1)
        #expect(results[0].technique == .fusing)
    }

    @Test("Should return empty array for no matches")
    func testSearchWithNoMatches() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let schedule = createTestSchedule()
        _ = try await repository.createSchedule(schedule)

        // Act
        let results = try await repository.searchSchedules(query: "nonexistent")

        // Assert
        #expect(results.isEmpty)
    }

    // MARK: - Test Helper Tests

    @Test("Should reset repository")
    func testReset() async throws {
        // Arrange
        let repository = MockKilnScheduleRepository()
        let schedule = createTestSchedule()
        _ = try await repository.createSchedule(schedule)

        #expect(await repository.getScheduleCount() == 1)

        // Act
        await repository.reset()

        // Assert
        #expect(await repository.getScheduleCount() == 0)
    }
}
