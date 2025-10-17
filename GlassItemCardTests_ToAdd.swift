//
//  GlassItemCardTests.swift
//  FlameworkerTests
//
//  Tests for GlassItemCard shared component
//
// Target: FlameworkerTests
//
// INSTRUCTIONS: Add this file to the FlameworkerTests target in Xcode
// 1. Open Xcode
// 2. Right-click on the FlameworkerTests folder in the project navigator
// 3. Select "Add Files to Flameworker..."
// 4. Select this file
// 5. IMPORTANT: In the "Add to targets" section, check ONLY "FlameworkerTests" (NOT "Flameworker")
// 6. Click "Add"
// 7. Delete this file after adding it to the project

import Testing
import SwiftUI
@testable import Flameworker

@Suite("GlassItemCard Tests")
struct GlassItemCardTests {

    // MARK: - Test Data

    let sampleGlassItem = GlassItemModel(
        natural_key: "bullseye-0001-0",
        name: "Bullseye Red Opal",
        sku: "0001",
        manufacturer: "bullseye",
        mfr_notes: "A beautiful deep red opal glass.",
        coe: 90,
        url: "https://www.bullseyeglass.com/color/0001-red-opal",
        mfr_status: "available"
    )

    let sampleGlassItemNoURL = GlassItemModel(
        natural_key: "cim-874-0",
        name: "Pale Gray",
        sku: "874",
        manufacturer: "cim",
        coe: 104,
        mfr_status: "available"
    )

    // MARK: - Initialization Tests

    @Test("GlassItemCard creates with large variant")
    func testLargeVariantCreation() {
        let card = GlassItemCard(item: sampleGlassItem, variant: .large)
        #expect(card.item.natural_key == "bullseye-0001-0")
        #expect(card.variant == .large)
    }

    @Test("GlassItemCard creates with compact variant")
    func testCompactVariantCreation() {
        let card = GlassItemCard(item: sampleGlassItem, variant: .compact)
        #expect(card.item.natural_key == "bullseye-0001-0")
        #expect(card.variant == .compact)
    }

    // MARK: - Variant Configuration Tests

    @Test("Large variant has correct image size")
    func testLargeVariantImageSize() {
        let variant = GlassItemCard.Variant.large
        #expect(variant.imageSize == 120)
    }

    @Test("Compact variant has correct image size")
    func testCompactVariantImageSize() {
        let variant = GlassItemCard.Variant.compact
        #expect(variant.imageSize == 60)
    }

    @Test("Large variant has correct spacing")
    func testLargeVariantSpacing() {
        let variant = GlassItemCard.Variant.large
        #expect(variant.spacing == DesignSystem.Spacing.xl)
        #expect(variant.contentSpacing == DesignSystem.Spacing.md)
    }

    @Test("Compact variant has correct spacing")
    func testCompactVariantSpacing() {
        let variant = GlassItemCard.Variant.compact
        #expect(variant.spacing == DesignSystem.Spacing.lg)
        #expect(variant.contentSpacing == DesignSystem.Spacing.xs)
    }

    @Test("Large variant has correct typography")
    func testLargeVariantTypography() {
        let variant = GlassItemCard.Variant.large
        #expect(variant.titleFont == DesignSystem.Typography.sectionHeader)
        #expect(variant.titleWeight == DesignSystem.FontWeight.bold)
    }

    @Test("Compact variant has correct typography")
    func testCompactVariantTypography() {
        let variant = GlassItemCard.Variant.compact
        #expect(variant.titleFont == DesignSystem.Typography.rowTitle)
        #expect(variant.titleWeight == DesignSystem.FontWeight.semibold)
    }

    @Test("Large variant has clear background")
    func testLargeVariantBackground() {
        let variant = GlassItemCard.Variant.large
        #expect(variant.background == Color.clear)
        #expect(variant.cornerRadius == 0)
    }

    @Test("Compact variant has styled background")
    func testCompactVariantBackground() {
        let variant = GlassItemCard.Variant.compact
        #expect(variant.background == DesignSystem.Colors.backgroundInputLight)
        #expect(variant.cornerRadius == DesignSystem.CornerRadius.extraLarge)
    }

    @Test("Large variant has minimal padding")
    func testLargeVariantPadding() {
        let variant = GlassItemCard.Variant.large
        let padding = variant.padding
        #expect(padding.top == DesignSystem.Padding.rowVertical)
        #expect(padding.leading == 0)
        #expect(padding.bottom == DesignSystem.Padding.rowVertical)
        #expect(padding.trailing == 0)
    }

    @Test("Compact variant has standard padding")
    func testCompactVariantPadding() {
        let variant = GlassItemCard.Variant.compact
        let padding = variant.padding
        #expect(padding.top == DesignSystem.Padding.standard)
        #expect(padding.leading == DesignSystem.Padding.standard)
        #expect(padding.bottom == DesignSystem.Padding.standard)
        #expect(padding.trailing == DesignSystem.Padding.standard)
    }

    // MARK: - Component Data Tests

    @Test("GlassItemCard displays item name")
    func testDisplaysItemName() {
        let card = GlassItemCard(item: sampleGlassItem, variant: .large)
        #expect(card.item.name == "Bullseye Red Opal")
    }

    @Test("GlassItemCard displays item SKU")
    func testDisplaysItemSKU() {
        let card = GlassItemCard(item: sampleGlassItem, variant: .large)
        #expect(card.item.sku == "0001")
    }

    @Test("GlassItemCard displays item manufacturer")
    func testDisplaysItemManufacturer() {
        let card = GlassItemCard(item: sampleGlassItem, variant: .large)
        #expect(card.item.manufacturer == "bullseye")
    }

    @Test("GlassItemCard displays item COE")
    func testDisplaysItemCOE() {
        let card = GlassItemCard(item: sampleGlassItem, variant: .large)
        #expect(card.item.coe == 90)
    }

    @Test("GlassItemCard displays item status")
    func testDisplaysItemStatus() {
        let card = GlassItemCard(item: sampleGlassItem, variant: .large)
        #expect(card.item.mfr_status == "available")
    }

    @Test("GlassItemCard handles item with URL")
    func testHandlesItemWithURL() {
        let card = GlassItemCard(item: sampleGlassItem, variant: .large)
        #expect(card.item.url != nil)
        #expect(card.item.url == "https://www.bullseyeglass.com/color/0001-red-opal")
    }

    @Test("GlassItemCard handles item without URL")
    func testHandlesItemWithoutURL() {
        let card = GlassItemCard(item: sampleGlassItemNoURL, variant: .large)
        #expect(card.item.url == nil)
    }

    // MARK: - Variant Comparison Tests

    @Test("Large and compact variants are different")
    func testVariantsAreDifferent() {
        let large = GlassItemCard.Variant.large
        let compact = GlassItemCard.Variant.compact

        #expect(large.imageSize != compact.imageSize)
        #expect(large.spacing != compact.spacing)
        #expect(large.background != compact.background)
        #expect(large.cornerRadius != compact.cornerRadius)
    }

    // MARK: - Edge Case Tests

    @Test("GlassItemCard handles empty URL string")
    func testHandlesEmptyURLString() {
        let itemWithEmptyURL = GlassItemModel(
            natural_key: "test-001-0",
            name: "Test Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            url: "",
            mfr_status: "available"
        )
        let card = GlassItemCard(item: itemWithEmptyURL, variant: .large)
        #expect(card.item.url == "")
    }

    @Test("GlassItemCard handles invalid URL string")
    func testHandlesInvalidURLString() {
        let itemWithInvalidURL = GlassItemModel(
            natural_key: "test-002-0",
            name: "Test Item 2",
            sku: "002",
            manufacturer: "test",
            coe: 96,
            url: "not a valid url",
            mfr_status: "available"
        )
        let card = GlassItemCard(item: itemWithInvalidURL, variant: .large)
        #expect(card.item.url == "not a valid url")
    }

    @Test("GlassItemCard handles different manufacturer statuses")
    func testHandlesDifferentStatuses() {
        let statusesToTest = ["available", "discontinued", "limited", "new"]

        for status in statusesToTest {
            let item = GlassItemModel(
                natural_key: "test-\(status)-0",
                name: "Test Item",
                sku: "001",
                manufacturer: "test",
                coe: 96,
                mfr_status: status
            )
            let card = GlassItemCard(item: item, variant: .large)
            #expect(card.item.mfr_status == status)
        }
    }
}
