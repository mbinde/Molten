//
//  UnifiedLocationModel.swift
//  Molten
//
//  Created for Unified Locations Feature on 11/1/25.
//

import Foundation
import CoreLocation

/// Capability models for what a location offers

/// What a location sells (retail capability)
struct RetailCapability: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let technique: TechniqueType
    let notes: String?

    nonisolated init(id: UUID = UUID(), technique: TechniqueType, notes: String? = nil) {
        self.id = id
        self.technique = technique
        self.notes = notes?.isEmpty == true ? nil : notes
    }
}

/// What a location teaches (education capability)
struct EducationCapability: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let technique: TechniqueType
    let classLevel: String? // "beginner", "intermediate", "advanced", "all"
    let notes: String?

    nonisolated init(id: UUID = UUID(), technique: TechniqueType, classLevel: String? = nil, notes: String? = nil) {
        self.id = id
        self.technique = technique
        self.classLevel = classLevel?.isEmpty == true ? nil : classLevel
        self.notes = notes?.isEmpty == true ? nil : notes
    }
}

/// What services a location offers (facilities)
struct ServicesCapability: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let serviceType: ServiceType
    let notes: String?

    nonisolated init(id: UUID = UUID(), serviceType: ServiceType, notes: String? = nil) {
        self.id = id
        self.serviceType = serviceType
        self.notes = notes?.isEmpty == true ? nil : notes
    }
}

/// Unified location model with capability-based architecture
struct UnifiedLocationModel: @preconcurrency LocationModel, Codable {
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

    // Capabilities (what this location offers)
    let retailCapabilities: [RetailCapability]
    let educationCapabilities: [EducationCapability]
    let servicesCapabilities: [ServicesCapability]

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
        retailCapabilities: [RetailCapability] = [],
        educationCapabilities: [EducationCapability] = [],
        servicesCapabilities: [ServicesCapability] = []
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
        self.retailCapabilities = retailCapabilities
        self.educationCapabilities = educationCapabilities
        self.servicesCapabilities = servicesCapabilities
    }

    // MARK: - Identifiable

    nonisolated var id: String { stable_id }

    // MARK: - Business Logic

    /// Check if location sells glass for a specific technique
    nonisolated func sells(_ technique: TechniqueType) -> Bool {
        return retailCapabilities.contains(where: { $0.technique == technique })
    }

    /// Check if location teaches a specific technique
    nonisolated func teaches(_ technique: TechniqueType) -> Bool {
        return educationCapabilities.contains(where: { $0.technique == technique })
    }

    /// Check if location offers a specific service
    nonisolated func offers(_ service: ServiceType) -> Bool {
        return servicesCapabilities.contains(where: { $0.serviceType == service })
    }

    /// Get all techniques this location sells
    nonisolated var retailTechniques: [TechniqueType] {
        return retailCapabilities.map { $0.technique }
    }

    /// Get all techniques this location teaches
    nonisolated var educationTechniques: [TechniqueType] {
        return educationCapabilities.map { $0.technique }
    }

    /// Get all services this location offers
    nonisolated var services: [ServiceType] {
        return servicesCapabilities.map { $0.serviceType }
    }

    /// Check if location has any retail capabilities
    nonisolated var hasRetail: Bool {
        return !retailCapabilities.isEmpty
    }

    /// Check if location has any education capabilities
    nonisolated var hasEducation: Bool {
        return !educationCapabilities.isEmpty
    }

    /// Check if location has any service capabilities
    nonisolated var hasServices: Bool {
        return !servicesCapabilities.isEmpty
    }

    // MARK: - Address & Location

    /// Full formatted address for display
    nonisolated var fullAddress: String? {
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
    nonisolated var compactAddress: String? {
        var components: [String] = []

        if let city = city {
            components.append(city)
        }
        if let state = state {
            components.append(state)
        }

        return components.isEmpty ? nil : components.joined(separator: ", ")
    }

    /// Check if location has valid coordinates
    nonisolated var hasValidLocation: Bool {
        return latitude != 0.0 && longitude != 0.0
    }

    /// CoreLocation coordinate for map display
    nonisolated var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Check if location has complete address information
    nonisolated var hasCompleteAddress: Bool {
        return addressLine1 != nil && city != nil && state != nil
    }

    /// Check if location has any address information
    nonisolated var hasAnyAddress: Bool {
        return addressLine1 != nil || city != nil || state != nil || zip != nil
    }

    /// Formatted phone number for display (basic formatting)
    nonisolated var formattedPhone: String? {
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
    nonisolated var displayName: String {
        return isVerified ? "\(name) ✓" : name
    }

    /// Distance from a given coordinate (in meters)
    nonisolated func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard hasValidLocation else { return nil }

        let locationHere = CLLocation(latitude: latitude, longitude: longitude)
        let otherLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return locationHere.distance(from: otherLocation)
    }

    /// Formatted distance string (miles or km based on locale)
    nonisolated func formattedDistance(from coordinate: CLLocationCoordinate2D) -> String? {
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

    // MARK: - Search & Filtering

    /// Check if location matches search text
    nonisolated func matchesSearchText(_ searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()

        return name.lowercased().contains(lowercaseSearch) ||
               (addressLine1?.lowercased().contains(lowercaseSearch) ?? false) ||
               (city?.lowercased().contains(lowercaseSearch) ?? false) ||
               (state?.lowercased().contains(lowercaseSearch) ?? false) ||
               (zip?.lowercased().contains(lowercaseSearch) ?? false) ||
               (notes?.lowercased().contains(lowercaseSearch) ?? false) ||
               retailTechniques.contains(where: { $0.displayName.lowercased().contains(lowercaseSearch) }) ||
               educationTechniques.contains(where: { $0.displayName.lowercased().contains(lowercaseSearch) }) ||
               services.contains(where: { $0.displayName.lowercased().contains(lowercaseSearch) })
    }

    // MARK: - Validation

    /// Validate that the location has required data
    nonisolated var isValid: Bool {
        return !stable_id.isEmpty && !name.isEmpty
    }

    /// Get validation errors if any
    nonisolated var validationErrors: [String] {
        var errors: [String] = []

        if stable_id.isEmpty {
            errors.append("Location ID is required")
        }

        if name.isEmpty {
            errors.append("Location name is required")
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

    /// Check if location has enough info to be useful
    nonisolated var hasMinimumInfo: Bool {
        return isValid && (hasAnyAddress || hasValidLocation || websiteUrl != nil)
    }
}

// MARK: - LocationModel Conformance

extension UnifiedLocationModel {
    /// Check if location sells casting glass
    nonisolated var supportsCasting: Bool {
        sells(.casting) || teaches(.casting)
    }

    /// Check if location sells hard glass flameworking supplies
    nonisolated var supportsFlameworkingHard: Bool {
        sells(.flameworkinghard) || teaches(.flameworkinghard)
    }

    /// Check if location sells soft glass flameworking supplies
    nonisolated var supportsFlameworkingSoft: Bool {
        sells(.flameworkingsoft) || teaches(.flameworkingsoft)
    }

    /// Check if location sells fusing glass
    nonisolated var supportsFusing: Bool {
        sells(.fusing) || teaches(.fusing)
    }

    /// Check if location sells glass blowing supplies
    nonisolated var supportsGlassBlowing: Bool {
        sells(.glassBlowing) || teaches(.glassBlowing)
    }

    /// Check if location sells stained glass supplies
    nonisolated var supportsStainedGlass: Bool {
        sells(.stainedGlass) || teaches(.stainedGlass)
    }

    /// Check if location sells other glass supplies
    nonisolated var supportsOther: Bool {
        sells(.other) || teaches(.other)
    }

    /// Get array of supported techniques (combination of retail and education)
    nonisolated var techniques: [TechniqueType] {
        let allTechniques = Set(retailTechniques + educationTechniques)
        return Array(allTechniques).sorted { $0.displayName < $1.displayName }
    }

    /// Formatted list of technique names for display
    nonisolated var techniquesDisplay: String {
        let supportedTechniques = techniques
        guard !supportedTechniques.isEmpty else { return "No techniques listed" }
        return supportedTechniques.map { $0.displayName }.joined(separator: ", ")
    }

    /// Check if location supports a specific technique (either retail or education)
    nonisolated func supportsTechnique(_ technique: TechniqueType) -> Bool {
        return sells(technique) || teaches(technique)
    }
}

// MARK: - Helper Extensions

extension UnifiedLocationModel {
    /// Create a location with generated stable_id from name
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
        retailCapabilities: [RetailCapability] = [],
        educationCapabilities: [EducationCapability] = [],
        servicesCapabilities: [ServicesCapability] = []
    ) -> UnifiedLocationModel {
        // Generate stable_id from name (simple slug)
        let stableId = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

        return UnifiedLocationModel(
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
            retailCapabilities: retailCapabilities,
            educationCapabilities: educationCapabilities,
            servicesCapabilities: servicesCapabilities
        )
    }
}
