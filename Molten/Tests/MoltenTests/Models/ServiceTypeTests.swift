//
//  ServiceTypeTests.swift
//  MoltenTests
//
//  Unit tests for ServiceType enum
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

@Suite("ServiceType Tests")
struct ServiceTypeTests {

    // MARK: - Display Name Tests

    @Test("kilnRental has correct display name")
    func testKilnRentalDisplayName() {
        let serviceType = ServiceType.kilnRental
        #expect(serviceType.displayName == "Kiln Rental")
    }

    @Test("torchRental has correct display name")
    func testTorchRentalDisplayName() {
        let serviceType = ServiceType.torchRental
        #expect(serviceType.displayName == "Torch Rental")
    }

    @Test("hotshopAccess has correct display name")
    func testHotshopAccessDisplayName() {
        let serviceType = ServiceType.hotshopAccess
        #expect(serviceType.displayName == "Hot Shop Access")
    }

    @Test("toolRental has correct display name")
    func testToolRentalDisplayName() {
        let serviceType = ServiceType.toolRental
        #expect(serviceType.displayName == "Tool Rental")
    }

    @Test("studioSpace has correct display name")
    func testStudioSpaceDisplayName() {
        let serviceType = ServiceType.studioSpace
        #expect(serviceType.displayName == "Studio Space")
    }

    @Test("other has correct display name")
    func testOtherDisplayName() {
        let serviceType = ServiceType.other
        #expect(serviceType.displayName == "Other Services")
    }

    // MARK: - Icon Tests

    @Test("kilnRental has correct icon")
    func testKilnRentalIcon() {
        let serviceType = ServiceType.kilnRental
        #expect(serviceType.icon == "fireplace.fill")
    }

    @Test("torchRental has correct icon")
    func testTorchRentalIcon() {
        let serviceType = ServiceType.torchRental
        #expect(serviceType.icon == "flame.fill")
    }

    @Test("hotshopAccess has correct icon")
    func testHotshopAccessIcon() {
        let serviceType = ServiceType.hotshopAccess
        #expect(serviceType.icon == "building.2.fill")
    }

    @Test("toolRental has correct icon")
    func testToolRentalIcon() {
        let serviceType = ServiceType.toolRental
        #expect(serviceType.icon == "wrench.and.screwdriver.fill")
    }

    @Test("studioSpace has correct icon")
    func testStudioSpaceIcon() {
        let serviceType = ServiceType.studioSpace
        #expect(serviceType.icon == "square.split.2x2.fill")
    }

    @Test("other has correct icon")
    func testOtherIcon() {
        let serviceType = ServiceType.other
        #expect(serviceType.icon == "ellipsis.circle.fill")
    }

    // MARK: - Codable Tests

    @Test("ServiceType can be encoded to JSON")
    func testEncodingToJSON() throws {
        let serviceType = ServiceType.kilnRental
        let encoder = JSONEncoder()

        let data = try encoder.encode(serviceType)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString == "\"kiln_rental\"")
    }

    @Test("ServiceType can be decoded from JSON")
    func testDecodingFromJSON() throws {
        let jsonData = "\"torch_rental\"".data(using: .utf8)!
        let decoder = JSONDecoder()

        let serviceType = try decoder.decode(ServiceType.self, from: jsonData)

        #expect(serviceType == .torchRental)
    }

    @Test("All service types can be encoded and decoded")
    func testRoundTripCoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for serviceType in ServiceType.allCases {
            let encoded = try encoder.encode(serviceType)
            let decoded = try decoder.decode(ServiceType.self, from: encoded)
            #expect(decoded == serviceType)
        }
    }

    // MARK: - RawValue Tests

    @Test("ServiceType raw values are correct")
    func testRawValues() {
        #expect(ServiceType.kilnRental.rawValue == "kiln_rental")
        #expect(ServiceType.torchRental.rawValue == "torch_rental")
        #expect(ServiceType.hotshopAccess.rawValue == "hotshop_access")
        #expect(ServiceType.toolRental.rawValue == "tool_rental")
        #expect(ServiceType.studioSpace.rawValue == "studio_space")
        #expect(ServiceType.other.rawValue == "other")
    }

    @Test("ServiceType can be initialized from raw value")
    func testInitFromRawValue() {
        #expect(ServiceType(rawValue: "kiln_rental") == .kilnRental)
        #expect(ServiceType(rawValue: "torch_rental") == .torchRental)
        #expect(ServiceType(rawValue: "hotshop_access") == .hotshopAccess)
        #expect(ServiceType(rawValue: "tool_rental") == .toolRental)
        #expect(ServiceType(rawValue: "studio_space") == .studioSpace)
        #expect(ServiceType(rawValue: "other") == .other)
    }

    @Test("ServiceType returns nil for invalid raw value")
    func testInvalidRawValue() {
        #expect(ServiceType(rawValue: "invalid") == nil)
        #expect(ServiceType(rawValue: "") == nil)
        #expect(ServiceType(rawValue: "kiln") == nil)
    }

    // MARK: - CaseIterable Tests

    @Test("ServiceType allCases contains all service types")
    func testAllCases() {
        let allCases = ServiceType.allCases

        #expect(allCases.count == 6)
        #expect(allCases.contains(.kilnRental))
        #expect(allCases.contains(.torchRental))
        #expect(allCases.contains(.hotshopAccess))
        #expect(allCases.contains(.toolRental))
        #expect(allCases.contains(.studioSpace))
        #expect(allCases.contains(.other))
    }

    @Test("ServiceType allCases order is consistent")
    func testAllCasesOrder() {
        let allCases = ServiceType.allCases

        // Verify expected order
        #expect(allCases[0] == .kilnRental)
        #expect(allCases[1] == .torchRental)
        #expect(allCases[2] == .hotshopAccess)
        #expect(allCases[3] == .toolRental)
        #expect(allCases[4] == .studioSpace)
        #expect(allCases[5] == .other)
    }

    // MARK: - Equatable Tests

    @Test("ServiceType equality works correctly")
    func testEquality() {
        #expect(ServiceType.kilnRental == ServiceType.kilnRental)
        #expect(ServiceType.kilnRental != ServiceType.torchRental)
        #expect(ServiceType.other == ServiceType.other)
    }

    // MARK: - Icon SFSymbol Validation

    @Test("All icons are valid SF Symbol names")
    func testIconsAreValidSFSymbols() {
        // All icons should contain "fill" or be valid SF Symbol patterns
        for serviceType in ServiceType.allCases {
            let icon = serviceType.icon
            // SF Symbols typically contain dots or underscores
            #expect(icon.contains(".") || icon.contains("_"))
        }
    }
}
