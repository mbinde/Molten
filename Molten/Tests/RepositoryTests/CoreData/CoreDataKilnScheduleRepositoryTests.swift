//
//  CoreDataKilnScheduleRepositoryTests.swift
//  RepositoryTests
//
//  Tests for CoreDataKilnScheduleRepository
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Core Data Kiln Schedule Repository Tests")
@MainActor
struct CoreDataKilnScheduleRepositoryTests {

    // MARK: - Test Helpers

    private func createTestRepository(controller: PersistenceController) -> CoreDataKilnScheduleRepository {
        RepositoryFactory.configureForTestingWithCoreData(controller: controller)
        return CoreDataKilnScheduleRepository(context: controller.container.viewContext)
    }

    private func createTestSegment(
        id: UUID = UUID(),
        targetTemperature: Decimal = 500,
        rampRate: Decimal = 100,
        holdTime: Decimal = 30
    ) -> KilnSegment {
        return KilnSegment(
            id: id,
            targetTemperature: targetTemperature,
            rampRate: rampRate,
            holdTime: holdTime
        )
    }

    private func createTestSchedule(
        id: UUID = UUID(),
        name: String = "Test Schedule",
        technique: TechniqueType? = .fusing,
        segments: [KilnSegment]? = nil,
        description: String? = nil
    ) -> KilnSchedule {
        let defaultSegments = segments ?? [createTestSegment()]
        return KilnSchedule(
            id: id,
            name: name,
            technique: technique,
            dateCreated: Date(),
            dateModified: Date(),
            segments: defaultSegments,
            description: description,
            temperatureUnit: .celsius
        )
    }

    // MARK: - CRUD Tests

    @Test("Should create a schedule")
    func testCreateSchedule() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let schedule = createTestSchedule(name: "Fusing Schedule")

        let created = try await repository.createSchedule(schedule)

        #expect(created.id == schedule.id)
        #expect(created.name == "Fusing Schedule")
        #expect(created.technique == .fusing)
        #expect(created.segments.count == 1)
    }

    @Test("Should get schedule by ID")
    func testGetScheduleById() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let schedule = createTestSchedule()
        _ = try await repository.createSchedule(schedule)

        let fetched = try await repository.getSchedule(id: schedule.id)

        #expect(fetched != nil)
        #expect(fetched?.id == schedule.id)
        #expect(fetched?.name == "Test Schedule")
    }

    @Test("Should return nil for non-existent schedule")
    func testGetNonExistentSchedule() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let nonExistentId = UUID()
        let fetched = try await repository.getSchedule(id: nonExistentId)

        #expect(fetched == nil)
    }

    @Test("Should get all schedules")
    func testGetAllSchedules() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let schedule1 = createTestSchedule(name: "Schedule 1")
        let schedule2 = createTestSchedule(name: "Schedule 2")

        _ = try await repository.createSchedule(schedule1)
        _ = try await repository.createSchedule(schedule2)

        let all = try await repository.getAllSchedules()

        #expect(all.count == 2)
        #expect(all.contains { $0.name == "Schedule 1" })
        #expect(all.contains { $0.name == "Schedule 2" })
    }

    @Test("Should update a schedule")
    func testUpdateSchedule() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let schedule = createTestSchedule(name: "Original Name")
        _ = try await repository.createSchedule(schedule)

        let updatedSchedule = KilnSchedule(
            id: schedule.id,
            name: "Updated Name",
            technique: .casting,
            dateCreated: schedule.dateCreated,
            dateModified: Date(),
            segments: schedule.segments,
            description: "Updated description",
            temperatureUnit: .celsius
        )

        try await repository.updateSchedule(updatedSchedule)

        let fetched = try await repository.getSchedule(id: schedule.id)
        #expect(fetched?.name == "Updated Name")
        #expect(fetched?.technique == .casting)
        #expect(fetched?.description == "Updated description")
    }

    @Test("Should throw when updating non-existent schedule")
    func testUpdateNonExistentSchedule() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let schedule = createTestSchedule()

        await #expect(throws: KilnScheduleRepositoryError.self) {
            try await repository.updateSchedule(schedule)
        }
    }

    @Test("Should delete a schedule")
    func testDeleteSchedule() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let schedule = createTestSchedule()
        _ = try await repository.createSchedule(schedule)

        try await repository.deleteSchedule(id: schedule.id)

        let fetched = try await repository.getSchedule(id: schedule.id)
        #expect(fetched == nil)
    }

    @Test("Should throw when deleting non-existent schedule")
    func testDeleteNonExistentSchedule() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let nonExistentId = UUID()

        await #expect(throws: KilnScheduleRepositoryError.self) {
            try await repository.deleteSchedule(id: nonExistentId)
        }
    }

    // MARK: - Segment Tests

    @Test("Should handle schedules with multiple segments")
    func testMultipleSegments() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let segments = [
            createTestSegment(targetTemperature: 500, rampRate: 100, holdTime: 30),
            createTestSegment(targetTemperature: 800, rampRate: 50, holdTime: 60),
            createTestSegment(targetTemperature: 500, rampRate: 200, holdTime: 15)
        ]

        let schedule = createTestSchedule(segments: segments)
        _ = try await repository.createSchedule(schedule)

        let fetched = try await repository.getSchedule(id: schedule.id)

        #expect(fetched?.segments.count == 3)
        #expect(fetched?.segments[0].targetTemperature == 500)
        #expect(fetched?.segments[1].targetTemperature == 800)
        #expect(fetched?.segments[2].targetTemperature == 500)
    }

    @Test("Should preserve segment order")
    func testSegmentOrder() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let segments = [
            createTestSegment(targetTemperature: 100),
            createTestSegment(targetTemperature: 200),
            createTestSegment(targetTemperature: 300)
        ]

        let schedule = createTestSchedule(segments: segments)
        _ = try await repository.createSchedule(schedule)

        let fetched = try await repository.getSchedule(id: schedule.id)

        #expect(fetched?.segments[0].targetTemperature == 100)
        #expect(fetched?.segments[1].targetTemperature == 200)
        #expect(fetched?.segments[2].targetTemperature == 300)
    }

    @Test("Should update schedule segments")
    func testUpdateSegments() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let segment1 = createTestSegment(targetTemperature: 500)
        let schedule = createTestSchedule(segments: [segment1])
        _ = try await repository.createSchedule(schedule)

        let newSegments = [
            createTestSegment(targetTemperature: 600),
            createTestSegment(targetTemperature: 700)
        ]

        let updatedSchedule = KilnSchedule(
            id: schedule.id,
            name: schedule.name,
            technique: schedule.technique,
            dateCreated: schedule.dateCreated,
            dateModified: Date(),
            segments: newSegments,
            description: schedule.description,
            temperatureUnit: .celsius
        )

        try await repository.updateSchedule(updatedSchedule)

        let fetched = try await repository.getSchedule(id: schedule.id)
        #expect(fetched?.segments.count == 2)
        #expect(fetched?.segments[0].targetTemperature == 600)
    }

    // MARK: - Query Tests

    @Test("Should get schedules by technique")
    func testGetSchedulesByTechnique() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let fusingSchedule = createTestSchedule(name: "Fusing", technique: .fusing)
        let castingSchedule = createTestSchedule(name: "Casting", technique: .casting)
        let anotherFusing = createTestSchedule(name: "Another Fusing", technique: .fusing)

        _ = try await repository.createSchedule(fusingSchedule)
        _ = try await repository.createSchedule(castingSchedule)
        _ = try await repository.createSchedule(anotherFusing)

        let fusingResults = try await repository.getSchedules(technique: .fusing)
        let castingResults = try await repository.getSchedules(technique: .casting)

        #expect(fusingResults.count == 2)
        #expect(castingResults.count == 1)
        #expect(castingResults.first?.name == "Casting")
    }

    @Test("Should get schedules sorted by name")
    func testGetSchedulesSortedByName() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let scheduleC = createTestSchedule(name: "Charlie")
        let scheduleA = createTestSchedule(name: "Alpha")
        let scheduleB = createTestSchedule(name: "Bravo")

        _ = try await repository.createSchedule(scheduleC)
        _ = try await repository.createSchedule(scheduleA)
        _ = try await repository.createSchedule(scheduleB)

        let sorted = try await repository.getSchedulesSortedByName()

        #expect(sorted.count == 3)
        #expect(sorted[0].name == "Alpha")
        #expect(sorted[1].name == "Bravo")
        #expect(sorted[2].name == "Charlie")
    }

    // MARK: - Search Tests

    @Test("Should search schedules by name")
    func testSearchSchedulesByName() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let schedule1 = createTestSchedule(name: "Fast Fusing Schedule", technique: .fusing)
        let schedule2 = createTestSchedule(name: "Slow Casting", technique: .casting)
        let schedule3 = createTestSchedule(name: "Quick Fusing", technique: .fusing)

        _ = try await repository.createSchedule(schedule1)
        _ = try await repository.createSchedule(schedule2)
        _ = try await repository.createSchedule(schedule3)

        let results = try await repository.searchSchedules(query: "Fusing")

        #expect(results.count == 2)
        #expect(results.contains { $0.name == "Fast Fusing Schedule" })
        #expect(results.contains { $0.name == "Quick Fusing" })
    }

    @Test("Should search schedules case-insensitively")
    func testSearchSchedulesCaseInsensitive() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let schedule = createTestSchedule(name: "Fast Fusing")
        _ = try await repository.createSchedule(schedule)

        let results = try await repository.searchSchedules(query: "fast")

        #expect(results.count == 1)
        #expect(results.first?.name == "Fast Fusing")
    }

    @Test("Should search schedules by description")
    func testSearchSchedulesByDescription() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let schedule = createTestSchedule(
            name: "Test",
            description: "Special technique for large pieces"
        )
        _ = try await repository.createSchedule(schedule)

        let results = try await repository.searchSchedules(query: "Special")

        #expect(results.count == 1)
        #expect(results.first?.name == "Test")
    }

    // MARK: - Technique Tests

    @Test("Should handle schedule with no technique")
    func testScheduleWithNoTechnique() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let schedule = createTestSchedule(technique: nil)
        _ = try await repository.createSchedule(schedule)

        let fetched = try await repository.getSchedule(id: schedule.id)

        #expect(fetched?.technique == nil)
    }

    @Test("Should handle different technique types")
    func testDifferentTechniqueTypes() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let techniques: [TechniqueType] = [.casting, .flameworkinghard, .flameworkingsoft, .fusing, .glassBlowing, .stainedGlass, .other]

        for technique in techniques {
            let schedule = createTestSchedule(name: "\(technique.rawValue) Schedule", technique: technique)
            _ = try await repository.createSchedule(schedule)
        }

        let all = try await repository.getAllSchedules()
        #expect(all.count == techniques.count)
    }

    // MARK: - Edge Cases

    @Test("Should handle empty search results")
    func testEmptySearchResults() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let results = try await repository.searchSchedules(query: "NonExistent")

        #expect(results.isEmpty)
    }

    @Test("Should handle getting all schedules when none exist")
    func testGetAllSchedulesEmpty() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let all = try await repository.getAllSchedules()

        #expect(all.isEmpty)
    }

    @Test("Should handle optional description field")
    func testOptionalDescription() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let withDescription = createTestSchedule(name: "With", description: "Has description")
        let withoutDescription = createTestSchedule(name: "Without", description: nil)

        _ = try await repository.createSchedule(withDescription)
        _ = try await repository.createSchedule(withoutDescription)

        let fetched1 = try await repository.getSchedule(id: withDescription.id)
        let fetched2 = try await repository.getSchedule(id: withoutDescription.id)

        #expect(fetched1?.description == "Has description")
        #expect(fetched2?.description == nil)
    }
}
