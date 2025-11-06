//
//  LocationTypeTests.swift
//  MoltenTests
//
//  Unit tests for LocationType enum
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Molten

@MainActor
@Suite("LocationType Tests")
struct LocationTypeTests {

    // MARK: - Raw Value Tests

    @Test("store has correct raw value")
    func testStoreRawValue() {
        #expect(LocationType.store.rawValue == "store")
    }

    @Test("classLocation has correct raw value")
    func testClassLocationRawValue() {
        #expect(LocationType.classLocation.rawValue == "class")
    }

    @Test("workshop has correct raw value")
    func testWorkshopRawValue() {
        #expect(LocationType.workshop.rawValue == "workshop")
    }

    @Test("LocationType can be initialized from raw value")
    func testInitFromRawValue() {
        #expect(LocationType(rawValue: "store") == .store)
        #expect(LocationType(rawValue: "class") == .classLocation)
        #expect(LocationType(rawValue: "workshop") == .workshop)
    }

    @Test("LocationType returns nil for invalid raw value")
    func testInvalidRawValue() {
        #expect(LocationType(rawValue: "invalid") == nil)
        #expect(LocationType(rawValue: "") == nil)
        #expect(LocationType(rawValue: "Store") == nil) // Case-sensitive
    }

    // MARK: - Display Name Tests

    @Test("store has correct display name")
    func testStoreDisplayName() {
        #expect(LocationType.store.displayName == "Stores")
    }

    @Test("classLocation has correct display name")
    func testClassLocationDisplayName() {
        #expect(LocationType.classLocation.displayName == "Classes")
    }

    @Test("workshop has correct display name")
    func testWorkshopDisplayName() {
        #expect(LocationType.workshop.displayName == "Workshops")
    }

    // MARK: - Singular Name Tests

    @Test("store has correct singular name")
    func testStoreSingularName() {
        #expect(LocationType.store.singularName == "Store")
    }

    @Test("classLocation has correct singular name")
    func testClassLocationSingularName() {
        #expect(LocationType.classLocation.singularName == "Class")
    }

    @Test("workshop has correct singular name")
    func testWorkshopSingularName() {
        #expect(LocationType.workshop.singularName == "Workshop")
    }

    // MARK: - Icon Tests

    @Test("store has correct icon name")
    func testStoreIconName() {
        #expect(LocationType.store.iconName == "storefront")
    }

    @Test("classLocation has correct icon name")
    func testClassLocationIconName() {
        #expect(LocationType.classLocation.iconName == "graduationcap")
    }

    @Test("workshop has correct icon name")
    func testWorkshopIconName() {
        #expect(LocationType.workshop.iconName == "hammer")
    }

    @Test("All icons are valid SF Symbol names")
    func testIconsAreValidSFSymbols() {
        // SF Symbols should be lowercase without spaces
        for locationType in LocationType.allCases {
            let iconName = locationType.iconName
            #expect(!iconName.isEmpty)
            #expect(iconName == iconName.lowercased() || iconName.contains("."))
        }
    }

    // MARK: - Identifiable Tests

    @Test("ID matches raw value")
    func testIdMatchesRawValue() {
        for locationType in LocationType.allCases {
            #expect(locationType.id == locationType.rawValue)
        }
    }

    // MARK: - CaseIterable Tests

    @Test("allCases contains all location types")
    func testAllCases() {
        let allCases = LocationType.allCases

        #expect(allCases.count == 3)
        #expect(allCases.contains(.store))
        #expect(allCases.contains(.classLocation))
        #expect(allCases.contains(.workshop))
    }

    @Test("allCases order is consistent")
    func testAllCasesOrder() {
        let allCases = LocationType.allCases

        #expect(allCases[0] == .store)
        #expect(allCases[1] == .classLocation)
        #expect(allCases[2] == .workshop)
    }

    // MARK: - Codable Tests

    @Test("LocationType can be encoded to JSON")
    func testEncodingToJSON() throws {
        let locationType = LocationType.store
        let encoder = JSONEncoder()

        let data = try encoder.encode(locationType)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString == "\"store\"")
    }

    @Test("LocationType can be decoded from JSON")
    func testDecodingFromJSON() throws {
        let jsonData = "\"class\"".data(using: .utf8)!
        let decoder = JSONDecoder()

        let locationType = try decoder.decode(LocationType.self, from: jsonData)

        #expect(locationType == .classLocation)
    }

    @Test("All location types can be encoded and decoded")
    func testRoundTripCoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for locationType in LocationType.allCases {
            let encoded = try encoder.encode(locationType)
            let decoded = try decoder.decode(LocationType.self, from: encoded)
            #expect(decoded == locationType)
        }
    }

    @Test("Decoding invalid JSON throws error")
    func testDecodingInvalidJSON() throws {
        let jsonData = "\"invalid_type\"".data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            _ = try decoder.decode(LocationType.self, from: jsonData)
            Issue.record("Expected decoding to fail for invalid type")
        } catch {
            // Expected to throw
            #expect(true)
        }
    }

    // MARK: - Equatable Tests

    @Test("LocationType equality works correctly")
    func testEquality() {
        #expect(LocationType.store == LocationType.store)
        #expect(LocationType.store != LocationType.classLocation)
        #expect(LocationType.classLocation == LocationType.classLocation)
        #expect(LocationType.workshop == LocationType.workshop)
    }

    // MARK: - Comprehensive Coverage Tests

    @Test("All cases have valid display names")
    func testAllCasesHaveDisplayNames() {
        for locationType in LocationType.allCases {
            #expect(!locationType.displayName.isEmpty)
        }
    }

    @Test("All cases have valid singular names")
    func testAllCasesHaveSingularNames() {
        for locationType in LocationType.allCases {
            #expect(!locationType.singularName.isEmpty)
        }
    }

    @Test("All cases have valid icon names")
    func testAllCasesHaveIconNames() {
        for locationType in LocationType.allCases {
            #expect(!locationType.iconName.isEmpty)
        }
    }

    @Test("Display names are pluralized")
    func testDisplayNamesArePluralized() {
        // Plural forms should end with 's'
        #expect(LocationType.store.displayName.hasSuffix("s"))
        #expect(LocationType.classLocation.displayName.hasSuffix("es"))
        #expect(LocationType.workshop.displayName.hasSuffix("s"))
    }

    @Test("Singular names are not pluralized")
    func testSingularNamesAreNotPluralized() {
        #expect(LocationType.store.singularName == "Store")
        #expect(LocationType.classLocation.singularName == "Class")
        #expect(LocationType.workshop.singularName == "Workshop")
    }
}
