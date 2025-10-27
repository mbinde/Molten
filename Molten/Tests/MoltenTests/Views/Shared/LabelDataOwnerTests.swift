//
//  LabelDataOwnerTests.swift
//  MoltenTests
//
//  Tests for LabelData owner field support
//

import Testing
import Foundation
@testable import Molten

@Suite("LabelData - Owner Field")
@MainActor
struct LabelDataOwnerTests {

    @Test("LabelData can be created with owner")
    func labelDataCanBeCreatedWithOwner() async throws {
        let labelData = LabelData(
            stableId: "test-123",
            manufacturer: "be",
            sku: "001",
            colorName: "Clear",
            coe: "96",
            location: nil,
            owner: "Test Studio"
        )

        #expect(labelData.owner == "Test Studio")
    }

    @Test("LabelData owner can be nil")
    func labelDataOwnerCanBeNil() async throws {
        let labelData = LabelData(
            stableId: "test-123",
            manufacturer: "be",
            sku: "001",
            colorName: "Clear",
            coe: "96",
            location: nil,
            owner: nil
        )

        #expect(labelData.owner == nil)
    }

    @Test("LabelData owner field is independent of location")
    func ownerFieldIsIndependentOfLocation() async throws {
        let withBoth = LabelData(
            stableId: "test-123",
            manufacturer: "be",
            sku: "001",
            colorName: "Clear",
            coe: "96",
            location: "Shelf A",
            owner: "Studio Name"
        )

        #expect(withBoth.location == "Shelf A")
        #expect(withBoth.owner == "Studio Name")

        let withLocationOnly = LabelData(
            stableId: "test-123",
            manufacturer: "be",
            sku: "001",
            colorName: "Clear",
            coe: "96",
            location: "Shelf A",
            owner: nil
        )

        #expect(withLocationOnly.location == "Shelf A")
        #expect(withLocationOnly.owner == nil)

        let withOwnerOnly = LabelData(
            stableId: "test-123",
            manufacturer: "be",
            sku: "001",
            colorName: "Clear",
            coe: "96",
            location: nil,
            owner: "Studio Name"
        )

        #expect(withOwnerOnly.location == nil)
        #expect(withOwnerOnly.owner == "Studio Name")
    }

    @Test("LabelData with empty owner string")
    func labelDataWithEmptyOwnerString() async throws {
        let labelData = LabelData(
            stableId: "test-123",
            manufacturer: "be",
            sku: "001",
            colorName: "Clear",
            coe: "96",
            location: nil,
            owner: ""
        )

        #expect(labelData.owner == "")
    }

    @Test("LabelData owner supports long names")
    func ownerSupportsLongNames() async throws {
        let longOwner = "The Glass Art Studio and Educational Workshop Center"

        let labelData = LabelData(
            stableId: "test-123",
            manufacturer: "be",
            sku: "001",
            colorName: "Clear",
            coe: "96",
            location: nil,
            owner: longOwner
        )

        #expect(labelData.owner == longOwner)
    }

    @Test("LabelData owner supports special characters")
    func ownerSupportsSpecialCharacters() async throws {
        let ownerWithSpecialChars = "Studio & Co. — Artist's Glass"

        let labelData = LabelData(
            stableId: "test-123",
            manufacturer: "be",
            sku: "001",
            colorName: "Clear",
            coe: "96",
            location: nil,
            owner: ownerWithSpecialChars
        )

        #expect(labelData.owner == ownerWithSpecialChars)
    }

    @Test("LabelData owner supports Unicode")
    func ownerSupportsUnicode() async throws {
        let unicodeOwner = "玻璃工作室"

        let labelData = LabelData(
            stableId: "test-123",
            manufacturer: "be",
            sku: "001",
            colorName: "Clear",
            coe: "96",
            location: nil,
            owner: unicodeOwner
        )

        #expect(labelData.owner == unicodeOwner)
    }

    @Test("Multiple LabelData instances with different owners")
    func multipleLabelDataWithDifferentOwners() async throws {
        let labelData1 = LabelData(
            stableId: "test-1",
            manufacturer: "be",
            sku: "001",
            colorName: "Clear",
            coe: "96",
            location: nil,
            owner: "Studio A"
        )

        let labelData2 = LabelData(
            stableId: "test-2",
            manufacturer: "cim",
            sku: "002",
            colorName: "Blue",
            coe: "104",
            location: nil,
            owner: "Studio B"
        )

        let labelData3 = LabelData(
            stableId: "test-3",
            manufacturer: "ef",
            sku: "003",
            colorName: "Red",
            coe: "90",
            location: nil,
            owner: nil
        )

        #expect(labelData1.owner == "Studio A")
        #expect(labelData2.owner == "Studio B")
        #expect(labelData3.owner == nil)
    }
}
