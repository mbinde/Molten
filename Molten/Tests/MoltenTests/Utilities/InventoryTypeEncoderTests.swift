//
//  InventoryTypeEncoderTests.swift
//  MoltenTests
//
//  Tests for InventoryTypeEncoder - compact QR code URL encoding/decoding
//

import Testing
import Foundation
@testable import Molten

@Suite("InventoryTypeEncoder Tests")
@MainActor
struct InventoryTypeEncoderTests {

    // MARK: - Type Encoding Tests

    @Test("Encode primary types correctly")
    func encodePrimaryTypes() async throws {
        #expect(InventoryTypeEncoder.encode(type: "rod") == "r")
        #expect(InventoryTypeEncoder.encode(type: "tube") == "t")
        #expect(InventoryTypeEncoder.encode(type: "sheet") == "s")
        #expect(InventoryTypeEncoder.encode(type: "frit") == "f")
        #expect(InventoryTypeEncoder.encode(type: "powder") == "p")
        #expect(InventoryTypeEncoder.encode(type: "stringer") == "g")
        #expect(InventoryTypeEncoder.encode(type: "accessory") == "a")
        #expect(InventoryTypeEncoder.encode(type: "tool") == "l")
        #expect(InventoryTypeEncoder.encode(type: "enamel") == "e")
        #expect(InventoryTypeEncoder.encode(type: "billet") == "b")
        #expect(InventoryTypeEncoder.encode(type: "cullet") == "c")
        #expect(InventoryTypeEncoder.encode(type: "noodle") == "n")
        #expect(InventoryTypeEncoder.encode(type: "confetti") == "k")
        #expect(InventoryTypeEncoder.encode(type: "murrine") == "m")
    }

    @Test("Encode type is case insensitive")
    func encodeTypeIsCaseInsensitive() async throws {
        #expect(InventoryTypeEncoder.encode(type: "ROD") == "r")
        #expect(InventoryTypeEncoder.encode(type: "Frit") == "f")
        #expect(InventoryTypeEncoder.encode(type: "TUBE") == "t")
    }

    @Test("Encode unknown type returns nil")
    func encodeUnknownTypeReturnsNil() async throws {
        #expect(InventoryTypeEncoder.encode(type: "unknown") == nil)
        #expect(InventoryTypeEncoder.encode(type: "invalid") == nil)
        #expect(InventoryTypeEncoder.encode(type: "") == nil)
    }

    // MARK: - Subtype Encoding Tests

    @Test("Encode frit subtypes correctly")
    func encodeFritSubtypes() async throws {
        #expect(InventoryTypeEncoder.encode(type: "frit", subtype: "coarse") == "fc")
        #expect(InventoryTypeEncoder.encode(type: "frit", subtype: "medium") == "fm")
        #expect(InventoryTypeEncoder.encode(type: "frit", subtype: "fine") == "ff")
        #expect(InventoryTypeEncoder.encode(type: "frit", subtype: "powder") == "fp")
    }

    @Test("Encode powder subtypes correctly")
    func encodePowderSubtypes() async throws {
        #expect(InventoryTypeEncoder.encode(type: "powder", subtype: "coarse") == "pc")
        #expect(InventoryTypeEncoder.encode(type: "powder", subtype: "medium") == "pm")
        #expect(InventoryTypeEncoder.encode(type: "powder", subtype: "fine") == "pf")
    }

    @Test("Encode sheet subtypes correctly")
    func encodeSheetSubtypes() async throws {
        #expect(InventoryTypeEncoder.encode(type: "sheet", subtype: "thin") == "st")
        #expect(InventoryTypeEncoder.encode(type: "sheet", subtype: "standard") == "ss")
        #expect(InventoryTypeEncoder.encode(type: "sheet", subtype: "thick") == "sk")
    }

    @Test("Encode rod subtypes correctly")
    func encodeRodSubtypes() async throws {
        #expect(InventoryTypeEncoder.encode(type: "rod", subtype: "solid") == "rs")
        #expect(InventoryTypeEncoder.encode(type: "rod", subtype: "hollow") == "rh")
    }

    @Test("Encode stringer subtypes correctly")
    func encodeStringerSubtypes() async throws {
        #expect(InventoryTypeEncoder.encode(type: "stringer", subtype: "thin") == "gt")
        #expect(InventoryTypeEncoder.encode(type: "stringer", subtype: "medium") == "gm")
        #expect(InventoryTypeEncoder.encode(type: "stringer", subtype: "thick") == "gk")
    }

    @Test("Unknown subtype is ignored")
    func unknownSubtypeIsIgnored() async throws {
        // Unknown subtype should be ignored, just return type code
        #expect(InventoryTypeEncoder.encode(type: "frit", subtype: "unknown") == "f")
        #expect(InventoryTypeEncoder.encode(type: "rod", subtype: "invalid") == "r")
    }

    @Test("Subtype for type without subtypes is ignored")
    func subtypeForTypeWithoutSubtypesIsIgnored() async throws {
        // Types like "tube" don't have subtypes defined
        #expect(InventoryTypeEncoder.encode(type: "tube", subtype: "anything") == "t")
        #expect(InventoryTypeEncoder.encode(type: "billet", subtype: "something") == "b")
    }

    // MARK: - Type Decoding Tests

    @Test("Decode primary types correctly")
    func decodePrimaryTypes() async throws {
        #expect(InventoryTypeEncoder.decode("r")?.type == "rod")
        #expect(InventoryTypeEncoder.decode("t")?.type == "tube")
        #expect(InventoryTypeEncoder.decode("s")?.type == "sheet")
        #expect(InventoryTypeEncoder.decode("f")?.type == "frit")
        #expect(InventoryTypeEncoder.decode("p")?.type == "powder")
        #expect(InventoryTypeEncoder.decode("g")?.type == "stringer")
        #expect(InventoryTypeEncoder.decode("a")?.type == "accessory")
        #expect(InventoryTypeEncoder.decode("l")?.type == "tool")
        #expect(InventoryTypeEncoder.decode("e")?.type == "enamel")
        #expect(InventoryTypeEncoder.decode("b")?.type == "billet")
        #expect(InventoryTypeEncoder.decode("c")?.type == "cullet")
        #expect(InventoryTypeEncoder.decode("n")?.type == "noodle")
        #expect(InventoryTypeEncoder.decode("k")?.type == "confetti")
        #expect(InventoryTypeEncoder.decode("m")?.type == "murrine")
    }

    @Test("Decode type only has nil subtype")
    func decodeTypeOnlyHasNilSubtype() async throws {
        let decoded = InventoryTypeEncoder.decode("r")
        #expect(decoded?.type == "rod")
        #expect(decoded?.subtype == nil)
        #expect(decoded?.subsubtype == nil)
    }

    @Test("Decode with subtype")
    func decodeWithSubtype() async throws {
        let fritCoarse = InventoryTypeEncoder.decode("fc")
        #expect(fritCoarse?.type == "frit")
        #expect(fritCoarse?.subtype == "coarse")
        #expect(fritCoarse?.subsubtype == nil)

        let sheetThin = InventoryTypeEncoder.decode("st")
        #expect(sheetThin?.type == "sheet")
        #expect(sheetThin?.subtype == "thin")
    }

    @Test("Decode unknown code returns nil")
    func decodeUnknownCodeReturnsNil() async throws {
        #expect(InventoryTypeEncoder.decode("x") == nil)
        #expect(InventoryTypeEncoder.decode("z") == nil)
        #expect(InventoryTypeEncoder.decode("") == nil)
    }

    @Test("Decode unknown subtype code leaves subtype nil")
    func decodeUnknownSubtypeCodeLeavesSubtypeNil() async throws {
        // "rx" - 'r' is rod, but 'x' is not a valid subtype for rod
        let decoded = InventoryTypeEncoder.decode("rx")
        #expect(decoded?.type == "rod")
        #expect(decoded?.subtype == nil)  // Unknown subtype ignored
    }

    // MARK: - Round Trip Tests

    @Test("Round trip encoding/decoding preserves type")
    func roundTripPreservesType() async throws {
        let types = ["rod", "tube", "sheet", "frit", "powder", "stringer",
                     "accessory", "tool", "enamel", "billet", "cullet",
                     "noodle", "confetti", "murrine"]

        for type in types {
            let encoded = InventoryTypeEncoder.encode(type: type)
            #expect(encoded != nil, "Failed to encode \(type)")

            let decoded = InventoryTypeEncoder.decode(encoded!)
            #expect(decoded?.type == type, "Round trip failed for \(type)")
        }
    }

    @Test("Round trip encoding/decoding preserves subtype")
    func roundTripPreservesSubtype() async throws {
        let testCases: [(type: String, subtype: String)] = [
            ("frit", "coarse"),
            ("frit", "medium"),
            ("frit", "fine"),
            ("powder", "fine"),
            ("sheet", "thin"),
            ("sheet", "standard"),
            ("rod", "solid"),
            ("rod", "hollow"),
            ("stringer", "medium"),
        ]

        for testCase in testCases {
            let encoded = InventoryTypeEncoder.encode(type: testCase.type, subtype: testCase.subtype)
            #expect(encoded != nil, "Failed to encode \(testCase)")

            let decoded = InventoryTypeEncoder.decode(encoded!)
            #expect(decoded?.type == testCase.type, "Type mismatch for \(testCase)")
            #expect(decoded?.subtype == testCase.subtype, "Subtype mismatch for \(testCase)")
        }
    }

    // MARK: - QR URL Building Tests

    @Test("Build QR URL with type only")
    func buildQRURLWithTypeOnly() async throws {
        let url = InventoryTypeEncoder.buildQRCodeURL(stableId: "abc123", type: "rod")
        #expect(url == "molten://i/abc123/r")
    }

    @Test("Build QR URL with type and subtype")
    func buildQRURLWithTypeAndSubtype() async throws {
        let url = InventoryTypeEncoder.buildQRCodeURL(stableId: "abc123", type: "frit", subtype: "coarse")
        #expect(url == "molten://i/abc123/fc")
    }

    @Test("Build QR URL with unknown type omits type code")
    func buildQRURLWithUnknownTypeOmitsTypeCode() async throws {
        let url = InventoryTypeEncoder.buildQRCodeURL(stableId: "abc123", type: "unknown")
        #expect(url == "molten://i/abc123")
    }

    // MARK: - QR URL Parsing Tests

    @Test("Parse QR URL with type code")
    func parseQRURLWithTypeCode() async throws {
        let url = URL(string: "molten://i/abc123/r")!
        let result = InventoryTypeEncoder.parseQRCodeURL(url)

        #expect(result?.stableId == "abc123")
        #expect(result?.type?.type == "rod")
    }

    @Test("Parse QR URL with type and subtype code")
    func parseQRURLWithTypeAndSubtypeCode() async throws {
        let url = URL(string: "molten://i/abc123/fc")!
        let result = InventoryTypeEncoder.parseQRCodeURL(url)

        #expect(result?.stableId == "abc123")
        #expect(result?.type?.type == "frit")
        #expect(result?.type?.subtype == "coarse")
    }

    @Test("Parse QR URL without type code")
    func parseQRURLWithoutTypeCode() async throws {
        let url = URL(string: "molten://i/abc123")!
        let result = InventoryTypeEncoder.parseQRCodeURL(url)

        #expect(result?.stableId == "abc123")
        #expect(result?.type == nil)
    }

    @Test("Parse invalid URL returns nil")
    func parseInvalidURLReturnsNil() async throws {
        // Wrong scheme
        let wrongScheme = URL(string: "https://i/abc123/r")!
        #expect(InventoryTypeEncoder.parseQRCodeURL(wrongScheme) == nil)

        // Wrong host
        let wrongHost = URL(string: "molten://g/abc123/r")!
        #expect(InventoryTypeEncoder.parseQRCodeURL(wrongHost) == nil)

        // No path
        let noPath = URL(string: "molten://i")!
        #expect(InventoryTypeEncoder.parseQRCodeURL(noPath) == nil)
    }

    // MARK: - Display Name Tests

    @Test("Display name for type only")
    func displayNameForTypeOnly() async throws {
        #expect(InventoryTypeEncoder.displayName(type: "rod") == "Rod")
        #expect(InventoryTypeEncoder.displayName(type: "frit") == "Frit")
        #expect(InventoryTypeEncoder.displayName(type: "tube") == "Tube")
    }

    @Test("Display name with subtype")
    func displayNameWithSubtype() async throws {
        #expect(InventoryTypeEncoder.displayName(type: "frit", subtype: "coarse") == "Coarse Frit")
        #expect(InventoryTypeEncoder.displayName(type: "sheet", subtype: "thin") == "Thin Sheet")
        #expect(InventoryTypeEncoder.displayName(type: "rod", subtype: "hollow") == "Hollow Rod")
    }

    @Test("Display name with subtype and subsubtype")
    func displayNameWithSubtypeAndSubsubtype() async throws {
        // Currently subsubtype codes aren't defined, but test the format
        let name = InventoryTypeEncoder.displayName(type: "frit", subtype: "coarse", subsubtype: "special")
        #expect(name == "Special Coarse Frit")
    }
}
