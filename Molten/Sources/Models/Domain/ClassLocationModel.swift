//
//  ClassLocationModel.swift
//  Molten
//
//  Created for ClassLocation Feature on 11/1/25.
//

import Foundation
import CoreLocation

/// Business model for glass art class locations
struct ClassLocationModel: @preconcurrency LocationModel, Codable {
    nonisolated let stable_id: String
    nonisolated let name: String
    nonisolated let addressLine1: String?
    nonisolated let addressLine2: String?
    nonisolated let city: String?
    nonisolated let state: String?
    nonisolated let zip: String?
    nonisolated let latitude: Double
    nonisolated let longitude: Double
    nonisolated let websiteUrl: String?
    nonisolated let phone: String?
    nonisolated let hoursJson: String?
    nonisolated let heroImagePath: String?
    nonisolated let notes: String?
    nonisolated let isVerified: Bool

    // Technique support (individual booleans for efficient Core Data querying)
    nonisolated let supportsCasting: Bool
    nonisolated let supportsFlameworkingHard: Bool
    nonisolated let supportsFlameworkingSoft: Bool
    nonisolated let supportsFusing: Bool
    nonisolated let supportsGlassBlowing: Bool
    nonisolated let supportsStainedGlass: Bool
    nonisolated let supportsOther: Bool

    /// Initialize with business logic validation
    nonisolated init(
        stable_id: String,
        name: String,
        addressLine1: String? = nil,
        addressLine2: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zip: String? = nil,
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        websiteUrl: String? = nil,
        phone: String? = nil,
        hoursJson: String? = nil,
        heroImagePath: String? = nil,
        notes: String? = nil,
        isVerified: Bool = false,
        supportsCasting: Bool = false,
        supportsFlameworkingHard: Bool = false,
        supportsFlameworkingSoft: Bool = false,
        supportsFusing: Bool = false,
        supportsGlassBlowing: Bool = false,
        supportsStainedGlass: Bool = false,
        supportsOther: Bool = false
    ) {
        self.stable_id = stable_id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.addressLine1 = addressLine1?.isEmpty == true ? nil : addressLine1?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.addressLine2 = addressLine2?.isEmpty == true ? nil : addressLine2?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.city = city?.isEmpty == true ? nil : city?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.state = state?.isEmpty == true ? nil : state?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.zip = zip?.isEmpty == true ? nil : zip?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.latitude = latitude
        self.longitude = longitude
        self.websiteUrl = websiteUrl?.isEmpty == true ? nil : websiteUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.phone = phone?.isEmpty == true ? nil : phone?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hoursJson = hoursJson?.isEmpty == true ? nil : hoursJson
        self.heroImagePath = heroImagePath?.isEmpty == true ? nil : heroImagePath
        self.notes = notes?.isEmpty == true ? nil : notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isVerified = isVerified
        self.supportsCasting = supportsCasting
        self.supportsFlameworkingHard = supportsFlameworkingHard
        self.supportsFlameworkingSoft = supportsFlameworkingSoft
        self.supportsFusing = supportsFusing
        self.supportsGlassBlowing = supportsGlassBlowing
        self.supportsStainedGlass = supportsStainedGlass
        self.supportsOther = supportsOther
    }

    // MARK: - Business Logic
    // (All business logic methods inherited from LocationModel protocol)
}

// MARK: - Helper Extensions

extension ClassLocationModel {
    /// Create a class location with generated stable_id from name
    static func create(
        name: String,
        addressLine1: String? = nil,
        addressLine2: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zip: String? = nil,
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        websiteUrl: String? = nil,
        phone: String? = nil,
        hoursJson: String? = nil,
        heroImagePath: String? = nil,
        notes: String? = nil,
        isVerified: Bool = false,
        supportsCasting: Bool = false,
        supportsFlameworkingHard: Bool = false,
        supportsFlameworkingSoft: Bool = false,
        supportsFusing: Bool = false,
        supportsGlassBlowing: Bool = false,
        supportsStainedGlass: Bool = false,
        supportsOther: Bool = false
    ) -> ClassLocationModel {
        // Generate stable_id from name (simple slug)
        let stableId = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

        return ClassLocationModel(
            stable_id: stableId,
            name: name,
            addressLine1: addressLine1,
            addressLine2: addressLine2,
            city: city,
            state: state,
            zip: zip,
            latitude: latitude,
            longitude: longitude,
            websiteUrl: websiteUrl,
            phone: phone,
            hoursJson: hoursJson,
            heroImagePath: heroImagePath,
            notes: notes,
            isVerified: isVerified,
            supportsCasting: supportsCasting,
            supportsFlameworkingHard: supportsFlameworkingHard,
            supportsFlameworkingSoft: supportsFlameworkingSoft,
            supportsFusing: supportsFusing,
            supportsGlassBlowing: supportsGlassBlowing,
            supportsStainedGlass: supportsStainedGlass,
            supportsOther: supportsOther
        )
    }

    /// Convenience initializer that accepts an array of TechniqueType
    static func create(
        name: String,
        addressLine1: String? = nil,
        addressLine2: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zip: String? = nil,
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        websiteUrl: String? = nil,
        phone: String? = nil,
        hoursJson: String? = nil,
        heroImagePath: String? = nil,
        notes: String? = nil,
        isVerified: Bool = false,
        techniques: [TechniqueType] = []
    ) -> ClassLocationModel {
        return create(
            name: name,
            addressLine1: addressLine1,
            addressLine2: addressLine2,
            city: city,
            state: state,
            zip: zip,
            latitude: latitude,
            longitude: longitude,
            websiteUrl: websiteUrl,
            phone: phone,
            hoursJson: hoursJson,
            heroImagePath: heroImagePath,
            notes: notes,
            isVerified: isVerified,
            supportsCasting: techniques.contains(.casting),
            supportsFlameworkingHard: techniques.contains(.flameworkinghard),
            supportsFlameworkingSoft: techniques.contains(.flameworkingsoft),
            supportsFusing: techniques.contains(.fusing),
            supportsGlassBlowing: techniques.contains(.glassBlowing),
            supportsStainedGlass: techniques.contains(.stainedGlass),
            supportsOther: techniques.contains(.other)
        )
    }
}

