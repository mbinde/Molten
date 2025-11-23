//
//  GlassTerminologySettingsTests.swift
//  MoltenTests
//
//  Tests for simplified terminology settings with default display names.
//

import Testing
import Foundation
@testable import Molten

@Suite("GlassTerminologySettings Tests")
@MainActor
struct GlassTerminologySettingsTests {

    @Test("Default display names are Bar and Rod")
    func testDefaultDisplayNames() {
        // Given: Reset to defaults (clear any cached values from other tests)
        let settings = GlassTerminologySettings.shared
        settings.resetToDefaults()

        // Then: Default display names should be set
        #expect(settings.bigRodDisplayName == "Bars")
        #expect(settings.rodDisplayName == "Rods")
    }

    @Test("Display name returns correct value for backend types")
    func testDisplayNameForBackendTypes() {
        // Given: Settings with default names
        let settings = GlassTerminologySettings.shared
        settings.bigRodDisplayName = "Bars"
        settings.rodDisplayName = "Rods"

        // When/Then: Display names match backend types
        #expect(settings.displayName(for: "big-rod") == "Bars")
        #expect(settings.displayName(for: "rod") == "Rods")
        #expect(settings.displayName(for: "frit") == "Frit")
        #expect(settings.displayName(for: "tube") == "Tubes")
    }

    @Test("Backend type returns correct value from display names")
    func testBackendTypeFromDisplayName() {
        // Given: Settings with default names
        let settings = GlassTerminologySettings.shared
        settings.bigRodDisplayName = "Bars"
        settings.rodDisplayName = "Rods"

        // When/Then: Backend types resolve correctly
        #expect(settings.backendType(from: "Bars") == "big-rod")
        #expect(settings.backendType(from: "bars") == "big-rod")  // Case insensitive
        #expect(settings.backendType(from: "Rods") == "rod")
        #expect(settings.backendType(from: "rods") == "rod")
        #expect(settings.backendType(from: "Frit") == "frit")
    }

    @Test("Custom display names are persisted")
    func testCustomDisplayNamesPersistence() {
        // Given: Settings with custom names
        let settings = GlassTerminologySettings.shared

        // When: Setting custom display names
        settings.bigRodDisplayName = "Large Rod"
        settings.rodDisplayName = "Small Rod"

        // Then: Names are stored in UserDefaults
        #expect(UserDefaults.standard.string(forKey: "bigRodDisplayName") == "Large Rod")
        #expect(UserDefaults.standard.string(forKey: "rodDisplayName") == "Small Rod")

        // And: Display names work correctly
        #expect(settings.displayName(for: "big-rod") == "Large Rod")
        #expect(settings.displayName(for: "rod") == "Small Rod")
    }

    @Test("Reset to defaults restores Bar and Rod")
    func testResetToDefaults() {
        // Given: Settings with custom names
        let settings = GlassTerminologySettings.shared
        settings.bigRodDisplayName = "Custom Bar"
        settings.rodDisplayName = "Custom Rod"

        // When: Resetting to defaults
        settings.resetToDefaults()

        // Then: Names are restored
        #expect(settings.bigRodDisplayName == "Bars")
        #expect(settings.rodDisplayName == "Rods")
    }

    @Test("Detailed display name with size information")
    func testDetailedDisplayNameWithSize() {
        // Given: Settings with default names
        let settings = GlassTerminologySettings.shared
        settings.bigRodDisplayName = "Bars"
        settings.rodDisplayName = "Rods"

        // When/Then: Detailed names include size info when requested
        #expect(settings.detailedDisplayName(for: "big-rod", includeSize: true) == "Bars (12mm+)")
        #expect(settings.detailedDisplayName(for: "rod", includeSize: true) == "Rods (5-6mm)")
        #expect(settings.detailedDisplayName(for: "frit", includeSize: true) == "Frit")

        // And: Without size info, just returns display name
        #expect(settings.detailedDisplayName(for: "big-rod", includeSize: false) == "Bars")
        #expect(settings.detailedDisplayName(for: "rod", includeSize: false) == "Rods")
    }

    @Test("Backend type constants remain stable")
    func testBackendTypeConstants() {
        // Then: Backend type constants never change (critical for data storage)
        #expect(GlassTerminologySettings.bigRodType == "big-rod")
        #expect(GlassTerminologySettings.rodType == "rod")
    }

    @Test("Custom display names resolve to correct backend types")
    func testCustomDisplayNamesResolveCorrectly() {
        // Given: Settings with custom names
        let settings = GlassTerminologySettings.shared
        settings.bigRodDisplayName = "Large"
        settings.rodDisplayName = "Standard"

        // When/Then: Backend types still resolve correctly
        #expect(settings.backendType(from: "Large") == "big-rod")
        #expect(settings.backendType(from: "Standard") == "rod")

        // And: Display names work correctly
        #expect(settings.displayName(for: "big-rod") == "Large")
        #expect(settings.displayName(for: "rod") == "Standard")
    }
}
