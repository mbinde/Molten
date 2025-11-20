//
//  ManufacturerFilterServiceTests.swift
//  MoltenTests
//
//  Tests for ManufacturerFilterService orchestration
//

import Testing
import Foundation
@testable import Molten

@Suite("ManufacturerFilterService Tests")
@MainActor
struct ManufacturerFilterServiceTests {

    @Test("Initialize with repository and load existing preferences")
    func testInitializeWithExistingPreferences() async throws {
        let mockRepo = MockUserPreferencesRepository()
        mockRepo.manufacturerFilterData = Set(["EF", "DH"])

        let service = ManufacturerFilterService(
            repository: mockRepo,
            availableManufacturers: ["EF", "DH", "BE", "CiM"]
        )

        // Wait for initialization
        try await Task.sleep(for: .milliseconds(50))

        // Service loads saved preferences as-is (doesn't auto-enable new manufacturers until updateAvailableManufacturers is called)
        #expect(service.selectedManufacturers == Set(["EF", "DH"]))
        #expect(service.isManufacturerEnabled("EF") == true)
        #expect(service.isManufacturerEnabled("DH") == true)
        #expect(service.isManufacturerEnabled("BE") == false)
        #expect(service.isManufacturerEnabled("CiM") == false)
    }

    @Test("Initialize with no existing preferences (defaults to all)")
    func testInitializeWithNoPreferences() async throws {
        let mockRepo = MockUserPreferencesRepository()
        mockRepo.manufacturerFilterData = nil  // No saved preferences

        let service = ManufacturerFilterService(
            repository: mockRepo,
            availableManufacturers: ["EF", "DH", "BE"]
        )

        // Wait for initialization
        try await Task.sleep(for: .milliseconds(50))

        #expect(service.selectedManufacturers == Set(["EF", "DH", "BE"]))
        #expect(service.isManufacturerEnabled("EF") == true)
        #expect(service.isManufacturerEnabled("DH") == true)
        #expect(service.isManufacturerEnabled("BE") == true)
    }

    @Test("Enable manufacturer and persist")
    func testEnableManufacturerPersists() async throws {
        let mockRepo = MockUserPreferencesRepository()
        mockRepo.manufacturerFilterData = Set(["EF"])

        let service = ManufacturerFilterService(
            repository: mockRepo,
            availableManufacturers: ["EF", "DH"]
        )

        try await Task.sleep(for: .milliseconds(50))

        await service.enableManufacturer("DH")

        #expect(service.isManufacturerEnabled("DH") == true)
        #expect(mockRepo.manufacturerFilterData == Set(["EF", "DH"]))
    }

    @Test("Disable manufacturer and persist")
    func testDisableManufacturerPersists() async throws {
        let mockRepo = MockUserPreferencesRepository()
        mockRepo.manufacturerFilterData = Set(["EF", "DH"])

        let service = ManufacturerFilterService(
            repository: mockRepo,
            availableManufacturers: ["EF", "DH"]
        )

        try await Task.sleep(for: .milliseconds(50))

        await service.disableManufacturer("EF")

        #expect(service.isManufacturerEnabled("EF") == false)
        #expect(mockRepo.manufacturerFilterData == Set(["DH"]))
    }

    @Test("Select all manufacturers and persist")
    func testSelectAllPersists() async throws {
        let mockRepo = MockUserPreferencesRepository()
        mockRepo.manufacturerFilterData = Set(["EF"])

        let service = ManufacturerFilterService(
            repository: mockRepo,
            availableManufacturers: ["EF", "DH", "BE"]
        )

        try await Task.sleep(for: .milliseconds(50))

        await service.selectAll()

        #expect(service.selectedManufacturers == Set(["EF", "DH", "BE"]))
        #expect(mockRepo.manufacturerFilterData == Set(["EF", "DH", "BE"]))
    }

    @Test("Select none and persist")
    func testSelectNonePersists() async throws {
        let mockRepo = MockUserPreferencesRepository()
        mockRepo.manufacturerFilterData = Set(["EF", "DH"])

        let service = ManufacturerFilterService(
            repository: mockRepo,
            availableManufacturers: ["EF", "DH"]
        )

        try await Task.sleep(for: .milliseconds(50))

        await service.selectNone()

        #expect(service.selectedManufacturers.isEmpty)
        #expect(mockRepo.manufacturerFilterData?.isEmpty == true)
    }

    @Test("Should show item based on filter")
    func testShouldShowItem() async throws {
        let mockRepo = MockUserPreferencesRepository()
        mockRepo.manufacturerFilterData = Set(["EF"])

        let service = ManufacturerFilterService(
            repository: mockRepo,
            availableManufacturers: ["EF", "DH"]
        )

        try await Task.sleep(for: .milliseconds(50))

        #expect(service.shouldShowItem(manufacturer: "EF") == true)
        #expect(service.shouldShowItem(manufacturer: "DH") == false)
        #expect(service.shouldShowItem(manufacturer: nil) == true)
    }

    @Test("Update available manufacturers")
    func testUpdateAvailableManufacturers() async throws {
        let mockRepo = MockUserPreferencesRepository()
        mockRepo.manufacturerFilterData = Set(["EF", "DH"])

        let service = ManufacturerFilterService(
            repository: mockRepo,
            availableManufacturers: ["EF", "DH"]
        )

        try await Task.sleep(for: .milliseconds(50))

        await service.updateAvailableManufacturers(["EF", "DH", "BE"])

        #expect(service.isManufacturerEnabled("EF") == true)
        #expect(service.isManufacturerEnabled("DH") == true)
        #expect(service.isManufacturerEnabled("BE") == true)  // New, enabled by default
        #expect(mockRepo.manufacturerFilterData == Set(["EF", "DH", "BE"]))
    }

    @Test("Get enabled manufacturers count")
    func testEnabledCount() async throws {
        let mockRepo = MockUserPreferencesRepository()
        mockRepo.manufacturerFilterData = Set(["EF", "DH"])

        let service = ManufacturerFilterService(
            repository: mockRepo,
            availableManufacturers: ["EF", "DH", "BE", "CiM"]
        )

        try await Task.sleep(for: .milliseconds(50))

        #expect(service.enabledCount == 2)  // EF, DH (as saved)
    }
}

// MARK: - Mock UserPreferencesRepository

@MainActor
class MockUserPreferencesRepository: UserPreferencesRepository {
    var manufacturerFilterData: Set<String>?

    func getManufacturerFilter() async throws -> Set<String>? {
        return manufacturerFilterData
    }

    func saveManufacturerFilter(_ manufacturers: Set<String>) async throws {
        manufacturerFilterData = manufacturers
    }

    func clearManufacturerFilter() async throws {
        manufacturerFilterData = nil
    }
}
