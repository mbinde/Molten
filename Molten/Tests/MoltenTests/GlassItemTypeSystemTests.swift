//
//  GlassItemTypeSystemTests.swift
//  MoltenTests
//
//  Tests for GlassItemTypeSystem with simplified terminology.
//

import Testing
import Foundation
@testable import Molten

@Suite("GlassItemTypeSystem Tests")
@MainActor
struct GlassItemTypeSystemTests {

    @Test("Default display names are Bar and Rod")
    func testDefaultDisplayNames() {
        // Given: Type definitions
        let rod = GlassItemTypeSystem.rod
        let bigRod = GlassItemTypeSystem.bigRod

        // Then: Default display names are set correctly
        #expect(rod.displayName == "Rods")
        #expect(bigRod.displayName == "Bars")
    }

    @Test("Backend type names remain stable")
    func testBackendTypeNamesStable() {
        // Given: Type definitions
        let rod = GlassItemTypeSystem.rod
        let bigRod = GlassItemTypeSystem.bigRod

        // Then: Backend names never change (critical for data storage)
        #expect(rod.name == "rod")
        #expect(bigRod.name == "big-rod")
    }

    @Test("Display name uses terminology settings for rod types")
    func testDisplayNameUsesTerminologySettings() {
        // Given: Custom terminology settings
        let settings = GlassTerminologySettings.shared
        settings.bigRodDisplayName = "Large Rod"
        settings.rodDisplayName = "Small Rod"

        // When: Getting display names via GlassItemTypeSystem
        let bigRodDisplay = GlassItemTypeSystem.displayName(for: "big-rod")
        let rodDisplay = GlassItemTypeSystem.displayName(for: "rod")

        // Then: Custom names are used
        #expect(bigRodDisplay == "Large Rod")
        #expect(rodDisplay == "Small Rod")

        // Cleanup
        settings.resetToDefaults()
    }

    @Test("Display name uses static names for non-rod types")
    func testDisplayNameForNonRodTypes() {
        // When: Getting display names for non-rod types
        let fritDisplay = GlassItemTypeSystem.displayName(for: "frit")
        let tubeDisplay = GlassItemTypeSystem.displayName(for: "tube")
        let stringerDisplay = GlassItemTypeSystem.displayName(for: "stringer")

        // Then: Capitalized backend names are used
        #expect(fritDisplay == "Frit")
        #expect(tubeDisplay == "Tubes")
        #expect(stringerDisplay == "Stringers")
    }

    @Test("All type names are available")
    func testAllTypeNamesAvailable() {
        // When: Getting all type names
        let allTypes = GlassItemTypeSystem.allTypeNames

        // Then: All expected types are present
        #expect(allTypes.contains("rod"))
        #expect(allTypes.contains("big-rod"))
        #expect(allTypes.contains("frit"))
        #expect(allTypes.contains("tube"))
        #expect(allTypes.contains("stringer"))
        #expect(allTypes.contains("sheet"))
        #expect(allTypes.contains("powder"))
        #expect(allTypes.contains("scrap"))
        #expect(allTypes.contains("murrini-cane"))
        #expect(allTypes.contains("murrini-slice"))
        // Note: "enamel" type was removed from the system

        // And: Count matches expected
        #expect(allTypes.count == 10)
    }

    @Test("Backend type name resolves from display name")
    func testBackendTypeNameFromDisplayName() {
        // Given: Default terminology settings
        let settings = GlassTerminologySettings.shared
        settings.resetToDefaults()

        // When/Then: Backend types resolve correctly
        #expect(GlassItemTypeSystem.backendTypeName(from: "Bars") == "big-rod")
        #expect(GlassItemTypeSystem.backendTypeName(from: "Rods") == "rod")
        #expect(GlassItemTypeSystem.backendTypeName(from: "Frit") == "frit")
        #expect(GlassItemTypeSystem.backendTypeName(from: "Tubes") == "tube")
    }

    @Test("Backend type name resolves custom display names")
    func testBackendTypeNameFromCustomDisplayName() {
        // Given: Custom terminology settings
        let settings = GlassTerminologySettings.shared
        settings.bigRodDisplayName = "Large"
        settings.rodDisplayName = "Standard"

        // When/Then: Custom names resolve to correct backend types
        #expect(GlassItemTypeSystem.backendTypeName(from: "Large") == "big-rod")
        #expect(GlassItemTypeSystem.backendTypeName(from: "Standard") == "rod")

        // Cleanup
        settings.resetToDefaults()
    }

    @Test("Type system has correct dimension fields for rod types")
    func testDimensionFieldsForRodTypes() {
        // When: Getting dimension fields for rod types
        let rodFields = GlassItemTypeSystem.getDimensionFields(for: "rod")
        let bigRodFields = GlassItemTypeSystem.getDimensionFields(for: "big-rod")

        // Then: Both have diameter and length
        #expect(rodFields.count == 2)
        #expect(bigRodFields.count == 2)

        #expect(rodFields.contains { $0.name == "diameter" })
        #expect(rodFields.contains { $0.name == "length" })
        #expect(bigRodFields.contains { $0.name == "diameter" })
        #expect(bigRodFields.contains { $0.name == "length" })
    }

    @Test("Rod type has expected subtypes")
    func testRodSubtypes() {
        // When: Getting subtypes for rod
        let rodSubtypes = GlassItemTypeSystem.getSubtypes(for: "rod")

        // Then: Expected subtypes are present
        #expect(rodSubtypes.contains("standard"))
        #expect(rodSubtypes.contains("cane"))
        #expect(rodSubtypes.contains("pull"))
    }

    @Test("Big rod type has no subtypes")
    func testBigRodNoSubtypes() {
        // When: Getting subtypes for big-rod
        let bigRodSubtypes = GlassItemTypeSystem.getSubtypes(for: "big-rod")

        // Then: No subtypes
        #expect(bigRodSubtypes.isEmpty)
    }

    @Test("Type validation works correctly")
    func testTypeValidation() {
        // When/Then: Valid types are recognized
        #expect(GlassItemTypeSystem.isValidType("rod"))
        #expect(GlassItemTypeSystem.isValidType("big-rod"))
        #expect(GlassItemTypeSystem.isValidType("frit"))

        // And: Invalid types are rejected
        #expect(!GlassItemTypeSystem.isValidType("invalid"))
        #expect(!GlassItemTypeSystem.isValidType(""))
    }
}
