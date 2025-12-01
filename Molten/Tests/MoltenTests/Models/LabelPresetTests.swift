//
//  LabelPresetTests.swift
//  MoltenTests
//
//  Tests for LabelBuilderPreset - specifically the recommended_label field
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

@Suite("LabelBuilderPreset Tests")
@MainActor
struct LabelPresetTests {

    // MARK: - recommended_label Tests

    @Test("Preset can be created with recommended_label")
    func testPresetWithRecommendedLabel() async {
        let preset = LabelBuilderPreset(
            name: "Test Preset",
            description: "A test preset",
            config: .default,
            recommended_label: "Avery 5160"
        )

        #expect(preset.recommended_label == "Avery 5160")
    }

    @Test("Preset can be created without recommended_label")
    func testPresetWithoutRecommendedLabel() async {
        let preset = LabelBuilderPreset(
            name: "Test Preset",
            description: "A test preset",
            config: .default
        )

        #expect(preset.recommended_label == nil)
    }

    @Test("Preset encodes and decodes recommended_label correctly")
    func testPresetCodableWithRecommendedLabel() async throws {
        let original = LabelBuilderPreset(
            name: "Test Preset",
            description: "A test preset",
            config: .default,
            recommended_label: "Avery 5263"
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LabelBuilderPreset.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.recommended_label == "Avery 5263")
    }

    @Test("Preset encodes and decodes nil recommended_label correctly")
    func testPresetCodableWithNilRecommendedLabel() async throws {
        let original = LabelBuilderPreset(
            name: "Test Preset",
            description: "A test preset",
            config: .default,
            recommended_label: nil
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LabelBuilderPreset.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.recommended_label == nil)
    }

    @Test("exportJSON includes recommended_label")
    func testExportJSONIncludesRecommendedLabel() async throws {
        let preset = LabelBuilderPreset(
            name: "Export Test",
            description: "Testing export",
            config: .default,
            recommended_label: "Avery 8160"
        )

        guard let jsonData = preset.exportJSON() else {
            Issue.record("exportJSON returned nil")
            return
        }

        // Parse JSON to verify field is present
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        let recommendedLabel = json?["recommended_label"] as? String
        #expect(recommendedLabel == "Avery 8160")
    }

    @Test("importJSON restores recommended_label")
    func testImportJSONRestoresRecommendedLabel() async throws {
        let original = LabelBuilderPreset(
            name: "Import Test",
            description: "Testing import",
            config: .default,
            recommended_label: "Avery 5167"
        )

        guard let jsonData = original.exportJSON() else {
            Issue.record("exportJSON returned nil")
            return
        }

        guard let imported = LabelBuilderPreset.importJSON(jsonData) else {
            Issue.record("importJSON returned nil")
            return
        }

        #expect(imported.name == "Import Test")
        #expect(imported.recommended_label == "Avery 5167")
    }
}
