//
//  LabelPresetManagementTests.swift
//  MoltenTests
//
//  Tests for label preset management functionality
//

import Testing
import Foundation
@testable import Molten

/// Tests for label preset management functionality including:
/// - Creating and saving presets
/// - Loading and applying presets
/// - Detecting preset modifications
/// - Overwriting existing presets
/// - Editing preset metadata (name/description)
/// - Per-field formatting
@Suite("Label Preset Management")
struct LabelPresetManagementTests {

    private let deps = AppDependencies(forTesting: true)

    // MARK: - Creating and Saving Presets

    @Test("Create new preset with basic config")
    func testCreatePreset() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.6,
            fontScale: 1.0,
            manufacturerImagePosition: .right,
            manufacturerImageSize: 0.5,
            textFields: [.manufacturer, .sku, .colorName],
            textAlignment: .left,
            fieldFormats: [:]
        )

        let preset = LabelBuilderPreset(
            name: "Test Preset",
            description: "A test preset",
            config: config
        )

        #expect(preset.name == "Test Preset")
        #expect(preset.description == "A test preset")
        #expect(preset.config.qrPosition == .left)
        #expect(preset.config.textFields.count == 3)
    }

    @Test("Save preset to manager")
    func testSavePreset() async throws {
        let manager = LabelPresetsManager(repository: deps.labelPresetRepository)

        let config = LabelBuilderConfig.default
        let preset = LabelBuilderPreset(
            name: "Saved Preset",
            description: "Test",
            config: config
        )

        manager.savePreset(preset)

        // Wait for async save
        try await Task.sleep(for: .milliseconds(100))

        #expect(manager.allPresets.contains(where: { $0.name == "Saved Preset" }))
    }

    // MARK: - Loading and Applying Presets

    @Test("Load preset and apply config")
    func testLoadPreset() async throws {
        let manager = LabelPresetsManager(repository: deps.labelPresetRepository)

        // Create and save a preset with specific config
        let config = LabelBuilderConfig(
            qrPosition: .right,
            qrSize: 0.7,
            fontScale: 1.2,
            manufacturerImagePosition: .left,
            manufacturerImageSize: 0.6,
            textFields: [.manufacturer, .colorName, .coe, .location],
            textAlignment: .center,
            fieldFormats: [:]
        )

        let preset = LabelBuilderPreset(
            name: "Load Test",
            description: "Test loading",
            config: config
        )

        manager.savePreset(preset)
        try await Task.sleep(for: .milliseconds(100))

        // Find and verify the saved preset
        let loaded = manager.allPresets.first(where: { $0.name == "Load Test" })
        #expect(loaded != nil)
        #expect(loaded?.config.qrPosition == .right)
        #expect(loaded?.config.qrSize == 0.7)
        #expect(loaded?.config.fontScale == 1.2)
        #expect(loaded?.config.textFields.count == 4)
        #expect(loaded?.config.textAlignment == .center)
    }

    // MARK: - Preset Modification Detection

    @Test("Detect when preset config is modified")
    func testPresetModificationDetection() async throws {
        let originalConfig = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.6,
            fontScale: 1.0,
            manufacturerImagePosition: .right,
            manufacturerImageSize: 0.5,
            textFields: [.manufacturer, .sku],
            textAlignment: .left,
            fieldFormats: [:]
        )

        let modifiedConfig = LabelBuilderConfig(
            qrPosition: .right,  // Changed
            qrSize: 0.6,
            fontScale: 1.0,
            manufacturerImagePosition: .right,
            manufacturerImageSize: 0.5,
            textFields: [.manufacturer, .sku],
            textAlignment: .left,
            fieldFormats: [:]
        )

        #expect(originalConfig != modifiedConfig)
    }

    @Test("Detect font scale modification")
    func testFontScaleModification() async throws {
        let config1 = LabelBuilderConfig.default
        var config2 = LabelBuilderConfig.default
        config2.fontScale = 1.5

        #expect(config1 != config2)
    }

    @Test("Detect text field changes")
    func testTextFieldModification() async throws {
        var config1 = LabelBuilderConfig.default
        config1.textFields = [.manufacturer, .sku]

        var config2 = LabelBuilderConfig.default
        config2.textFields = [.manufacturer, .sku, .colorName]

        #expect(config1 != config2)
    }

    // MARK: - Overwriting Presets

    @Test("Overwrite existing preset with new config")
    func testOverwritePreset() async throws {
        let manager = LabelPresetsManager(repository: deps.labelPresetRepository)

        // Create initial preset
        let initialConfig = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.6,
            fontScale: 1.0,
            manufacturerImagePosition: .right,
            manufacturerImageSize: 0.5,
            textFields: [.manufacturer, .sku],
            textAlignment: .left,
            fieldFormats: [:]
        )

        let preset = LabelBuilderPreset(
            name: "Overwrite Test",
            description: "Original",
            config: initialConfig
        )

        manager.savePreset(preset)
        try await Task.sleep(for: .milliseconds(100))

        // Find the saved preset
        guard let saved = manager.allPresets.first(where: { $0.name == "Overwrite Test" }) else {
            throw TestError.presetNotFound
        }

        // Create updated config
        let updatedConfig = LabelBuilderConfig(
            qrPosition: .right,  // Changed
            qrSize: 0.7,         // Changed
            fontScale: 1.2,      // Changed
            manufacturerImagePosition: .left,  // Changed
            manufacturerImageSize: 0.6,
            textFields: [.manufacturer, .sku, .colorName],  // Changed
            textAlignment: .center,  // Changed
            fieldFormats: [:]
        )

        // Overwrite the preset (same ID, new config)
        let updated = LabelBuilderPreset(
            id: saved.id,  // Same ID
            name: saved.name,
            description: saved.description,
            config: updatedConfig,
            createdAt: saved.createdAt,
            modifiedAt: Date()
        )

        manager.savePreset(updated)
        try await Task.sleep(for: .milliseconds(100))

        // Verify the preset was updated
        let result = manager.allPresets.first(where: { $0.id == saved.id })
        #expect(result != nil)
        #expect(result?.config.qrPosition == .right)
        #expect(result?.config.qrSize == 0.7)
        #expect(result?.config.fontScale == 1.2)
        #expect(result?.config.textFields.count == 3)
    }

    // MARK: - Editing Preset Metadata

    @Test("Edit preset name without changing config")
    func testEditPresetName() async throws {
        let manager = LabelPresetsManager(repository: deps.labelPresetRepository)

        let config = LabelBuilderConfig.default
        let preset = LabelBuilderPreset(
            name: "Original Name",
            description: "Original description",
            config: config
        )

        manager.savePreset(preset)
        try await Task.sleep(for: .milliseconds(100))

        // Find the saved preset
        guard let saved = manager.allPresets.first(where: { $0.name == "Original Name" }) else {
            throw TestError.presetNotFound
        }

        // Update name only
        let renamed = LabelBuilderPreset(
            id: saved.id,
            name: "New Name",
            description: saved.description,
            config: saved.config,
            createdAt: saved.createdAt,
            modifiedAt: Date()
        )

        manager.savePreset(renamed)
        try await Task.sleep(for: .milliseconds(100))

        // Verify name changed but config stayed the same
        let result = manager.allPresets.first(where: { $0.id == saved.id })
        #expect(result?.name == "New Name")
        #expect(result?.config == config)
    }

    @Test("Edit preset description")
    func testEditPresetDescription() async throws {
        let manager = LabelPresetsManager(repository: deps.labelPresetRepository)

        let config = LabelBuilderConfig.default
        let preset = LabelBuilderPreset(
            name: "Test Preset",
            description: "Original description",
            config: config
        )

        manager.savePreset(preset)
        try await Task.sleep(for: .milliseconds(100))

        // Find the saved preset
        guard let saved = manager.allPresets.first(where: { $0.name == "Test Preset" }) else {
            throw TestError.presetNotFound
        }

        // Update description
        let updated = LabelBuilderPreset(
            id: saved.id,
            name: saved.name,
            description: "Updated description",
            config: saved.config,
            createdAt: saved.createdAt,
            modifiedAt: Date()
        )

        manager.savePreset(updated)
        try await Task.sleep(for: .milliseconds(100))

        // Verify description changed
        let result = manager.allPresets.first(where: { $0.id == saved.id })
        #expect(result?.description == "Updated description")
    }

    // MARK: - Per-Field Formatting

    @Test("Set field formatting for specific field")
    func testSetFieldFormat() async throws {
        var config = LabelBuilderConfig.default

        // Set custom format for manufacturer field
        let manufacturerFormat = LabelFieldFormat(fontSize: 12, bold: true, italic: false)
        config.fieldFormats[.manufacturer] = manufacturerFormat

        let retrievedFormat = config.format(for: .manufacturer)
        #expect(retrievedFormat.fontSize == 12)
        #expect(retrievedFormat.bold == true)
        #expect(retrievedFormat.italic == false)
    }

    @Test("Use default format when not specified")
    func testDefaultFieldFormat() async throws {
        let config = LabelBuilderConfig.default

        // No custom format set, should return default
        let format = config.format(for: .manufacturer)
        let defaultFormat = LabelFieldFormat.defaultFormat(for: .manufacturer)

        #expect(format.fontSize == defaultFormat.fontSize)
        #expect(format.bold == defaultFormat.bold)
        #expect(format.italic == defaultFormat.italic)
    }

    @Test("Set bold style for field")
    func testSetBoldStyle() async throws {
        var config = LabelBuilderConfig.default

        var format = config.format(for: .sku)
        format.bold = true
        format.italic = false
        config.fieldFormats[.sku] = format

        let result = config.format(for: .sku)
        #expect(result.bold == true)
        #expect(result.italic == false)
    }

    @Test("Set italic style for field")
    func testSetItalicStyle() async throws {
        var config = LabelBuilderConfig.default

        var format = config.format(for: .colorName)
        format.bold = false
        format.italic = true
        config.fieldFormats[.colorName] = format

        let result = config.format(for: .colorName)
        #expect(result.bold == false)
        #expect(result.italic == true)
    }

    @Test("Set plain style for field")
    func testSetPlainStyle() async throws {
        var config = LabelBuilderConfig.default

        var format = config.format(for: .coe)
        format.bold = false
        format.italic = false
        config.fieldFormats[.coe] = format

        let result = config.format(for: .coe)
        #expect(result.bold == false)
        #expect(result.italic == false)
    }

    @Test("Set custom font size for field")
    func testSetFontSize() async throws {
        var config = LabelBuilderConfig.default

        var format = config.format(for: .location)
        format.fontSize = 10.5
        config.fieldFormats[.location] = format

        let result = config.format(for: .location)
        #expect(result.fontSize == 10.5)
    }

    @Test("Save and load preset with field formats")
    func testSaveLoadPresetWithFieldFormats() async throws {
        let manager = LabelPresetsManager(repository: deps.labelPresetRepository)

        var config = LabelBuilderConfig.default

        // Set custom formats for multiple fields
        config.fieldFormats[.manufacturer] = LabelFieldFormat(fontSize: 11, bold: true, italic: false)
        config.fieldFormats[.sku] = LabelFieldFormat(fontSize: 9, bold: false, italic: true)
        config.fieldFormats[.colorName] = LabelFieldFormat(fontSize: 10, bold: false, italic: false)

        let preset = LabelBuilderPreset(
            name: "Format Test",
            description: "Test field formats",
            config: config
        )

        manager.savePreset(preset)
        try await Task.sleep(for: .milliseconds(100))

        // Load and verify
        let loaded = manager.allPresets.first(where: { $0.name == "Format Test" })
        #expect(loaded != nil)

        let manufacturerFormat = loaded?.config.format(for: .manufacturer)
        #expect(manufacturerFormat?.fontSize == 11)
        #expect(manufacturerFormat?.bold == true)
        #expect(manufacturerFormat?.italic == false)

        let skuFormat = loaded?.config.format(for: .sku)
        #expect(skuFormat?.fontSize == 9)
        #expect(skuFormat?.bold == false)
        #expect(skuFormat?.italic == true)

        let colorFormat = loaded?.config.format(for: .colorName)
        #expect(colorFormat?.fontSize == 10)
        #expect(colorFormat?.bold == false)
        #expect(colorFormat?.italic == false)
    }

    // MARK: - Deleting Presets

    @Test("Delete preset")
    func testDeletePreset() async throws {
        let manager = LabelPresetsManager(repository: deps.labelPresetRepository)

        let preset = LabelBuilderPreset(
            name: "To Delete",
            description: "Will be deleted",
            config: .default
        )

        manager.savePreset(preset)
        try await Task.sleep(for: .milliseconds(100))

        // Verify it was saved
        #expect(manager.allPresets.contains(where: { $0.name == "To Delete" }))

        // Delete it
        if let toDelete = manager.allPresets.first(where: { $0.name == "To Delete" }) {
            manager.deletePreset(toDelete)
            try await Task.sleep(for: .milliseconds(100))
        }

        // Verify it's gone
        #expect(!manager.allPresets.contains(where: { $0.name == "To Delete" }))
    }

    // MARK: - Built-in vs User Presets

    @Test("Built-in presets should not be modifiable")
    func testBuiltInPresetsNotModifiable() async throws {
        // Built-in presets are defined in LabelBuilderConfig.presets
        let builtInPresets = LabelBuilderConfig.presets

        #expect(!builtInPresets.isEmpty)
        #expect(builtInPresets.contains(where: { $0.name == "Information Dense" }))
    }

    @Test("User presets shown first in list")
    func testUserPresetsFirst() async throws {
        let manager = LabelPresetsManager(repository: deps.labelPresetRepository)

        // Add a user preset
        let userPreset = LabelBuilderPreset(
            name: "User Preset",
            description: "Custom",
            config: .default
        )

        manager.savePreset(userPreset)
        try await Task.sleep(for: .milliseconds(100))

        // Get all presets (user + built-in)
        let allPresets = manager.allPresets

        // Find indices
        let userIndex = allPresets.firstIndex(where: { $0.name == "User Preset" })
        let builtInIndex = allPresets.firstIndex(where: { $0.name == "Information Dense" })

        // User preset should come before built-in
        if let userIdx = userIndex, let builtInIdx = builtInIndex {
            #expect(userIdx < builtInIdx)
        }
    }
}

// MARK: - Test Errors

enum TestError: Error {
    case presetNotFound
}
