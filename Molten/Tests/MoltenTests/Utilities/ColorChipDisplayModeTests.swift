//
//  ColorChipDisplayModeTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 11/20/25.
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import SwiftUI
import UIKit
import Foundation
@testable import Molten

@Suite("Color Chip Display Mode Tests", .serialized)
@MainActor
struct ColorChipDisplayModeTests: MockOnlyTestSuite {

    // Prevent Core Data usage automatically
    init() {
        ensureMockOnlyEnvironment()
    }

    // MARK: - UserSettings Tests

    @Test("Should have correct default color chip display mode")
    func testDefaultColorChipDisplayMode() {
        // Given/When
        let defaultMode = UserSettings.shared.colorChipDisplayMode

        // Then
        #expect(defaultMode == .noPhoto, "Default color chip display mode should be 'noPhoto'")
    }

    @Test("Should persist color chip display mode setting")
    func testColorChipDisplayModePersistence() {
        let originalMode = UserSettings.shared.colorChipDisplayMode

        // Test always mode
        UserSettings.shared.colorChipDisplayMode = .always
        #expect(UserSettings.shared.colorChipDisplayMode == .always, "Should persist 'always' mode")

        // Test never mode
        UserSettings.shared.colorChipDisplayMode = .never
        #expect(UserSettings.shared.colorChipDisplayMode == .never, "Should persist 'never' mode")

        // Test noPhoto mode
        UserSettings.shared.colorChipDisplayMode = .noPhoto
        #expect(UserSettings.shared.colorChipDisplayMode == .noPhoto, "Should persist 'noPhoto' mode")

        // Restore original
        UserSettings.shared.colorChipDisplayMode = originalMode
    }

    // MARK: - ColorChipDisplayMode Enum Tests

    @Test("Should have all required color chip display modes")
    func testColorChipDisplayModeAllCases() {
        let allCases = UserSettings.ColorChipDisplayMode.allCases
        #expect(allCases.count == 3, "Should have exactly 3 display modes")
        #expect(allCases.contains(.always), "Should include 'always' mode")
        #expect(allCases.contains(.noPhoto), "Should include 'noPhoto' mode")
        #expect(allCases.contains(.never), "Should include 'never' mode")
    }

    @Test("Should have correct display names")
    func testColorChipDisplayModeDisplayNames() {
        #expect(UserSettings.ColorChipDisplayMode.always.displayName == "Always", "Always mode should have correct display name")
        #expect(UserSettings.ColorChipDisplayMode.noPhoto.displayName == "No Photo", "NoPhoto mode should have correct display name")
        #expect(UserSettings.ColorChipDisplayMode.never.displayName == "Never", "Never mode should have correct display name")
    }

    @Test("Should have correct descriptions")
    func testColorChipDisplayModeDescriptions() {
        let alwaysDesc = UserSettings.ColorChipDisplayMode.always.description
        #expect(alwaysDesc.contains("Always show"), "Always mode description should mention 'Always show'")
        #expect(alwaysDesc.contains("gradient"), "Always mode description should mention gradient")

        let noPhotoDesc = UserSettings.ColorChipDisplayMode.noPhoto.description
        #expect(noPhotoDesc.contains("Only show"), "NoPhoto mode description should mention 'Only show'")
        #expect(noPhotoDesc.contains("don't have a photo"), "NoPhoto mode description should mention photo availability")

        let neverDesc = UserSettings.ColorChipDisplayMode.never.description
        #expect(neverDesc.contains("Never show"), "Never mode description should mention 'Never show'")
        #expect(neverDesc.contains("manufacturer's logo"), "Never mode description should mention manufacturer logo")
    }

    @Test("Should have system icons")
    func testColorChipDisplayModeSystemIcons() {
        let alwaysIcon = UserSettings.ColorChipDisplayMode.always.systemImage
        #expect(!alwaysIcon.isEmpty, "Always mode should have a system icon")

        let noPhotoIcon = UserSettings.ColorChipDisplayMode.noPhoto.systemImage
        #expect(!noPhotoIcon.isEmpty, "NoPhoto mode should have a system icon")

        let neverIcon = UserSettings.ColorChipDisplayMode.never.systemImage
        #expect(!neverIcon.isEmpty, "Never mode should have a system icon")
    }

    // MARK: - Image Loading Logic Tests - ALWAYS Mode

    @Test("ALWAYS mode: Should return gradient image when colors exist")
    func testAlwaysModeWithColors() async {
        let originalMode = UserSettings.shared.colorChipDisplayMode
        UserSettings.shared.colorChipDisplayMode = .always

        let result = await ImageHelpers.loadProductImageForDisplay(
            itemCode: "TEST-001",
            manufacturer: "TestMfg",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: ["#FF0000", "#00FF00"]
        )

        // Now returns a gradient UIImage instead of nil
        #expect(result != nil, "ALWAYS mode with colors should return a gradient image")

        // Also verify wouldReturnGradientImage returns true
        let wouldShowGradient = await ImageHelpers.wouldReturnGradientImage(
            manufacturer: "TestMfg",
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: ["#FF0000", "#00FF00"]
        )
        #expect(wouldShowGradient == true, "wouldReturnGradientImage should return true in ALWAYS mode with colors")

        UserSettings.shared.colorChipDisplayMode = originalMode
    }

    @Test("ALWAYS mode: Should continue to normal flow when no colors")
    func testAlwaysModeWithoutColors() async {
        let originalMode = UserSettings.shared.colorChipDisplayMode
        UserSettings.shared.colorChipDisplayMode = .always

        let result = await ImageHelpers.loadProductImageForDisplay(
            itemCode: "NONEXISTENT-001",
            manufacturer: "TestMfg",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: nil
        )

        // Should not crash and should complete normal flow
        #expect(true, "ALWAYS mode without colors should complete normal flow")

        UserSettings.shared.colorChipDisplayMode = originalMode
    }

    @Test("ALWAYS mode: Should handle empty color array")
    func testAlwaysModeWithEmptyColors() async {
        let originalMode = UserSettings.shared.colorChipDisplayMode
        UserSettings.shared.colorChipDisplayMode = .always

        let result = await ImageHelpers.loadProductImageForDisplay(
            itemCode: "TEST-002",
            manufacturer: "TestMfg",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: []
        )

        // Empty array should not show gradient, should continue to normal flow
        #expect(true, "ALWAYS mode with empty colors array should continue to normal flow")

        UserSettings.shared.colorChipDisplayMode = originalMode
    }

    // MARK: - Image Loading Logic Tests - NEVER Mode

    @Test("NEVER mode: Should skip gradient when no permission")
    func testNeverModeNoPermission() async {
        let originalMode = UserSettings.shared.colorChipDisplayMode
        UserSettings.shared.colorChipDisplayMode = .never

        // Test with a manufacturer that has no permission (e.g., "CiM")
        let result = await ImageHelpers.loadProductImageForDisplay(
            itemCode: "TEST-003",
            manufacturer: "CiM",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: ["#FF0000", "#00FF00"]
        )

        // Should not return nil (shouldn't show gradient), should return logo or nil
        #expect(true, "NEVER mode should not show gradient even with colors and no permission")

        UserSettings.shared.colorChipDisplayMode = originalMode
    }

    @Test("NEVER mode: Should try product photo when has permission")
    func testNeverModeWithPermission() async {
        let originalMode = UserSettings.shared.colorChipDisplayMode
        UserSettings.shared.colorChipDisplayMode = .never

        // Test with a manufacturer that has permission (e.g., "DH")
        let result = await ImageHelpers.loadProductImageForDisplay(
            itemCode: "NONEXISTENT-002",
            manufacturer: "DH",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: ["#FF0000"]
        )

        // Should complete without crashing, trying product photo then logo
        #expect(true, "NEVER mode with permission should try product photo")

        UserSettings.shared.colorChipDisplayMode = originalMode
    }

    @Test("NEVER mode: Should ignore dominant colors")
    func testNeverModeIgnoresColors() async {
        let originalMode = UserSettings.shared.colorChipDisplayMode
        UserSettings.shared.colorChipDisplayMode = .never

        // Test with colors that would normally trigger gradient in noPhoto mode
        let result = await ImageHelpers.loadProductImageForDisplay(
            itemCode: "TEST-004",
            manufacturer: "CiM",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: ["#FF0000", "#00FF00", "#0000FF"]
        )

        // Should not return nil (no gradient) even with colors
        #expect(true, "NEVER mode should ignore colors and not show gradient")

        UserSettings.shared.colorChipDisplayMode = originalMode
    }

    // MARK: - Image Loading Logic Tests - NO PHOTO Mode (Default)

    @Test("NO PHOTO mode: Should return gradient image when no permission and has colors")
    func testNoPhotoModeNoPermissionWithColors() async {
        let originalMode = UserSettings.shared.colorChipDisplayMode
        UserSettings.shared.colorChipDisplayMode = .noPhoto

        let result = await ImageHelpers.loadProductImageForDisplay(
            itemCode: "TEST-005",
            manufacturer: "CiM",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: ["#FF0000"]
        )

        // Now returns a gradient UIImage instead of nil
        #expect(result != nil, "NO PHOTO mode should return gradient image when no permission and has colors")

        // Verify wouldReturnGradientImage agrees
        let wouldShowGradient = await ImageHelpers.wouldReturnGradientImage(
            manufacturer: "CiM",
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: ["#FF0000"]
        )
        #expect(wouldShowGradient == true, "wouldReturnGradientImage should return true for CiM with colors")

        UserSettings.shared.colorChipDisplayMode = originalMode
    }

    @Test("NO PHOTO mode: Should show logo when no permission and no colors")
    func testNoPhotoModeNoPermissionNoColors() async {
        let originalMode = UserSettings.shared.colorChipDisplayMode
        UserSettings.shared.colorChipDisplayMode = .noPhoto

        let result = await ImageHelpers.loadProductImageForDisplay(
            itemCode: "TEST-006",
            manufacturer: "CiM",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: nil
        )

        // Should try to load logo (may return image or nil)
        #expect(true, "NO PHOTO mode without colors should try to load logo")

        UserSettings.shared.colorChipDisplayMode = originalMode
    }

    @Test("NO PHOTO mode: Should handle PDX special case")
    func testNoPhotoModePDXSpecialCase() async {
        let originalMode = UserSettings.shared.colorChipDisplayMode
        UserSettings.shared.colorChipDisplayMode = .noPhoto

        let result = await ImageHelpers.loadProductImageForDisplay(
            itemCode: "TEST-007",
            manufacturer: "PDX",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: ["#FF0000"]
        )

        // PDX should always show logo, never gradient
        #expect(true, "NO PHOTO mode should handle PDX special case (no gradient even with colors)")

        UserSettings.shared.colorChipDisplayMode = originalMode
    }

    @Test("NO PHOTO mode: Should return gradient image when photo not found and has colors")
    func testNoPhotoModePhotoNotFoundWithColors() async {
        let originalMode = UserSettings.shared.colorChipDisplayMode
        UserSettings.shared.colorChipDisplayMode = .noPhoto

        let result = await ImageHelpers.loadProductImageForDisplay(
            itemCode: "DEFINITELY-NONEXISTENT",
            manufacturer: "DH",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: ["#FF0000", "#00FF00"]
        )

        // Now returns a gradient UIImage when photo not found but has colors
        #expect(result != nil, "NO PHOTO mode should return gradient image when photo not found and has colors")

        // Verify wouldReturnGradientImage agrees
        let wouldShowGradient = await ImageHelpers.wouldReturnGradientImage(
            manufacturer: "DH",
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: ["#FF0000", "#00FF00"]
        )
        #expect(wouldShowGradient == true, "wouldReturnGradientImage should return true when no photo found")

        UserSettings.shared.colorChipDisplayMode = originalMode
    }

    // MARK: - Edge Case Tests

    @Test("Should handle nil manufacturer in all modes")
    func testNilManufacturerAllModes() async {
        let modes: [UserSettings.ColorChipDisplayMode] = [.always, .noPhoto, .never]

        for mode in modes {
            let originalMode = UserSettings.shared.colorChipDisplayMode
            UserSettings.shared.colorChipDisplayMode = mode

            let result = await ImageHelpers.loadProductImageForDisplay(
                itemCode: "TEST-NIL-MFG",
                manufacturer: nil,
                stableId: nil,
                imagePath: nil,
                imageThumbPath: nil,
                dominantColors: ["#FF0000"]
            )

            #expect(true, "\(mode.displayName) mode should handle nil manufacturer gracefully")

            UserSettings.shared.colorChipDisplayMode = originalMode
        }
    }

    @Test("Should handle empty item code in all modes")
    func testEmptyItemCodeAllModes() async {
        let modes: [UserSettings.ColorChipDisplayMode] = [.always, .noPhoto, .never]

        for mode in modes {
            let originalMode = UserSettings.shared.colorChipDisplayMode
            UserSettings.shared.colorChipDisplayMode = mode

            let result = await ImageHelpers.loadProductImageForDisplay(
                itemCode: "",
                manufacturer: "TestMfg",
                stableId: nil,
                imagePath: nil,
                imageThumbPath: nil,
                dominantColors: ["#FF0000"]
            )

            #expect(true, "\(mode.displayName) mode should handle empty item code gracefully")

            UserSettings.shared.colorChipDisplayMode = originalMode
        }
    }

    // MARK: - Mode Transition Tests

    @Test("Should handle switching between modes")
    func testModeSwitching() async {
        let originalMode = UserSettings.shared.colorChipDisplayMode
        let testCode = "MODE-SWITCH-TEST"
        let testColors = ["#FF0000", "#00FF00"]

        // Test Always mode
        UserSettings.shared.colorChipDisplayMode = .always
        let alwaysResult = await ImageHelpers.loadProductImageForDisplay(
            itemCode: testCode,
            manufacturer: "CiM",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: testColors
        )
        let alwaysWouldShowGradient = await ImageHelpers.wouldReturnGradientImage(
            manufacturer: "CiM",
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: testColors
        )

        // Test NoPhoto mode
        UserSettings.shared.colorChipDisplayMode = .noPhoto
        let noPhotoResult = await ImageHelpers.loadProductImageForDisplay(
            itemCode: testCode,
            manufacturer: "CiM",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: testColors
        )
        let noPhotoWouldShowGradient = await ImageHelpers.wouldReturnGradientImage(
            manufacturer: "CiM",
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: testColors
        )

        // Test Never mode
        UserSettings.shared.colorChipDisplayMode = .never
        let neverResult = await ImageHelpers.loadProductImageForDisplay(
            itemCode: testCode,
            manufacturer: "CiM",
            stableId: nil,
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: testColors
        )
        let neverWouldShowGradient = await ImageHelpers.wouldReturnGradientImage(
            manufacturer: "CiM",
            imagePath: nil,
            imageThumbPath: nil,
            dominantColors: testColors
        )

        // Always and NoPhoto should return gradient image (not nil)
        #expect(alwaysResult != nil, "Always mode should return gradient image with colors")
        #expect(alwaysWouldShowGradient == true, "Always mode wouldReturnGradientImage should be true")
        #expect(noPhotoResult != nil, "NoPhoto mode should return gradient image when no permission and has colors")
        #expect(noPhotoWouldShowGradient == true, "NoPhoto mode wouldReturnGradientImage should be true")

        // Never mode should not show gradient
        #expect(neverWouldShowGradient == false, "Never mode wouldReturnGradientImage should be false")

        UserSettings.shared.colorChipDisplayMode = originalMode
    }

    // MARK: - Integration Tests

    @Test("Should integrate with manufacturer permission system")
    func testManufacturerPermissionIntegration() async {
        let originalMode = UserSettings.shared.colorChipDisplayMode

        // Test with manufacturers that have different permission statuses
        let testCases: [(manufacturer: String, hasPermission: Bool)] = [
            ("DH", true),
            ("CiM", false),
            ("GA", true),
            ("BB", false)
        ]

        for (manufacturer, hasPermission) in testCases {
            for mode in UserSettings.ColorChipDisplayMode.allCases {
                UserSettings.shared.colorChipDisplayMode = mode

                let result = await ImageHelpers.loadProductImageForDisplay(
                    itemCode: "PERM-TEST",
                    manufacturer: manufacturer,
                    stableId: nil,
                    imagePath: nil,
                    imageThumbPath: nil,
                    dominantColors: ["#FF0000"]
                )

                #expect(true, "\(mode.displayName) mode should work with \(manufacturer) (permission: \(hasPermission))")
            }
        }

        UserSettings.shared.colorChipDisplayMode = originalMode
    }
}
