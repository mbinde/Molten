//
//  UserDefaultsPreferencesRepository.swift
//  Molten
//
//  UserDefaults-backed implementation of UserPreferencesRepository
//  Following CLAUDE.md: "Repositories persist. CRUD operations only. NO business logic."
//

import Foundation

/// UserDefaults-backed persistence for user preferences
@MainActor
final class UserDefaultsPreferencesRepository: UserPreferencesRepository {

    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let manufacturerFilterKey = "selectedManufacturerFilter"

    // MARK: - Initialization

    /// Initialize with custom UserDefaults (useful for testing)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - UserPreferencesRepository

    func getManufacturerFilter() async throws -> Set<String>? {
        guard let data = userDefaults.data(forKey: manufacturerFilterKey) else {
            return nil
        }

        let decoded = try JSONDecoder().decode(Set<String>.self, from: data)
        return decoded
    }

    func saveManufacturerFilter(_ manufacturers: Set<String>) async throws {
        let encoded = try JSONEncoder().encode(manufacturers)
        userDefaults.set(encoded, forKey: manufacturerFilterKey)
    }

    func clearManufacturerFilter() async throws {
        userDefaults.removeObject(forKey: manufacturerFilterKey)
    }
}
