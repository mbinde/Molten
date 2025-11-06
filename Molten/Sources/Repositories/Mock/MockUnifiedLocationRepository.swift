//
//  MockUnifiedLocationRepository.swift
//  Molten
//
//  Mock implementation for testing
//

import Foundation

class MockUnifiedLocationRepository: @unchecked Sendable, UnifiedLocationRepository {
    nonisolated(unsafe) private var locations: [String: UnifiedLocationModel] = [:]

    nonisolated init(initialLocations: [UnifiedLocationModel] = []) {
        for location in initialLocations {
            locations[location.stable_id] = location
        }
    }

    func fetchAll() async throws -> [UnifiedLocationModel] {
        return Array(locations.values).sorted { $0.name < $1.name }
    }

    func fetch(stableId: String) async throws -> UnifiedLocationModel? {
        return locations[stableId]
    }

    func save(_ location: UnifiedLocationModel) async throws {
        locations[location.stable_id] = location
    }

    func saveAll(_ locations: [UnifiedLocationModel]) async throws {
        for location in locations {
            try await save(location)
        }
    }

    func delete(stableId: String) async throws {
        locations.removeValue(forKey: stableId)
    }

    func deleteAll() async throws {
        locations.removeAll()
    }

    func search(text: String) async throws -> [UnifiedLocationModel] {
        let lowercaseText = text.lowercased()
        return locations.values.filter { location in
            location.matchesSearchText(lowercaseText)
        }.sorted { $0.name < $1.name }
    }

    func fetchLocationsSellingTechnique(_ technique: TechniqueType) async throws -> [UnifiedLocationModel] {
        return locations.values.filter { location in
            location.sells(technique)
        }.sorted { $0.name < $1.name }
    }

    func fetchLocationsTeachingTechnique(_ technique: TechniqueType) async throws -> [UnifiedLocationModel] {
        return locations.values.filter { location in
            location.teaches(technique)
        }.sorted { $0.name < $1.name }
    }

    func fetchLocationsOfferingService(_ service: ServiceType) async throws -> [UnifiedLocationModel] {
        return locations.values.filter { location in
            location.offers(service)
        }.sorted { $0.name < $1.name }
    }

    func fetchLocationsNear(latitude: Double, longitude: Double, radiusMeters: Double) async throws -> [UnifiedLocationModel] {
        let radiusDegrees = radiusMeters / 111_000.0

        return locations.values.filter { location in
            let latDiff = abs(location.latitude - latitude)
            let lonDiff = abs(location.longitude - longitude)
            return latDiff < radiusDegrees && lonDiff < radiusDegrees
        }.sorted { $0.name < $1.name }
    }

    func count() async throws -> Int {
        return locations.count
    }

    // MARK: - JSON Loading

    func loadLocationsFromJSON(_ data: Data) async throws -> Int {
        let decoder = JSONDecoder()
        let wrappedData = try decoder.decode(WrappedStoresData.self, from: data)

        var loadedCount = 0
        for storeData in wrappedData.stores {
            let location = convertStoreDataToUnifiedLocation(storeData)
            locations[location.stable_id] = location
            loadedCount += 1
        }

        return loadedCount
    }

    func loadLocationsFromJSONFile(at fileURL: URL) async throws -> Int {
        let data = try Data(contentsOf: fileURL)
        return try await loadLocationsFromJSON(data)
    }

    // MARK: - Private Helpers

    /// Convert StoreData format to UnifiedLocationModel with retail, education, and service capabilities
    private nonisolated func convertStoreDataToUnifiedLocation(_ storeData: StoreData) -> UnifiedLocationModel {
        var retailCapabilities: [RetailCapability] = []
        var educationCapabilities: [EducationCapability] = []
        var servicesCapabilities: [ServicesCapability] = []

        // Convert retail capability flags (prefer new format, fall back to legacy)
        if (storeData.retail_supports_casting ?? storeData.supports_casting) == true {
            retailCapabilities.append(RetailCapability(technique: .casting))
        }
        if (storeData.retail_supports_flameworking_hard ?? storeData.supports_flameworking_hard) == true {
            retailCapabilities.append(RetailCapability(technique: .flameworkinghard))
        }
        if (storeData.retail_supports_flameworking_soft ?? storeData.supports_flameworking_soft) == true {
            retailCapabilities.append(RetailCapability(technique: .flameworkingsoft))
        }
        if (storeData.retail_supports_fusing ?? storeData.supports_fusing) == true {
            retailCapabilities.append(RetailCapability(technique: .fusing))
        }
        if (storeData.retail_supports_glass_blowing ?? storeData.supports_glass_blowing) == true {
            retailCapabilities.append(RetailCapability(technique: .glassBlowing))
        }
        if (storeData.retail_supports_stained_glass ?? storeData.supports_stained_glass) == true {
            retailCapabilities.append(RetailCapability(technique: .stainedGlass))
        }
        if (storeData.retail_supports_other ?? storeData.supports_other) == true {
            retailCapabilities.append(RetailCapability(technique: .other))
        }

        // Convert education capability flags (new format)
        if storeData.classes_supports_casting == true {
            educationCapabilities.append(EducationCapability(technique: .casting))
        }
        if storeData.classes_supports_flameworking_hard == true {
            educationCapabilities.append(EducationCapability(technique: .flameworkinghard))
        }
        if storeData.classes_supports_flameworking_soft == true {
            educationCapabilities.append(EducationCapability(technique: .flameworkingsoft))
        }
        if storeData.classes_supports_fusing == true {
            educationCapabilities.append(EducationCapability(technique: .fusing))
        }
        if storeData.classes_supports_glass_blowing == true {
            educationCapabilities.append(EducationCapability(technique: .glassBlowing))
        }
        if storeData.classes_supports_stained_glass == true {
            educationCapabilities.append(EducationCapability(technique: .stainedGlass))
        }
        if storeData.classes_supports_other == true {
            educationCapabilities.append(EducationCapability(technique: .other))
        }

        // Convert service capability flags (new format)
        // Services are technique-agnostic - just check if any rental is supported
        let hasAnyRental = (storeData.rentals_supports_casting == true) ||
                          (storeData.rentals_supports_flameworking_hard == true) ||
                          (storeData.rentals_supports_flameworking_soft == true) ||
                          (storeData.rentals_supports_fusing == true) ||
                          (storeData.rentals_supports_glass_blowing == true) ||
                          (storeData.rentals_supports_stained_glass == true) ||
                          (storeData.rentals_supports_other == true)

        if hasAnyRental {
            servicesCapabilities.append(ServicesCapability(serviceType: .kilnRental))
        }

        return UnifiedLocationModel(
            stable_id: storeData.stable_id,
            name: storeData.name,
            addressLine1: storeData.address_line1,
            addressLine2: storeData.address_line2,
            city: storeData.city,
            state: storeData.state,
            zip: storeData.zip,
            latitude: storeData.latitude ?? 0.0,
            longitude: storeData.longitude ?? 0.0,
            websiteUrl: storeData.website_url,
            phone: storeData.phone,
            hoursJson: storeData.hours_json,
            heroImagePath: storeData.hero_image_path,
            notes: storeData.notes,
            isVerified: storeData.is_verified ?? false,
            retailCapabilities: retailCapabilities,
            educationCapabilities: educationCapabilities,
            servicesCapabilities: servicesCapabilities
        )
    }
}
