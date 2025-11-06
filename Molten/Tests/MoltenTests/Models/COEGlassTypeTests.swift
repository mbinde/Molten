//
//  COEGlassTypeTests.swift
//  MoltenTests
//
//  Unit tests for COEGlassType enum
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
@Suite("COEGlassType Tests")
struct COEGlassTypeTests {

    // MARK: - Raw Value Tests

    @Test("coe33 has correct raw value")
    func testCOE33RawValue() {
        #expect(COEGlassType.coe33.rawValue == 33)
    }

    @Test("coe90 has correct raw value")
    func testCOE90RawValue() {
        #expect(COEGlassType.coe90.rawValue == 90)
    }

    @Test("coe96 has correct raw value")
    func testCOE96RawValue() {
        #expect(COEGlassType.coe96.rawValue == 96)
    }

    @Test("coe104 has correct raw value")
    func testCOE104RawValue() {
        #expect(COEGlassType.coe104.rawValue == 104)
    }

    @Test("COEGlassType can be initialized from raw value")
    func testInitFromRawValue() {
        #expect(COEGlassType(rawValue: 33) == .coe33)
        #expect(COEGlassType(rawValue: 90) == .coe90)
        #expect(COEGlassType(rawValue: 96) == .coe96)
        #expect(COEGlassType(rawValue: 104) == .coe104)
    }

    @Test("COEGlassType returns nil for invalid raw value")
    func testInvalidRawValue() {
        #expect(COEGlassType(rawValue: 0) == nil)
        #expect(COEGlassType(rawValue: 50) == nil)
        #expect(COEGlassType(rawValue: 100) == nil)
        #expect(COEGlassType(rawValue: -1) == nil)
    }

    // MARK: - CaseIterable Tests

    @Test("allCases contains all COE types")
    func testAllCases() {
        let allCases = COEGlassType.allCases

        #expect(allCases.count == 4)
        #expect(allCases.contains(.coe33))
        #expect(allCases.contains(.coe90))
        #expect(allCases.contains(.coe96))
        #expect(allCases.contains(.coe104))
    }

    @Test("allCases order is consistent")
    func testAllCasesOrder() {
        let allCases = COEGlassType.allCases

        #expect(allCases[0] == .coe33)
        #expect(allCases[1] == .coe90)
        #expect(allCases[2] == .coe96)
        #expect(allCases[3] == .coe104)
    }

    @Test("allCases are in ascending order by raw value")
    func testAllCasesAscending() {
        let rawValues = COEGlassType.allCases.map { $0.rawValue }

        for i in 0..<(rawValues.count - 1) {
            #expect(rawValues[i] < rawValues[i + 1])
        }
    }

    // MARK: - Display Name Tests

    @Test("coe33 has correct display name")
    func testCOE33DisplayName() {
        #expect(COEGlassType.coe33.displayName == "COE 33")
    }

    @Test("coe90 has correct display name")
    func testCOE90DisplayName() {
        #expect(COEGlassType.coe90.displayName == "COE 90")
    }

    @Test("coe96 has correct display name")
    func testCOE96DisplayName() {
        #expect(COEGlassType.coe96.displayName == "COE 96")
    }

    @Test("coe104 has correct display name")
    func testCOE104DisplayName() {
        #expect(COEGlassType.coe104.displayName == "COE 104")
    }

    @Test("All display names start with 'COE '")
    func testDisplayNamesFormat() {
        for coeType in COEGlassType.allCases {
            #expect(coeType.displayName.hasPrefix("COE "))
        }
    }

    @Test("All display names are not empty")
    func testAllDisplayNamesNotEmpty() {
        for coeType in COEGlassType.allCases {
            #expect(!coeType.displayName.isEmpty)
        }
    }

    @Test("Display name includes raw value")
    func testDisplayNameIncludesRawValue() {
        for coeType in COEGlassType.allCases {
            let rawValueString = "\(coeType.rawValue)"
            #expect(coeType.displayName.contains(rawValueString))
        }
    }

    @Test("Each COE type has unique display name")
    func testUniqueDisplayNames() {
        let names = COEGlassType.allCases.map { $0.displayName }
        let uniqueNames = Set(names)

        #expect(names.count == uniqueNames.count)
    }

    // MARK: - safeInit Tests

    @Test("safeInit with valid raw value returns correct case")
    func testSafeInitValid() {
        #expect(COEGlassType.safeInit(from: 33) == .coe33)
        #expect(COEGlassType.safeInit(from: 90) == .coe90)
        #expect(COEGlassType.safeInit(from: 96) == .coe96)
        #expect(COEGlassType.safeInit(from: 104) == .coe104)
    }

    @Test("safeInit with invalid raw value returns coe96 default")
    func testSafeInitInvalidReturnsDefault() {
        #expect(COEGlassType.safeInit(from: 0) == .coe96)
        #expect(COEGlassType.safeInit(from: 50) == .coe96)
        #expect(COEGlassType.safeInit(from: 100) == .coe96)
        #expect(COEGlassType.safeInit(from: -1) == .coe96)
        #expect(COEGlassType.safeInit(from: 999) == .coe96)
    }

    @Test("safeInit never returns nil")
    func testSafeInitNeverReturnsNil() {
        let testValues = [-100, -1, 0, 1, 50, 80, 95, 100, 200, 999]

        for value in testValues {
            let result = COEGlassType.safeInit(from: value)
            #expect(result != nil)
        }
    }

    @Test("safeInit default is coe96")
    func testSafeInitDefaultIsCOE96() {
        // COE 96 is most common, so it's the default
        #expect(COEGlassType.safeInit(from: 999) == .coe96)
    }

    // MARK: - Hashable Tests

    @Test("COE types are hashable")
    func testHashable() {
        let set: Set<COEGlassType> = [.coe33, .coe90, .coe96, .coe104]

        #expect(set.count == 4)
        #expect(set.contains(.coe33))
        #expect(set.contains(.coe90))
        #expect(set.contains(.coe96))
        #expect(set.contains(.coe104))
    }

    @Test("Same COE types have same hash")
    func testHashEquality() {
        let coe96_a = COEGlassType.coe96
        let coe96_b = COEGlassType.coe96

        #expect(coe96_a.hashValue == coe96_b.hashValue)
    }

    @Test("Different COE types can be used as dictionary keys")
    func testDictionaryKeys() {
        let dict: [COEGlassType: String] = [
            .coe33: "Borosilicate",
            .coe90: "Soft glass",
            .coe96: "Fusible glass",
            .coe104: "Soda lime"
        ]

        #expect(dict[.coe33] == "Borosilicate")
        #expect(dict[.coe90] == "Soft glass")
        #expect(dict[.coe96] == "Fusible glass")
        #expect(dict[.coe104] == "Soda lime")
    }

    // MARK: - Equatable Tests

    @Test("COEGlassType equality works correctly")
    func testEquality() {
        #expect(COEGlassType.coe33 == COEGlassType.coe33)
        #expect(COEGlassType.coe90 == COEGlassType.coe90)
        #expect(COEGlassType.coe96 == COEGlassType.coe96)
        #expect(COEGlassType.coe104 == COEGlassType.coe104)

        #expect(COEGlassType.coe33 != COEGlassType.coe90)
        #expect(COEGlassType.coe96 != COEGlassType.coe104)
    }

    // MARK: - Raw Value Uniqueness Tests

    @Test("All raw values are unique")
    func testAllRawValuesUnique() {
        let rawValues = COEGlassType.allCases.map { $0.rawValue }
        let uniqueRawValues = Set(rawValues)

        #expect(rawValues.count == uniqueRawValues.count)
    }

    @Test("Raw values match actual COE values")
    func testRawValuesMatchCOEValues() {
        // These should match real-world COE (Coefficient of Expansion) values
        #expect(COEGlassType.coe33.rawValue == 33)  // Borosilicate
        #expect(COEGlassType.coe90.rawValue == 90)  // Soft glass
        #expect(COEGlassType.coe96.rawValue == 96)  // Fusible glass
        #expect(COEGlassType.coe104.rawValue == 104) // Soda lime
    }

    // MARK: - Real-World Usage Tests

    @Test("Bullseye glass is COE 90")
    func testBullseyeGlassCOE() {
        // Bullseye glass is known to be COE 90
        let bullseyeCOE = COEGlassType.coe90
        #expect(bullseyeCOE.displayName == "COE 90")
    }

    @Test("Fusible glass is typically COE 96")
    func testFusibleGlassCOE() {
        // Most fusible glass for art is COE 96
        let fusibleCOE = COEGlassType.coe96
        #expect(fusibleCOE.rawValue == 96)
    }

    @Test("Borosilicate is COE 33")
    func testBorosilicateCOE() {
        // Borosilicate (like Pyrex) is COE 33
        let boroCOE = COEGlassType.coe33
        #expect(boroCOE.rawValue == 33)
    }

    @Test("COE types can be used in switch statements")
    func testSwitchStatement() {
        for coeType in COEGlassType.allCases {
            let description: String
            switch coeType {
            case .coe33:
                description = "Borosilicate"
            case .coe90:
                description = "Soft glass"
            case .coe96:
                description = "Fusible glass"
            case .coe104:
                description = "Soda lime"
            }
            #expect(!description.isEmpty)
        }
    }

    @Test("COE compatibility check logic")
    func testCOECompatibility() {
        // Glass with same COE can be fused together
        let item1COE = COEGlassType.coe96
        let item2COE = COEGlassType.coe96

        #expect(item1COE == item2COE) // Compatible

        let item3COE = COEGlassType.coe90
        #expect(item1COE != item3COE) // Not compatible
    }

    @Test("safeInit handles database migration scenarios")
    func testSafeInitDatabaseMigration() {
        // When migrating old data, invalid COE values should default to coe96
        let unknownCOE = COEGlassType.safeInit(from: 0)
        #expect(unknownCOE == .coe96)

        // Valid values should be preserved
        let validCOE = COEGlassType.safeInit(from: 90)
        #expect(validCOE == .coe90)
    }

    @Test("All COE types can be stored in arrays")
    func testArrayStorage() {
        let coeTypes: [COEGlassType] = [.coe33, .coe90, .coe96, .coe104]

        #expect(coeTypes.count == 4)
        #expect(coeTypes[0] == .coe33)
        #expect(coeTypes[3] == .coe104)
    }

    @Test("COE types can be compared for sorting")
    func testSorting() {
        let unsorted: [COEGlassType] = [.coe104, .coe33, .coe96, .coe90]
        let sorted = unsorted.sorted { $0.rawValue < $1.rawValue }

        #expect(sorted[0] == .coe33)
        #expect(sorted[1] == .coe90)
        #expect(sorted[2] == .coe96)
        #expect(sorted[3] == .coe104)
    }

    // MARK: - Edge Cases

    @Test("safeInit with boundary values")
    func testSafeInitBoundaryValues() {
        #expect(COEGlassType.safeInit(from: Int.min) == .coe96)
        #expect(COEGlassType.safeInit(from: Int.max) == .coe96)
    }

    @Test("Raw values are positive integers")
    func testRawValuesPositive() {
        for coeType in COEGlassType.allCases {
            #expect(coeType.rawValue > 0)
        }
    }

    @Test("Display names have consistent formatting")
    func testDisplayNameFormatting() {
        for coeType in COEGlassType.allCases {
            let displayName = coeType.displayName

            // Should be "COE XX" or "COE XXX"
            #expect(displayName.hasPrefix("COE "))

            let parts = displayName.split(separator: " ")
            #expect(parts.count == 2)
            #expect(parts[0] == "COE")
        }
    }

    @Test("safeInit preserves valid values through round-trip")
    func testSafeInitRoundTrip() {
        for coeType in COEGlassType.allCases {
            let rawValue = coeType.rawValue
            let restored = COEGlassType.safeInit(from: rawValue)

            #expect(restored == coeType)
        }
    }

    @Test("COE types work with filter operations")
    func testFilterOperations() {
        let allTypes = COEGlassType.allCases

        let fusibleOnly = allTypes.filter { $0.rawValue >= 90 }
        #expect(fusibleOnly.count == 3) // 90, 96, 104

        let boroOnly = allTypes.filter { $0.rawValue < 50 }
        #expect(boroOnly.count == 1) // 33
    }

    @Test("Display names are suitable for UI display")
    func testDisplayNamesUICompatibility() {
        for coeType in COEGlassType.allCases {
            let displayName = coeType.displayName

            // Short enough for labels
            #expect(displayName.count < 20)

            // No special characters that might break UI
            #expect(!displayName.contains("\n"))
            #expect(!displayName.contains("\t"))
        }
    }

    @Test("COE values match industry standards")
    func testCOEValuesIndustryStandards() {
        // These are actual COE values used in glass industry
        let standardCOEs = [33, 90, 96, 104]
        let implementedCOEs = COEGlassType.allCases.map { $0.rawValue }

        #expect(Set(standardCOEs) == Set(implementedCOEs))
    }

    @Test("safeInit is truly safe and never crashes")
    func testSafeInitNeverCrashes() {
        // Test a wide range of potentially problematic values
        let edgeCases = [
            Int.min, Int.min + 1,
            -1000, -100, -10, -1, 0,
            1, 10, 32, 34, 89, 91, 95, 97, 103, 105,
            1000, 10000,
            Int.max - 1, Int.max
        ]

        for value in edgeCases {
            let result = COEGlassType.safeInit(from: value)
            // Should always return a valid COE type, never crash
            #expect(COEGlassType.allCases.contains(result))
        }
    }
}
