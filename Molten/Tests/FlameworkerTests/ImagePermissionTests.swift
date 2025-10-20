//
//  ImagePermissionTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/17/25.
//

import Testing
@testable import Flameworker

/// Tests for manufacturer image usage permission tracking
/// Verifies that the system correctly respects image usage permissions
struct ImagePermissionTests {

    // MARK: - Permission Tracking Tests

    @Test("GlassManufacturers tracks permission for CiM as false")
    func testCiMHasNoPermission() async throws {
        // CiM should have no permission to use product-specific images
        let hasPermission = GlassManufacturers.hasProductImagePermission(for: "CiM")
        #expect(hasPermission == false)
    }

    @Test("GlassManufacturers tracks permission for other manufacturers as true")
    func testOtherManufacturersHavePermission() async throws {
        // Test that other manufacturers have permission
        let manufacturers = ["EF", "DH", "BB", "GA", "RE", "TAG", "VF", "NS", "BE", "KUG", "MOR"]

        for manufacturer in manufacturers {
            let hasPermission = GlassManufacturers.hasProductImagePermission(for: manufacturer)
            #expect(hasPermission == true, "Expected \(manufacturer) to have permission")
        }
    }

    @Test("Permission check is case-insensitive for manufacturer codes")
    func testPermissionCheckCaseInsensitive() async throws {
        // Test case variations of CiM
        #expect(GlassManufacturers.hasProductImagePermission(for: "CiM") == false)
        #expect(GlassManufacturers.hasProductImagePermission(for: "cim") == false)
        #expect(GlassManufacturers.hasProductImagePermission(for: "CIM") == false)
        #expect(GlassManufacturers.hasProductImagePermission(for: "ciM") == false)

        // Test case variations of permitted manufacturer (EF)
        #expect(GlassManufacturers.hasProductImagePermission(for: "EF") == true)
        #expect(GlassManufacturers.hasProductImagePermission(for: "ef") == true)
        #expect(GlassManufacturers.hasProductImagePermission(for: "Ef") == true)
    }

    @Test("Permission check returns false for nil manufacturer")
    func testPermissionCheckNilManufacturer() async throws {
        let hasPermission = GlassManufacturers.hasProductImagePermission(for: nil)
        #expect(hasPermission == false)
    }

    @Test("Permission check returns false for empty string")
    func testPermissionCheckEmptyString() async throws {
        let hasPermission = GlassManufacturers.hasProductImagePermission(for: "")
        #expect(hasPermission == false)
    }

    @Test("Permission check returns false for unknown manufacturer")
    func testPermissionCheckUnknownManufacturer() async throws {
        // Unknown manufacturers should default to no permission (safe default)
        let hasPermission = GlassManufacturers.hasProductImagePermission(for: "UNKNOWN")
        #expect(hasPermission == false)
    }

    @Test("Permission check handles whitespace-only manufacturer")
    func testPermissionCheckWhitespaceManufacturer() async throws {
        let hasPermission = GlassManufacturers.hasProductImagePermission(for: "   ")
        #expect(hasPermission == false)
    }

    @Test("Permission check trims whitespace from manufacturer code")
    func testPermissionCheckTrimsWhitespace() async throws {
        // CiM with surrounding whitespace should still be recognized
        #expect(GlassManufacturers.hasProductImagePermission(for: " CiM ") == false)
        #expect(GlassManufacturers.hasProductImagePermission(for: "  EF  ") == true)
    }

    // MARK: - Default Image Name Tests

    @Test("Default image name is returned for all manufacturers")
    func testDefaultImageNameReturned() async throws {
        let manufacturers = ["EF", "DH", "BB", "CiM", "GA", "RE", "TAG", "VF", "NS", "BE", "KUG"]

        for manufacturer in manufacturers {
            let imageName = GlassManufacturers.defaultImageName(for: manufacturer)
            #expect(imageName != nil, "Expected default image name for \(manufacturer)")
        }
    }

    @Test("Default image name matches expected values")
    func testDefaultImageNameValues() async throws {
        #expect(GlassManufacturers.defaultImageName(for: "CiM") == "cim")
        #expect(GlassManufacturers.defaultImageName(for: "EF") == "effetre")
        #expect(GlassManufacturers.defaultImageName(for: "DH") == "dh")
        #expect(GlassManufacturers.defaultImageName(for: "BB") == "bb")
        #expect(GlassManufacturers.defaultImageName(for: "GA") == "ga")
    }

    @Test("Default image name is case-insensitive")
    func testDefaultImageNameCaseInsensitive() async throws {
        #expect(GlassManufacturers.defaultImageName(for: "CiM") == "cim")
        #expect(GlassManufacturers.defaultImageName(for: "cim") == "cim")
        #expect(GlassManufacturers.defaultImageName(for: "CIM") == "cim")
    }

    @Test("Default image name returns nil for unknown manufacturer")
    func testDefaultImageNameUnknownManufacturer() async throws {
        let imageName = GlassManufacturers.defaultImageName(for: "UNKNOWN")
        #expect(imageName == nil)
    }

    @Test("Default image name returns nil for nil manufacturer")
    func testDefaultImageNameNilManufacturer() async throws {
        let imageName = GlassManufacturers.defaultImageName(for: nil)
        #expect(imageName == nil)
    }

    // MARK: - Integration Tests

    @Test("All manufacturers with default images have permission settings")
    func testAllManufacturersHavePermissionSettings() async throws {
        // Every manufacturer with a default image should have an explicit permission setting
        let manufacturersWithImages = ["EF", "DH", "BB", "CiM", "GA", "RE", "TAG", "VF", "NS", "BE", "KUG"]

        for manufacturer in manufacturersWithImages {
            // Should have a default image
            let imageName = GlassManufacturers.defaultImageName(for: manufacturer)
            #expect(imageName != nil, "Expected default image for \(manufacturer)")

            // Should have an explicit permission setting (not using default)
            // We can verify this by checking that the manufacturer is in the permissions dictionary
            let hasExplicitPermission = GlassManufacturers.productImagePermissions[manufacturer] != nil
            #expect(hasExplicitPermission, "Expected explicit permission setting for \(manufacturer)")
        }
    }

    @Test("Permission and default image are consistent")
    func testPermissionAndDefaultImageConsistent() async throws {
        // If a manufacturer has no permission, it should have a default image
        let manufacturers = ["EF", "DH", "BB", "CiM", "GA", "RE", "TAG", "VF", "NS", "BE", "KUG"]

        for manufacturer in manufacturers {
            let hasPermission = GlassManufacturers.hasProductImagePermission(for: manufacturer)
            let hasDefaultImage = GlassManufacturers.defaultImageName(for: manufacturer) != nil

            if !hasPermission {
                // If no permission, must have default image
                #expect(hasDefaultImage, "Manufacturer \(manufacturer) has no permission but no default image")
            }
        }
    }

    @Test("CiM has both no permission and a default image")
    func testCiMHasNoPermissionButHasDefaultImage() async throws {
        // CiM is our test case - no permission but has default image
        let hasPermission = GlassManufacturers.hasProductImagePermission(for: "CiM")
        let hasDefaultImage = GlassManufacturers.defaultImageName(for: "CiM") != nil

        #expect(hasPermission == false, "CiM should not have permission")
        #expect(hasDefaultImage == true, "CiM should have a default image")
        #expect(GlassManufacturers.defaultImageName(for: "CiM") == "cim", "CiM default image should be 'cim'")
    }

    // MARK: - Edge Cases

    @Test("Permission check handles special characters gracefully")
    func testPermissionCheckSpecialCharacters() async throws {
        // These should all return false (no permission) without crashing
        #expect(GlassManufacturers.hasProductImagePermission(for: "C/M") == false)
        #expect(GlassManufacturers.hasProductImagePermission(for: "C\\M") == false)
        #expect(GlassManufacturers.hasProductImagePermission(for: "C-M") == false)
        #expect(GlassManufacturers.hasProductImagePermission(for: "C.M") == false)
    }

    @Test("Permission check handles very long manufacturer codes")
    func testPermissionCheckLongCodes() async throws {
        let longCode = String(repeating: "A", count: 1000)
        let hasPermission = GlassManufacturers.hasProductImagePermission(for: longCode)
        #expect(hasPermission == false) // Should default to no permission
    }

    @Test("Default image name handles special characters")
    func testDefaultImageNameSpecialCharacters() async throws {
        // These should all return nil without crashing
        #expect(GlassManufacturers.defaultImageName(for: "C/M") == nil)
        #expect(GlassManufacturers.defaultImageName(for: "C\\M") == nil)
        #expect(GlassManufacturers.defaultImageName(for: "C-M") == nil)
    }
}
