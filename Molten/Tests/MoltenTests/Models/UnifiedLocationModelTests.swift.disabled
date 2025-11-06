//
//  UnifiedLocationModelTests.swift
//  MoltenTests
//
//  Unit tests for UnifiedLocationModel and related capability structs
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
import CoreLocation
@testable import Molten

@Suite("UnifiedLocationModel Tests")
@MainActor
struct UnifiedLocationModelTests {

    // MARK: - Initialization Tests

    @Test("Basic initialization with required fields")
    func testBasicInit() {
        let location = UnifiedLocationModel(
            stable_id: "test-location",
            name: "Test Location"
        )

        #expect(location.stable_id == "test-location")
        #expect(location.name == "Test Location")
        #expect(location.isVerified == false)
        #expect(location.retailCapabilities.isEmpty)
        #expect(location.educationCapabilities.isEmpty)
        #expect(location.servicesCapabilities.isEmpty)
    }

    @Test("Initialization trims whitespace from strings")
    func testInitTrimsWhitespace() {
        let location = UnifiedLocationModel(
            stable_id: "  test-id  ",
            name: "  Test Name  ",
            addressLine1: "  123 Main St  ",
            city: "  Portland  ",
            state: "  OR  "
        )

        #expect(location.stable_id == "test-id")
        #expect(location.name == "Test Name")
        #expect(location.addressLine1 == "123 Main St")
        #expect(location.city == "Portland")
        #expect(location.state == "OR")
    }

    @Test("Initialization converts empty strings to nil")
    func testInitEmptyStringsToNil() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Name",
            addressLine1: "",
            city: "",
            phone: "",
            websiteUrl: ""
        )

        #expect(location.addressLine1 == nil)
        #expect(location.city == nil)
        #expect(location.phone == nil)
        #expect(location.websiteUrl == nil)
    }

    // MARK: - Capability Tests

    @Test("Location with retail capabilities has retail")
    func testHasRetail() {
        let capability = RetailCapability(technique: .fusing)
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Store",
            retailCapabilities: [capability]
        )

        #expect(location.hasRetail == true)
        #expect(location.sells(.fusing) == true)
        #expect(location.sells(.glassBlowing) == false)
    }

    @Test("Location with education capabilities has education")
    func testHasEducation() {
        let capability = EducationCapability(technique: .flameworkinghard, classLevel: "beginner")
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test School",
            educationCapabilities: [capability]
        )

        #expect(location.hasEducation == true)
        #expect(location.teaches(.flameworkinghard) == true)
        #expect(location.teaches(.fusing) == false)
    }

    @Test("Location with services capabilities has services")
    func testHasServices() {
        let capability = ServicesCapability(serviceType: .kilnRental)
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Studio",
            servicesCapabilities: [capability]
        )

        #expect(location.hasServices == true)
        #expect(location.offers(.kilnRental) == true)
        #expect(location.offers(.torchRental) == false)
    }

    @Test("Get all retail techniques")
    func testRetailTechniques() {
        let capabilities = [
            RetailCapability(technique: .fusing),
            RetailCapability(technique: .glassBlowing)
        ]
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Store",
            retailCapabilities: capabilities
        )

        #expect(location.retailTechniques.count == 2)
        #expect(location.retailTechniques.contains(.fusing))
        #expect(location.retailTechniques.contains(.glassBlowing))
    }

    @Test("Get all education techniques")
    func testEducationTechniques() {
        let capabilities = [
            EducationCapability(technique: .flameworkingsoft),
            EducationCapability(technique: .stainedGlass)
        ]
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test School",
            educationCapabilities: capabilities
        )

        #expect(location.educationTechniques.count == 2)
        #expect(location.educationTechniques.contains(.flameworkingsoft))
        #expect(location.educationTechniques.contains(.stainedGlass))
    }

    @Test("Get all services")
    func testServices() {
        let capabilities = [
            ServicesCapability(serviceType: .kilnRental),
            ServicesCapability(serviceType: .studioSpace)
        ]
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Studio",
            servicesCapabilities: capabilities
        )

        #expect(location.services.count == 2)
        #expect(location.services.contains(.kilnRental))
        #expect(location.services.contains(.studioSpace))
    }

    // MARK: - Address Tests

    @Test("Full address formats correctly")
    func testFullAddress() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            addressLine1: "123 Main St",
            addressLine2: "Suite 200",
            city: "Portland",
            state: "OR",
            zip: "97201"
        )

        let expected = "123 Main St\nSuite 200\nPortland, OR, 97201"
        #expect(location.fullAddress == expected)
    }

    @Test("Full address handles missing address line 2")
    func testFullAddressNoLine2() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            addressLine1: "123 Main St",
            city: "Portland",
            state: "OR"
        )

        let expected = "123 Main St\nPortland, OR"
        #expect(location.fullAddress == expected)
    }

    @Test("Full address returns nil when no address components")
    func testFullAddressNil() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location"
        )

        #expect(location.fullAddress == nil)
    }

    @Test("Compact address formats correctly")
    func testCompactAddress() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            city: "Portland",
            state: "OR"
        )

        #expect(location.compactAddress == "Portland, OR")
    }

    @Test("Compact address handles missing state")
    func testCompactAddressNoState() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            city: "Portland"
        )

        #expect(location.compactAddress == "Portland")
    }

    @Test("Compact address returns nil when no city or state")
    func testCompactAddressNil() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            addressLine1: "123 Main St"
        )

        #expect(location.compactAddress == nil)
    }

    @Test("Has complete address checks required fields")
    func testHasCompleteAddress() {
        let complete = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            addressLine1: "123 Main St",
            city: "Portland",
            state: "OR"
        )

        let incomplete = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            addressLine1: "123 Main St",
            city: "Portland"
        )

        #expect(complete.hasCompleteAddress == true)
        #expect(incomplete.hasCompleteAddress == false)
    }

    @Test("Has any address detects partial address")
    func testHasAnyAddress() {
        let withAddress = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            city: "Portland"
        )

        let noAddress = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location"
        )

        #expect(withAddress.hasAnyAddress == true)
        #expect(noAddress.hasAnyAddress == false)
    }

    // MARK: - Location Coordinate Tests

    @Test("Valid location with non-zero coordinates")
    func testHasValidLocation() {
        let valid = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            latitude: 45.5231,
            longitude: -122.6765
        )

        let invalid = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            latitude: 0.0,
            longitude: 0.0
        )

        #expect(valid.hasValidLocation == true)
        #expect(invalid.hasValidLocation == false)
    }

    @Test("Coordinate returns CLLocationCoordinate2D")
    func testCoordinate() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            latitude: 45.5231,
            longitude: -122.6765
        )

        let coord = location.coordinate
        #expect(coord.latitude == 45.5231)
        #expect(coord.longitude == -122.6765)
    }

    @Test("Distance calculation from coordinate")
    func testDistance() {
        let portland = UnifiedLocationModel(
            stable_id: "portland",
            name: "Portland Store",
            latitude: 45.5231,
            longitude: -122.6765
        )

        // Seattle coordinates
        let seattleCoord = CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)

        let distance = portland.distance(from: seattleCoord)
        #expect(distance != nil)
        // Distance should be approximately 233 km (233000 meters)
        #expect(distance! > 200000)
        #expect(distance! < 250000)
    }

    @Test("Distance returns nil for invalid location")
    func testDistanceNil() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            latitude: 0.0,
            longitude: 0.0
        )

        let otherCoord = CLLocationCoordinate2D(latitude: 45.5231, longitude: -122.6765)
        #expect(location.distance(from: otherCoord) == nil)
    }

    @Test("Formatted distance in miles")
    func testFormattedDistance() {
        let portland = UnifiedLocationModel(
            stable_id: "portland",
            name: "Portland Store",
            latitude: 45.5231,
            longitude: -122.6765
        )

        let seattleCoord = CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)
        let formatted = portland.formattedDistance(from: seattleCoord)

        #expect(formatted != nil)
        #expect(formatted!.contains("mi"))
    }

    @Test("Formatted distance shows 'nearby' for very close locations")
    func testFormattedDistanceNearby() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            latitude: 45.5231,
            longitude: -122.6765
        )

        // Very close coordinate (about 100 meters away)
        let nearbyCoord = CLLocationCoordinate2D(latitude: 45.5240, longitude: -122.6770)
        let formatted = location.formattedDistance(from: nearbyCoord)

        #expect(formatted == "nearby")
    }

    // MARK: - Phone Formatting Tests

    @Test("Format 10-digit phone number")
    func testFormattedPhone() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            phone: "5035551234"
        )

        #expect(location.formattedPhone == "(503) 555-1234")
    }

    @Test("Format phone with existing formatting")
    func testFormattedPhoneWithFormatting() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            phone: "(503) 555-1234"
        )

        #expect(location.formattedPhone == "(503) 555-1234")
    }

    @Test("Phone with non-10 digits returns original")
    func testFormattedPhoneNon10Digits() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            phone: "555-1234"
        )

        #expect(location.formattedPhone == "555-1234")
    }

    @Test("Nil phone returns nil formatted phone")
    func testFormattedPhoneNil() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location"
        )

        #expect(location.formattedPhone == nil)
    }

    // MARK: - Display Name Tests

    @Test("Display name without verification badge")
    func testDisplayName() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            isVerified: false
        )

        #expect(location.displayName == "Test Location")
    }

    @Test("Display name with verification badge")
    func testDisplayNameVerified() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            isVerified: true
        )

        #expect(location.displayName == "Test Location ✓")
    }

    // MARK: - Search Tests

    @Test("Search by name")
    func testSearchByName() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Portland Glass Studio"
        )

        #expect(location.matchesSearchText("Portland") == true)
        #expect(location.matchesSearchText("Glass") == true)
        #expect(location.matchesSearchText("seattle") == false)
    }

    @Test("Search is case-insensitive")
    func testSearchCaseInsensitive() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Portland Glass Studio"
        )

        #expect(location.matchesSearchText("PORTLAND") == true)
        #expect(location.matchesSearchText("glass") == true)
    }

    @Test("Search by address")
    func testSearchByAddress() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            addressLine1: "123 Main Street",
            city: "Portland",
            state: "Oregon"
        )

        #expect(location.matchesSearchText("Main") == true)
        #expect(location.matchesSearchText("Portland") == true)
        #expect(location.matchesSearchText("Oregon") == true)
    }

    @Test("Search by technique")
    func testSearchByTechnique() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            retailCapabilities: [RetailCapability(technique: .fusing)]
        )

        #expect(location.matchesSearchText("fusing") == true)
        #expect(location.matchesSearchText("glass blowing") == false)
    }

    // MARK: - Validation Tests

    @Test("Valid location passes validation")
    func testValidLocation() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location"
        )

        #expect(location.isValid == true)
        #expect(location.validationErrors.isEmpty)
    }

    @Test("Empty stable_id fails validation")
    func testInvalidStableId() {
        let location = UnifiedLocationModel(
            stable_id: "",
            name: "Test Location"
        )

        #expect(location.isValid == false)
        #expect(location.validationErrors.contains("Location ID is required"))
    }

    @Test("Empty name fails validation")
    func testInvalidName() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: ""
        )

        #expect(location.isValid == false)
        #expect(location.validationErrors.contains("Location name is required"))
    }

    @Test("Invalid latitude fails validation")
    func testInvalidLatitude() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            latitude: 91.0,
            longitude: -122.0
        )

        #expect(location.validationErrors.contains("Invalid latitude (must be between -90 and 90)"))
    }

    @Test("Invalid longitude fails validation")
    func testInvalidLongitude() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            latitude: 45.0,
            longitude: 181.0
        )

        #expect(location.validationErrors.contains("Invalid longitude (must be between -180 and 180)"))
    }

    @Test("Has minimum info checks useful data")
    func testHasMinimumInfo() {
        let withAddress = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            city: "Portland"
        )

        let withLocation = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            latitude: 45.5231,
            longitude: -122.6765
        )

        let withWebsite = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            websiteUrl: "https://example.com"
        )

        let minimal = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location"
        )

        #expect(withAddress.hasMinimumInfo == true)
        #expect(withLocation.hasMinimumInfo == true)
        #expect(withWebsite.hasMinimumInfo == true)
        #expect(minimal.hasMinimumInfo == false)
    }

    // MARK: - LocationModel Conformance Tests

    @Test("Supports technique checks for retail or education")
    func testSupportsTechnique() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            retailCapabilities: [RetailCapability(technique: .fusing)],
            educationCapabilities: [EducationCapability(technique: .glassBlowing)]
        )

        #expect(location.supportsTechnique(.fusing) == true)
        #expect(location.supportsTechnique(.glassBlowing) == true)
        #expect(location.supportsTechnique(.stainedGlass) == false)
    }

    @Test("Techniques array combines retail and education")
    func testTechniques() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            retailCapabilities: [
                RetailCapability(technique: .fusing),
                RetailCapability(technique: .glassBlowing)
            ],
            educationCapabilities: [
                EducationCapability(technique: .fusing), // Duplicate should be deduplicated
                EducationCapability(technique: .stainedGlass)
            ]
        )

        let techniques = location.techniques
        #expect(techniques.count == 3) // fusing, glassBlowing, stainedGlass (deduped)
        #expect(techniques.contains(.fusing))
        #expect(techniques.contains(.glassBlowing))
        #expect(techniques.contains(.stainedGlass))
    }

    @Test("Techniques display formats as comma-separated list")
    func testTechniquesDisplay() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            retailCapabilities: [
                RetailCapability(technique: .fusing)
            ]
        )

        let empty = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location"
        )

        #expect(location.techniquesDisplay.contains("Fusing"))
        #expect(empty.techniquesDisplay == "No techniques listed")
    }

    @Test("Support flags for specific techniques")
    func testSupportFlags() {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            retailCapabilities: [
                RetailCapability(technique: .fusing),
                RetailCapability(technique: .flameworkinghard),
                RetailCapability(technique: .flameworkingsoft),
                RetailCapability(technique: .glassBlowing),
                RetailCapability(technique: .stainedGlass),
                RetailCapability(technique: .casting),
                RetailCapability(technique: .other)
            ]
        )

        #expect(location.supportsFusing == true)
        #expect(location.supportsFlameworkingHard == true)
        #expect(location.supportsFlameworkingSoft == true)
        #expect(location.supportsGlassBlowing == true)
        #expect(location.supportsStainedGlass == true)
        #expect(location.supportsCasting == true)
        #expect(location.supportsOther == true)
    }

    // MARK: - Helper Factory Tests

    @Test("Create helper generates stable_id from name")
    func testCreateHelper() {
        let location = UnifiedLocationModel.create(
            name: "Portland Glass Studio"
        )

        #expect(location.stable_id == "portland-glass-studio")
        #expect(location.name == "Portland Glass Studio")
    }

    @Test("Create helper handles special characters")
    func testCreateHelperSpecialChars() {
        let location = UnifiedLocationModel.create(
            name: "Bob's Glass & Art Studio!"
        )

        // Should remove special chars and convert to lowercase slug
        #expect(location.stable_id == "bobs-glass--art-studio")
    }

    // MARK: - Codable Tests

    @Test("UnifiedLocationModel can be encoded to JSON")
    func testEncodingToJSON() throws {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            latitude: 45.5231,
            longitude: -122.6765
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(location)

        #expect(data.count > 0)
    }

    @Test("UnifiedLocationModel can be decoded from JSON")
    func testDecodingFromJSON() throws {
        let location = UnifiedLocationModel(
            stable_id: "test-id",
            name: "Test Location",
            city: "Portland"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(location)
        let decoded = try decoder.decode(UnifiedLocationModel.self, from: data)

        #expect(decoded.stable_id == "test-id")
        #expect(decoded.name == "Test Location")
        #expect(decoded.city == "Portland")
    }
}

// MARK: - Capability Struct Tests

@Suite("RetailCapability Tests")
struct RetailCapabilityTests {

    @Test("Basic initialization")
    func testInit() {
        let capability = RetailCapability(technique: .fusing)

        #expect(capability.technique == .fusing)
        #expect(capability.notes == nil)
    }

    @Test("Initialization with notes")
    func testInitWithNotes() {
        let capability = RetailCapability(technique: .fusing, notes: "Full stock")

        #expect(capability.notes == "Full stock")
    }

    @Test("Empty notes converted to nil")
    func testEmptyNotesToNil() {
        let capability = RetailCapability(technique: .fusing, notes: "")

        #expect(capability.notes == nil)
    }

    @Test("Codable conformance")
    func testCodable() throws {
        let capability = RetailCapability(technique: .glassBlowing, notes: "Test notes")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(capability)
        let decoded = try decoder.decode(RetailCapability.self, from: data)

        #expect(decoded.technique == .glassBlowing)
        #expect(decoded.notes == "Test notes")
    }
}

@Suite("EducationCapability Tests")
struct EducationCapabilityTests {

    @Test("Basic initialization")
    func testInit() {
        let capability = EducationCapability(technique: .fusing)

        #expect(capability.technique == .fusing)
        #expect(capability.classLevel == nil)
        #expect(capability.notes == nil)
    }

    @Test("Initialization with class level")
    func testInitWithClassLevel() {
        let capability = EducationCapability(technique: .fusing, classLevel: "beginner")

        #expect(capability.classLevel == "beginner")
    }

    @Test("Empty class level converted to nil")
    func testEmptyClassLevelToNil() {
        let capability = EducationCapability(technique: .fusing, classLevel: "")

        #expect(capability.classLevel == nil)
    }

    @Test("Codable conformance")
    func testCodable() throws {
        let capability = EducationCapability(
            technique: .stainedGlass,
            classLevel: "advanced",
            notes: "Weekend classes"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(capability)
        let decoded = try decoder.decode(EducationCapability.self, from: data)

        #expect(decoded.technique == .stainedGlass)
        #expect(decoded.classLevel == "advanced")
        #expect(decoded.notes == "Weekend classes")
    }
}

@Suite("ServicesCapability Tests")
struct ServicesCapabilityTests {

    @Test("Basic initialization")
    func testInit() {
        let capability = ServicesCapability(serviceType: .kilnRental)

        #expect(capability.serviceType == .kilnRental)
        #expect(capability.notes == nil)
    }

    @Test("Initialization with notes")
    func testInitWithNotes() {
        let capability = ServicesCapability(serviceType: .studioSpace, notes: "By appointment")

        #expect(capability.notes == "By appointment")
    }

    @Test("Empty notes converted to nil")
    func testEmptyNotesToNil() {
        let capability = ServicesCapability(serviceType: .torchRental, notes: "")

        #expect(capability.notes == nil)
    }

    @Test("Codable conformance")
    func testCodable() throws {
        let capability = ServicesCapability(serviceType: .hotshopAccess, notes: "Members only")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(capability)
        let decoded = try decoder.decode(ServicesCapability.self, from: data)

        #expect(decoded.serviceType == .hotshopAccess)
        #expect(decoded.notes == "Members only")
    }
}
