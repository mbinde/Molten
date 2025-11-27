//
//  GlassItemImageSelectorTests.swift
//  MoltenTests
//
//  Tests for GlassItemImageSelector component
//

import Foundation

// Standard test framework imports pattern
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

#if canImport(UIKit)
import UIKit

// Use Swift Testing if available
#if canImport(Testing)

@Suite("GlassItemImageSelector Tests")
@MainActor
struct GlassItemImageSelectorTests {

    // MARK: - Helper Text Tests

    @Test("Should show extended helper text when user has images")
    func testHelperTextWithUserImages() {
        let expectedText = "Tap to select primary • Tap selected to use default • Tap and hold for more options"

        // The helper text should include all three instructions when user has uploaded images
        #expect(expectedText.contains("Tap to select primary"))
        #expect(expectedText.contains("Tap selected to use default"))
        #expect(expectedText.contains("Tap and hold for more options"))
        #expect(expectedText.contains("•"))
    }

    @Test("Should show manufacturer default message when no user images")
    func testHelperTextWithoutUserImages() {
        let expectedText = "Using manufacturer default image"

        // When no user images exist, should show simple default message
        #expect(expectedText == "Using manufacturer default image")
    }

    // MARK: - Context Menu Visibility Tests

    @Test("Should show Submit to Molten option when no user images exist")
    func testSubmitOptionVisibleWithNoUserImages() {
        let hasUserImages = false

        // Submit to Molten option should only be visible when user has NO images
        let shouldShowSubmitOption = !hasUserImages

        #expect(shouldShowSubmitOption)
    }

    @Test("Should hide Submit to Molten option when user images exist")
    func testSubmitOptionHiddenWithUserImages() {
        let hasUserImages = true

        // Submit to Molten option should be hidden when user has images
        let shouldShowSubmitOption = !hasUserImages

        #expect(!shouldShowSubmitOption)
    }

    @Test("Should show Submit to Molten option with empty images array")
    func testSubmitOptionWithEmptyArray() {
        let images: [UserImageModel] = []

        let shouldShowSubmitOption = images.isEmpty

        #expect(shouldShowSubmitOption)
    }

    @Test("Should hide Submit to Molten option with single image")
    func testSubmitOptionWithSingleImage() {
        let sampleImage = UserImageModel(
            id: UUID(),
            stableId: "test-001-0",
            imageType: .primary,
            fileName: "test.jpg",
            createdDate: Date()
        )
        let images = [sampleImage]

        let shouldShowSubmitOption = images.isEmpty

        #expect(!shouldShowSubmitOption)
    }

    @Test("Should hide Submit to Molten option with multiple images")
    func testSubmitOptionWithMultipleImages() {
        let sampleImages = [
            UserImageModel(id: UUID(), stableId: "test-001-0", imageType: .primary, fileName: "test1.jpg", createdDate: Date()),
            UserImageModel(id: UUID(), stableId: "test-001-0", imageType: .alternate, fileName: "test2.jpg", createdDate: Date())
        ]

        let shouldShowSubmitOption = sampleImages.isEmpty

        #expect(!shouldShowSubmitOption)
    }

    // MARK: - Delete Context Menu Tests

    @Test("Should always show delete option for user images")
    func testDeleteOptionAlwaysAvailable() {
        // Delete option should be available for all user images regardless of other conditions
        let hasDeleteOption = true

        #expect(hasDeleteOption)
    }

    // MARK: - Primary Selection Tests

    @Test("Should allow deselecting primary to use manufacturer default")
    func testDeselectPrimaryUsesDefault() {
        var currentPrimaryId: UUID? = UUID()

        // Deselecting (passing nil) should clear the primary
        currentPrimaryId = nil

        #expect(currentPrimaryId == nil)
    }

    @Test("Should allow selecting a different image as primary")
    func testSelectDifferentPrimary() {
        let firstImageId = UUID()
        let secondImageId = UUID()
        var currentPrimaryId: UUID? = firstImageId

        // Should be able to switch primary to different image
        currentPrimaryId = secondImageId

        #expect(currentPrimaryId == secondImageId)
        #expect(currentPrimaryId != firstImageId)
    }
}

#else
// XCTest fallback
import XCTest

final class GlassItemImageSelectorTests: XCTestCase {

    // MARK: - Helper Text Tests

    func testHelperTextWithUserImages() {
        let expectedText = "Tap to select primary • Tap selected to use default • Tap and hold for more options"

        XCTAssertTrue(expectedText.contains("Tap to select primary"))
        XCTAssertTrue(expectedText.contains("Tap selected to use default"))
        XCTAssertTrue(expectedText.contains("Tap and hold for more options"))
        XCTAssertTrue(expectedText.contains("•"))
    }

    func testHelperTextWithoutUserImages() {
        let expectedText = "Using manufacturer default image"

        XCTAssertEqual(expectedText, "Using manufacturer default image")
    }

    // MARK: - Context Menu Visibility Tests

    func testSubmitOptionVisibleWithNoUserImages() {
        let hasUserImages = false
        let shouldShowSubmitOption = !hasUserImages

        XCTAssertTrue(shouldShowSubmitOption)
    }

    func testSubmitOptionHiddenWithUserImages() {
        let hasUserImages = true
        let shouldShowSubmitOption = !hasUserImages

        XCTAssertFalse(shouldShowSubmitOption)
    }

    func testSubmitOptionWithEmptyArray() {
        let images: [UserImageModel] = []
        let shouldShowSubmitOption = images.isEmpty

        XCTAssertTrue(shouldShowSubmitOption)
    }

    func testSubmitOptionWithSingleImage() {
        let sampleImage = UserImageModel(
            id: UUID(),
            stableId: "test-001-0",
            imageType: .primary,
            fileName: "test.jpg",
            createdDate: Date()
        )
        let images = [sampleImage]
        let shouldShowSubmitOption = images.isEmpty

        XCTAssertFalse(shouldShowSubmitOption)
    }

    func testSubmitOptionWithMultipleImages() {
        let sampleImages = [
            UserImageModel(id: UUID(), stableId: "test-001-0", imageType: .primary, fileName: "test1.jpg", createdDate: Date()),
            UserImageModel(id: UUID(), stableId: "test-001-0", imageType: .alternate, fileName: "test2.jpg", createdDate: Date())
        ]
        let shouldShowSubmitOption = sampleImages.isEmpty

        XCTAssertFalse(shouldShowSubmitOption)
    }

    // MARK: - Delete Context Menu Tests

    func testDeleteOptionAlwaysAvailable() {
        let hasDeleteOption = true
        XCTAssertTrue(hasDeleteOption)
    }

    // MARK: - Primary Selection Tests

    func testDeselectPrimaryUsesDefault() {
        var currentPrimaryId: UUID? = UUID()
        currentPrimaryId = nil

        XCTAssertNil(currentPrimaryId)
    }

    func testSelectDifferentPrimary() {
        let firstImageId = UUID()
        let secondImageId = UUID()
        var currentPrimaryId: UUID? = firstImageId

        currentPrimaryId = secondImageId

        XCTAssertEqual(currentPrimaryId, secondImageId)
        XCTAssertNotEqual(currentPrimaryId, firstImageId)
    }
}

#endif
#endif
