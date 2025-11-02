//
//  AnyLocationModel.swift
//  Molten
//
//  Created for unified Locations feature on 11/1/25.
//

import Foundation
import CoreLocation

/// Type-erased wrapper for any LocationModel with its associated type
struct AnyLocationModel: Identifiable, Equatable, Hashable {
    let type: LocationType
    private let _model: any LocationModel

    var id: String { _model.id }

    // Forward all LocationModel properties
    var stable_id: String { _model.stable_id }
    var name: String { _model.name }
    var addressLine1: String? { _model.addressLine1 }
    var addressLine2: String? { _model.addressLine2 }
    var city: String? { _model.city }
    var state: String? { _model.state }
    var zip: String? { _model.zip }
    var latitude: Double { _model.latitude }
    var longitude: Double { _model.longitude }
    var websiteUrl: String? { _model.websiteUrl }
    var phone: String? { _model.phone }
    var hoursJson: String? { _model.hoursJson }
    var heroImagePath: String? { _model.heroImagePath }
    var notes: String? { _model.notes }
    var isVerified: Bool { _model.isVerified }
    var supportsCasting: Bool { _model.supportsCasting }
    var supportsFlameworkingHard: Bool { _model.supportsFlameworkingHard }
    var supportsFlameworkingSoft: Bool { _model.supportsFlameworkingSoft }
    var supportsFusing: Bool { _model.supportsFusing }
    var supportsGlassBlowing: Bool { _model.supportsGlassBlowing }
    var supportsStainedGlass: Bool { _model.supportsStainedGlass }
    var supportsOther: Bool { _model.supportsOther }

    // Forward computed properties
    var fullAddress: String? { _model.fullAddress }
    var compactAddress: String? { _model.compactAddress }
    var hasValidLocation: Bool { _model.hasValidLocation }
    var coordinate: CLLocationCoordinate2D { _model.coordinate }
    var hasCompleteAddress: Bool { _model.hasCompleteAddress }
    var hasAnyAddress: Bool { _model.hasAnyAddress }
    var formattedPhone: String? { _model.formattedPhone }
    var displayName: String { _model.displayName }
    var techniques: [TechniqueType] { _model.techniques }
    var techniquesDisplay: String { _model.techniquesDisplay }
    var isValid: Bool { _model.isValid }
    var validationErrors: [String] { _model.validationErrors }
    var hasMinimumInfo: Bool { _model.hasMinimumInfo }

    // Capability properties
    var hasRetail: Bool { _model.hasRetail }
    var hasEducation: Bool { _model.hasEducation }
    var hasServices: Bool { _model.hasServices }

    // Forward methods
    func matchesSearchText(_ searchText: String) -> Bool {
        _model.matchesSearchText(searchText)
    }

    func supportsTechnique(_ technique: TechniqueType) -> Bool {
        _model.supportsTechnique(technique)
    }

    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        _model.distance(from: coordinate)
    }

    func formattedDistance(from coordinate: CLLocationCoordinate2D) -> String? {
        _model.formattedDistance(from: coordinate)
    }

    // Initializers for each concrete type
    init(unified: UnifiedLocationModel) {
        // Determine primary type based on capabilities
        // Priority: retail > education > services
        if unified.hasRetail {
            self.type = .store
        } else if unified.hasEducation {
            self.type = .classLocation
        } else {
            // Default to store if only services or nothing
            self.type = .store
        }
        self._model = unified
    }

    // Equatable conformance
    static func == (lhs: AnyLocationModel, rhs: AnyLocationModel) -> Bool {
        lhs.stable_id == rhs.stable_id && lhs.type == rhs.type
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(stable_id)
        hasher.combine(type)
    }
}
