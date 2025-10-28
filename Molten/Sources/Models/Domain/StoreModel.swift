//
//  StoreModel.swift
//  Flameworker
//
//  Created for Store Feature on 10/26/25.
//

import Foundation
import CoreLocation

/// Business model for local glass stores
struct StoreModel: Identifiable, Equatable, Hashable, Codable, Sendable {
    let stable_id: String
    let name: String
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let state: String?
    let zip: String?
    let latitude: Double
    let longitude: Double
    let websiteUrl: String?
    let phone: String?
    let hoursJson: String?
    let heroImagePath: String?
    let notes: String?
    let isVerified: Bool

    // Technique support (individual booleans for efficient Core Data querying)
    let supportsCasting: Bool
    let supportsFlameworkingHard: Bool
    let supportsFlameworkingSoft: Bool
    let supportsFusing: Bool
    let supportsGlassBlowing: Bool
    let supportsStainedGlass: Bool
    let supportsOther: Bool

    // MARK: - Identifiable
    var id: String { stable_id }

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

    /// Full formatted address for display
    var fullAddress: String? {
        var components: [String] = []

        if let line1 = addressLine1 {
            components.append(line1)
        }
        if let line2 = addressLine2 {
            components.append(line2)
        }

        var cityStateZip: [String] = []
        if let city = city {
            cityStateZip.append(city)
        }
        if let state = state {
            cityStateZip.append(state)
        }
        if let zip = zip {
            cityStateZip.append(zip)
        }

        if !cityStateZip.isEmpty {
            components.append(cityStateZip.joined(separator: ", "))
        }

        return components.isEmpty ? nil : components.joined(separator: "\n")
    }

    /// Single-line address for compact display
    var compactAddress: String? {
        var components: [String] = []

        if let city = city {
            components.append(city)
        }
        if let state = state {
            components.append(state)
        }

        return components.isEmpty ? nil : components.joined(separator: ", ")
    }

    /// Check if store has a valid location
    nonisolated var hasValidLocation: Bool {
        return latitude != 0.0 && longitude != 0.0
    }

    /// CoreLocation coordinate for map display
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Check if store has complete address information
    var hasCompleteAddress: Bool {
        return addressLine1 != nil && city != nil && state != nil
    }

    /// Check if store has any address information
    var hasAnyAddress: Bool {
        return addressLine1 != nil || city != nil || state != nil || zip != nil
    }

    /// Formatted phone number for display (basic formatting)
    var formattedPhone: String? {
        guard let phone = phone else { return nil }

        // Remove all non-digit characters
        let digits = phone.filter { $0.isNumber }

        // Format as (XXX) XXX-XXXX if 10 digits
        if digits.count == 10 {
            let areaCode = digits.prefix(3)
            let prefix = digits.dropFirst(3).prefix(3)
            let lineNumber = digits.dropFirst(6)
            return "(\(areaCode)) \(prefix)-\(lineNumber)"
        }

        // Return original if not 10 digits
        return phone
    }

    /// Display name with verification badge indicator
    var displayName: String {
        return isVerified ? "\(name) ✓" : name
    }

    /// Check if store matches search text
    nonisolated func matchesSearchText(_ searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()

        return name.lowercased().contains(lowercaseSearch) ||
               (addressLine1?.lowercased().contains(lowercaseSearch) ?? false) ||
               (city?.lowercased().contains(lowercaseSearch) ?? false) ||
               (state?.lowercased().contains(lowercaseSearch) ?? false) ||
               (notes?.lowercased().contains(lowercaseSearch) ?? false) ||
               techniques.contains(where: { $0.displayName.lowercased().contains(lowercaseSearch) })
    }

    /// Check if store supports a specific technique
    nonisolated func supportsTechnique(_ technique: TechniqueType) -> Bool {
        switch technique {
        case .casting: return supportsCasting
        case .flameworkinghard: return supportsFlameworkingHard
        case .flameworkingsoft: return supportsFlameworkingSoft
        case .fusing: return supportsFusing
        case .glassBlowing: return supportsGlassBlowing
        case .stainedGlass: return supportsStainedGlass
        case .other: return supportsOther
        }
    }

    /// Get array of supported techniques
    nonisolated var techniques: [TechniqueType] {
        var result: [TechniqueType] = []
        if supportsCasting { result.append(.casting) }
        if supportsFlameworkingHard { result.append(.flameworkinghard) }
        if supportsFlameworkingSoft { result.append(.flameworkingsoft) }
        if supportsFusing { result.append(.fusing) }
        if supportsGlassBlowing { result.append(.glassBlowing) }
        if supportsStainedGlass { result.append(.stainedGlass) }
        if supportsOther { result.append(.other) }
        return result
    }

    /// Formatted list of technique names for display
    var techniquesDisplay: String {
        let supportedTechniques = techniques
        guard !supportedTechniques.isEmpty else { return "No techniques listed" }
        return supportedTechniques.map { $0.displayName }.joined(separator: ", ")
    }

    /// Distance from a given coordinate (in meters)
    nonisolated func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard hasValidLocation else { return nil }

        let storeLocation = CLLocation(latitude: latitude, longitude: longitude)
        let otherLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return storeLocation.distance(from: otherLocation)
    }

    /// Formatted distance string (miles or km based on locale)
    func formattedDistance(from coordinate: CLLocationCoordinate2D) -> String? {
        guard let meters = distance(from: coordinate) else { return nil }

        // Convert to miles for US locale
        let miles = meters * 0.000621371

        if miles < 0.1 {
            return "nearby"
        } else if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }

    // MARK: - Validation

    /// Validate that the store has required data
    var isValid: Bool {
        return !stable_id.isEmpty && !name.isEmpty
    }

    /// Get validation errors if any
    var validationErrors: [String] {
        var errors: [String] = []

        if stable_id.isEmpty {
            errors.append("Store ID is required")
        }

        if name.isEmpty {
            errors.append("Store name is required")
        }

        // Validate coordinates if provided
        if hasValidLocation {
            if latitude < -90 || latitude > 90 {
                errors.append("Invalid latitude (must be between -90 and 90)")
            }
            if longitude < -180 || longitude > 180 {
                errors.append("Invalid longitude (must be between -180 and 180)")
            }
        }

        return errors
    }

    /// Check if store has enough info to be useful
    var hasMinimumInfo: Bool {
        return isValid && (hasAnyAddress || hasValidLocation || websiteUrl != nil)
    }
}

// MARK: - Helper Extensions

extension StoreModel {
    /// Create a store with generated stable_id from name
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
    ) -> StoreModel {
        // Generate stable_id from name (simple slug)
        let stableId = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

        return StoreModel(
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
    ) -> StoreModel {
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
