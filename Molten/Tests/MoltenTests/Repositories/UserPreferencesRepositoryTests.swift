//
//  UserPreferencesRepositoryTests.swift
//  MoltenTests
//
//  Tests for UserPreferencesRepository persistence
//

import Testing
import Foundation
@testable import Molten

@Suite("UserPreferencesRepository Tests")
@MainActor
struct UserPreferencesRepositoryTests {

    @Test("Save and retrieve manufacturer filter")
    func testSaveAndRetrieveManufacturerFilter() async throws {
        let userDefaults = UserDefaults(suiteName: "test.manufacturerFilter.\(UUID().uuidString)")!
        let repository = UserDefaultsPreferencesRepository(userDefaults: userDefaults)

        let manufacturers = Set(["EF", "DH", "BE"])
        try await repository.saveManufacturerFilter(manufacturers)

        let retrieved = try await repository.getManufacturerFilter()
        #expect(retrieved == manufacturers)
    }

    @Test("Retrieve manufacturer filter returns nil when not set")
    func testRetrieveWhenNotSet() async throws {
        let userDefaults = UserDefaults(suiteName: "test.manufacturerFilter.\(UUID().uuidString)")!
        let repository = UserDefaultsPreferencesRepository(userDefaults: userDefaults)

        let retrieved = try await repository.getManufacturerFilter()
        #expect(retrieved == nil)
    }

    @Test("Clear manufacturer filter")
    func testClearManufacturerFilter() async throws {
        let userDefaults = UserDefaults(suiteName: "test.manufacturerFilter.\(UUID().uuidString)")!
        let repository = UserDefaultsPreferencesRepository(userDefaults: userDefaults)

        // Save, then clear
        let manufacturers = Set(["EF", "DH"])
        try await repository.saveManufacturerFilter(manufacturers)
        try await repository.clearManufacturerFilter()

        let retrieved = try await repository.getManufacturerFilter()
        #expect(retrieved == nil)
    }

    @Test("Update manufacturer filter (overwrite existing)")
    func testUpdateManufacturerFilter() async throws {
        let userDefaults = UserDefaults(suiteName: "test.manufacturerFilter.\(UUID().uuidString)")!
        let repository = UserDefaultsPreferencesRepository(userDefaults: userDefaults)

        // Save initial
        try await repository.saveManufacturerFilter(Set(["EF", "DH"]))

        // Update
        try await repository.saveManufacturerFilter(Set(["BE", "CiM"]))

        let retrieved = try await repository.getManufacturerFilter()
        #expect(retrieved == Set(["BE", "CiM"]))
    }

    @Test("Save empty set")
    func testSaveEmptySet() async throws {
        let userDefaults = UserDefaults(suiteName: "test.manufacturerFilter.\(UUID().uuidString)")!
        let repository = UserDefaultsPreferencesRepository(userDefaults: userDefaults)

        try await repository.saveManufacturerFilter(Set())

        let retrieved = try await repository.getManufacturerFilter()
        #expect(retrieved?.isEmpty == true)
    }

    @Test("Isolation between different UserDefaults instances")
    func testIsolation() async throws {
        let userDefaults1 = UserDefaults(suiteName: "test.manufacturerFilter.\(UUID().uuidString)")!
        let userDefaults2 = UserDefaults(suiteName: "test.manufacturerFilter.\(UUID().uuidString)")!

        let repo1 = UserDefaultsPreferencesRepository(userDefaults: userDefaults1)
        let repo2 = UserDefaultsPreferencesRepository(userDefaults: userDefaults2)

        try await repo1.saveManufacturerFilter(Set(["EF"]))
        try await repo2.saveManufacturerFilter(Set(["DH"]))

        let retrieved1 = try await repo1.getManufacturerFilter()
        let retrieved2 = try await repo2.getManufacturerFilter()

        #expect(retrieved1 == Set(["EF"]))
        #expect(retrieved2 == Set(["DH"]))
    }
}
