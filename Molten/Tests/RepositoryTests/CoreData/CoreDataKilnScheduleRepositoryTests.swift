//
//  CoreDataKilnScheduleRepositoryTests.swift
//  RepositoryTests
//
//  Tests for CoreDataKilnScheduleRepository - manages kiln firing schedules
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Core Data KilnSchedule Repository Tests")
@MainActor
struct CoreDataKilnScheduleRepositoryTests {

    // MARK: - Create Tests

    @Test("Should create kiln schedule")
    func testCreateSchedule() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let segments = [
            KilnSegment(targetTemperature: 500, rampRate: 100, holdTime: 30),
            KilnSegment(targetTemperature: 800, rampRate: 50, holdTime: 60)
        ]

        let schedule = KilnSchedule(
            name: "Test Schedule",
            technique: .fusing,
            segments: segments
        )

        // Test
        let created = try await repository.createSchedule(schedule)

        // Verify
        #expect(created.name == "Test Schedule")
        #expect(created.segments.count == 2)
    }

    @Test("Should create schedule with optional description")
    func testCreateScheduleWithDescription() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let segments = [
            KilnSegment(targetTemperature: 500, rampRate: 100, holdTime: 30)
        ]

        let schedule = KilnSchedule(
            name: "Test Schedule",
            segments: segments,
            description: "Test description"
        )

        // Test
        let created = try await repository.createSchedule(schedule)

        // Verify
        #expect(created.description == "Test description")
    }

    // MARK: - Read Tests

    @Test("Should get schedule by ID")
    func testGetScheduleById() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let scheduleId = UUID()
        let segments = [
            KilnSegment(targetTemperature: 500, rampRate: 100, holdTime: 30)
        ]

        let schedule = KilnSchedule(
            id: scheduleId,
            name: "Test Schedule",
            segments: segments
        )
        _ = try await repository.createSchedule(schedule)

        // Test
        let fetched = try await repository.getSchedule(id: scheduleId)

        // Verify
        #expect(fetched != nil)
        #expect(fetched?.id == scheduleId)
        #expect(fetched?.name == "Test Schedule")
    }

    @Test("Should return nil for non-existent schedule")
    func testGetNonExistentSchedule() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        // Test
        let fetched = try await repository.getSchedule(id: UUID())

        // Verify
        #expect(fetched == nil)
    }

    @Test("Should get all schedules")
    func testGetAllSchedules() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let segments = [
            KilnSegment(targetTemperature: 500, rampRate: 100, holdTime: 30)
        ]

        _ = try await repository.createSchedule(KilnSchedule(
            name: "Schedule 1",
            segments: segments
        ))
        _ = try await repository.createSchedule(KilnSchedule(
            name: "Schedule 2",
            segments: segments
        ))

        // Test
        let schedules = try await repository.getAllSchedules()

        // Verify
        #expect(schedules.count == 2)
    }

    @Test("Should preserve segment order")
    func testPreserveSegmentOrder() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let segments = [
            KilnSegment(targetTemperature: 100, rampRate: 50, holdTime: 10),
            KilnSegment(targetTemperature: 200, rampRate: 75, holdTime: 20),
            KilnSegment(targetTemperature: 300, rampRate: 100, holdTime: 30)
        ]

        let schedule = KilnSchedule(
            name: "Multi-Segment Schedule",
            segments: segments
        )
        let created = try await repository.createSchedule(schedule)

        // Test
        let fetched = try await repository.getSchedule(id: created.id)

        // Verify
        #expect(fetched?.segments.count == 3)
        #expect(fetched?.segments[0].targetTemperature == 100)
        #expect(fetched?.segments[1].targetTemperature == 200)
        #expect(fetched?.segments[2].targetTemperature == 300)
    }

    // MARK: - Update Tests

    @Test("Should update existing schedule")
    func testUpdateSchedule() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let scheduleId = UUID()
        let segments = [
            KilnSegment(targetTemperature: 500, rampRate: 100, holdTime: 30)
        ]

        let original = KilnSchedule(
            id: scheduleId,
            name: "Original Name",
            segments: segments
        )
        _ = try await repository.createSchedule(original)

        // Test
        let updated = KilnSchedule(
            id: scheduleId,
            name: "Updated Name",
            segments: segments
        )
        try await repository.updateSchedule(updated)

        // Verify
        let fetched = try await repository.getSchedule(id: scheduleId)
        #expect(fetched?.name == "Updated Name")
    }

    @Test("Should update schedule segments")
    func testUpdateScheduleSegments() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let scheduleId = UUID()
        let originalSegments = [
            KilnSegment(targetTemperature: 500, rampRate: 100, holdTime: 30)
        ]

        let original = KilnSchedule(
            id: scheduleId,
            name: "Test Schedule",
            segments: originalSegments
        )
        _ = try await repository.createSchedule(original)

        // Test - Update with different segments
        let newSegments = [
            KilnSegment(targetTemperature: 300, rampRate: 50, holdTime: 15),
            KilnSegment(targetTemperature: 600, rampRate: 75, holdTime: 45)
        ]
        let updated = KilnSchedule(
            id: scheduleId,
            name: "Test Schedule",
            segments: newSegments
        )
        try await repository.updateSchedule(updated)

        // Verify
        let fetched = try await repository.getSchedule(id: scheduleId)
        #expect(fetched?.segments.count == 2)
        #expect(fetched?.segments[0].targetTemperature == 300)
        #expect(fetched?.segments[1].targetTemperature == 600)
    }

    @Test("Should throw error when updating non-existent schedule")
    func testUpdateNonExistentSchedule() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let segments = [
            KilnSegment(targetTemperature: 500, rampRate: 100, holdTime: 30)
        ]

        let schedule = KilnSchedule(
            name: "Test Schedule",
            segments: segments
        )

        // Test & Verify
        do {
            try await repository.updateSchedule(schedule)
            Issue.record("Expected error for updating non-existent schedule")
        } catch {
            // Expected error
        }
    }

    // MARK: - Delete Tests

    @Test("Should delete schedule")
    func testDeleteSchedule() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let scheduleId = UUID()
        let segments = [
            KilnSegment(targetTemperature: 500, rampRate: 100, holdTime: 30)
        ]

        let schedule = KilnSchedule(
            id: scheduleId,
            name: "Test Schedule",
            segments: segments
        )
        _ = try await repository.createSchedule(schedule)

        // Test
        try await repository.deleteSchedule(id: scheduleId)

        // Verify
        let fetched = try await repository.getSchedule(id: scheduleId)
        #expect(fetched == nil)
    }

    @Test("Should delete schedule and its segments")
    func testDeleteScheduleWithSegments() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let scheduleId = UUID()
        let segments = [
            KilnSegment(targetTemperature: 300, rampRate: 50, holdTime: 15),
            KilnSegment(targetTemperature: 600, rampRate: 75, holdTime: 45)
        ]

        let schedule = KilnSchedule(
            id: scheduleId,
            name: "Test Schedule",
            segments: segments
        )
        _ = try await repository.createSchedule(schedule)

        // Test
        try await repository.deleteSchedule(id: scheduleId)

        // Verify
        let fetched = try await repository.getSchedule(id: scheduleId)
        #expect(fetched == nil)
    }

    @Test("Should throw error when deleting non-existent schedule")
    func testDeleteNonExistentSchedule() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        // Test & Verify
        do {
            try await repository.deleteSchedule(id: UUID())
            Issue.record("Expected error for deleting non-existent schedule")
        } catch {
            // Expected error
        }
    }

    // MARK: - Query Tests

    @Test("Should get schedules by technique")
    func testGetSchedulesByTechnique() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let segments = [
            KilnSegment(targetTemperature: 500, rampRate: 100, holdTime: 30)
        ]

        _ = try await repository.createSchedule(KilnSchedule(
            name: "Fusing Schedule",
            technique: .fusing,
            segments: segments
        ))
        _ = try await repository.createSchedule(KilnSchedule(
            name: "Casting Schedule",
            technique: .casting,
            segments: segments
        ))

        // Test
        let fusingSchedules = try await repository.getSchedules(technique: .fusing)

        // Verify
        #expect(fusingSchedules.count == 1)
        #expect(fusingSchedules[0].name == "Fusing Schedule")
    }

    @Test("Should get schedules sorted by name")
    func testGetSchedulesSortedByName() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let segments = [
            KilnSegment(targetTemperature: 500, rampRate: 100, holdTime: 30)
        ]

        _ = try await repository.createSchedule(KilnSchedule(
            name: "Z Schedule",
            segments: segments
        ))
        _ = try await repository.createSchedule(KilnSchedule(
            name: "A Schedule",
            segments: segments
        ))
        _ = try await repository.createSchedule(KilnSchedule(
            name: "M Schedule",
            segments: segments
        ))

        // Test
        let schedules = try await repository.getSchedulesSortedByName()

        // Verify
        #expect(schedules.count == 3)
        #expect(schedules[0].name == "A Schedule")
        #expect(schedules[1].name == "M Schedule")
        #expect(schedules[2].name == "Z Schedule")
    }

    // MARK: - Search Tests

    @Test("Should search schedules by name")
    func testSearchSchedulesByName() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let segments = [
            KilnSegment(targetTemperature: 500, rampRate: 100, holdTime: 30)
        ]

        _ = try await repository.createSchedule(KilnSchedule(
            name: "Fast Fusing",
            segments: segments
        ))
        _ = try await repository.createSchedule(KilnSchedule(
            name: "Slow Fusing",
            segments: segments
        ))

        // Test
        let results = try await repository.searchSchedules(query: "Fast")

        // Verify
        #expect(results.count == 1)
        #expect(results[0].name == "Fast Fusing")
    }

    // MARK: - Helper Methods

    private func createTestRepository(controller: PersistenceController) -> CoreDataKilnScheduleRepository {
        RepositoryFactory.configureForTestingWithCoreData(controller: controller)
        return CoreDataKilnScheduleRepository(context: controller.container.viewContext)
    }
}
