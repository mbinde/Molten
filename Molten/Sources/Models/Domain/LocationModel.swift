//
//  LocationModel.swift
//  Molten
//
//  Created for Location Feature on 11/1/25.
//

import Foundation
import CoreLocation

/// Protocol for location-based entities (stores, classes, etc.)
/// Defines shared fields and business logic for places with addresses and techniques
/// Note: Conforming types should add Codable separately if needed for JSON serialization
protocol LocationModel: Identifiable, Sendable {
    nonisolated var stable_id: String { get }
    nonisolated var name: String { get }
    nonisolated var addressLine1: String? { get }
    nonisolated var addressLine2: String? { get }
    nonisolated var city: String? { get }
    nonisolated var state: String? { get }
    nonisolated var zip: String? { get }
    nonisolated var latitude: Double { get }
    nonisolated var longitude: Double { get }
    nonisolated var websiteUrl: String? { get }
    nonisolated var phone: String? { get }
    nonisolated var hoursJson: String? { get }
    nonisolated var heroImagePath: String? { get }
    nonisolated var notes: String? { get }
    nonisolated var isVerified: Bool { get }

    // Technique support
    nonisolated var supportsCasting: Bool { get }
    nonisolated var supportsFlameworkingHard: Bool { get }
    nonisolated var supportsFlameworkingSoft: Bool { get }
    nonisolated var supportsFusing: Bool { get }
    nonisolated var supportsGlassBlowing: Bool { get }
    nonisolated var supportsStainedGlass: Bool { get }
    nonisolated var supportsOther: Bool { get }
}

// MARK: - Default Implementations (Shared Business Logic)

extension LocationModel {
    /// ID for Identifiable conformance
    nonisolated var id: String { stable_id }

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

    /// Check if location has valid coordinates
    nonisolated var hasValidLocation: Bool {
        return latitude != 0.0 && longitude != 0.0
    }

    /// CoreLocation coordinate for map display
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Check if location has complete address information
    var hasCompleteAddress: Bool {
        return addressLine1 != nil && city != nil && state != nil
    }

    /// Check if location has any address information
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

    /// Check if location matches search text
    nonisolated func matchesSearchText(_ searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()

        return name.lowercased().contains(lowercaseSearch) ||
               (addressLine1?.lowercased().contains(lowercaseSearch) ?? false) ||
               (city?.lowercased().contains(lowercaseSearch) ?? false) ||
               (state?.lowercased().contains(lowercaseSearch) ?? false) ||
               (notes?.lowercased().contains(lowercaseSearch) ?? false) ||
               techniques.contains(where: { $0.displayName.lowercased().contains(lowercaseSearch) })
    }

    /// Check if location supports a specific technique
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

    /// Validate that the location has required data
    var isValid: Bool {
        return !stable_id.isEmpty && !name.isEmpty
    }

    /// Get validation errors if any
    var validationErrors: [String] {
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
    var hasMinimumInfo: Bool {
        return isValid && (hasAnyAddress || hasValidLocation || websiteUrl != nil)
    }
}
