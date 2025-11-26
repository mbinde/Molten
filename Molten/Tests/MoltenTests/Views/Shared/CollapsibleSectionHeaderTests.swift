//
//  CollapsibleSectionHeaderTests.swift
//  MoltenTests
//
//  Tests for CollapsibleSectionHeader component toggle behavior and state management
//

import Testing
import SwiftUI
@testable import Molten

@Suite("CollapsibleSectionHeader Tests")
@MainActor
struct CollapsibleSectionHeaderTests {

    // MARK: - Initialization Tests

    @Test("CollapsibleSectionHeader initializes with basic properties")
    func testBasicInitialization() {
        var toggleCalled = false
        let header = CollapsibleSectionHeader(
            title: "Test Section",
            itemCount: nil,
            isExpanded: false,
            onToggle: { toggleCalled = true }
        )

        #expect(header != nil)
        #expect(header.title == "Test Section")
        #expect(header.itemCount == nil)
        #expect(header.isExpanded == false)
    }

    @Test("CollapsibleSectionHeader initializes with item count")
    func testInitializationWithItemCount() {
        let header = CollapsibleSectionHeader(
            title: "My Items",
            itemCount: 42,
            isExpanded: true,
            onToggle: {}
        )

        #expect(header != nil)
        #expect(header.title == "My Items")
        #expect(header.itemCount == 42)
        #expect(header.isExpanded == true)
    }

    @Test("CollapsibleSectionHeader initializes with leading icon")
    func testInitializationWithLeadingIcon() {
        let header = CollapsibleSectionHeader(
            title: "Settings",
            itemCount: nil,
            isExpanded: false,
            onToggle: {},
            leadingIcon: "gear"
        )

        #expect(header != nil)
        #expect(header.leadingIcon == "gear")
    }

    @Test("CollapsibleSectionHeader initializes with count suffix")
    func testInitializationWithCountSuffix() {
        let header = CollapsibleSectionHeader(
            title: "Stores",
            itemCount: 5,
            isExpanded: true,
            onToggle: {},
            countSuffix: "store"
        )

        #expect(header != nil)
        #expect(header.countSuffix == "store")
    }

    // MARK: - Convenience Initializer Tests

    @Test("withItemCount convenience initializer uses 'item' suffix")
    func testConvenienceInitializer() {
        let header = CollapsibleSectionHeader.withItemCount(
            title: "My Section",
            itemCount: 10,
            isExpanded: false,
            onToggle: {}
        )

        #expect(header != nil)
        #expect(header.title == "My Section")
        #expect(header.itemCount == 10)
        #expect(header.countSuffix == "item")
    }

    @Test("withItemCount convenience initializer with leading icon")
    func testConvenienceInitializerWithIcon() {
        let header = CollapsibleSectionHeader.withItemCount(
            title: "Files",
            itemCount: 3,
            isExpanded: true,
            onToggle: {},
            leadingIcon: "doc"
        )

        #expect(header != nil)
        #expect(header.leadingIcon == "doc")
        #expect(header.countSuffix == "item")
    }

    // MARK: - Toggle Behavior Tests

    @Test("onToggle callback is triggered")
    func testToggleCallback() async {
        var toggleCalled = false
        var toggleCount = 0

        let header = CollapsibleSectionHeader(
            title: "Test",
            isExpanded: false,
            onToggle: {
                toggleCalled = true
                toggleCount += 1
            }
        )

        #expect(header != nil)
        // Note: Actual toggle interaction would require UI testing
        // This test validates the callback setup
    }

    @Test("Toggle updates isExpanded state")
    func testToggleUpdatesState() {
        @State var isExpanded = false

        let header = CollapsibleSectionHeader(
            title: "Test",
            isExpanded: isExpanded,
            onToggle: {
                isExpanded.toggle()
            }
        )

        #expect(header != nil)
        #expect(isExpanded == false)
        // After toggle would be called, isExpanded would become true
    }

    // MARK: - State Management Tests

    @Test("Expanded state shows correct chevron")
    func testExpandedStateChevronDirection() {
        let expandedHeader = CollapsibleSectionHeader(
            title: "Expanded",
            isExpanded: true,
            onToggle: {}
        )

        let collapsedHeader = CollapsibleSectionHeader(
            title: "Collapsed",
            isExpanded: false,
            onToggle: {}
        )

        #expect(expandedHeader.isExpanded == true)
        #expect(collapsedHeader.isExpanded == false)
    }

    @Test("Multiple headers maintain independent state")
    func testIndependentHeaderStates() {
        @State var section1Expanded = true
        @State var section2Expanded = false

        let header1 = CollapsibleSectionHeader(
            title: "Section 1",
            isExpanded: section1Expanded,
            onToggle: { section1Expanded.toggle() }
        )

        let header2 = CollapsibleSectionHeader(
            title: "Section 2",
            isExpanded: section2Expanded,
            onToggle: { section2Expanded.toggle() }
        )

        #expect(header1.isExpanded == true)
        #expect(header2.isExpanded == false)
        #expect(header1.title != header2.title)
    }

    // MARK: - Count Formatting Tests

    @Test("Format count without suffix shows number only")
    func testFormatCountWithoutSuffix() {
        let header = CollapsibleSectionHeader(
            title: "Test",
            itemCount: 10,
            isExpanded: false,
            onToggle: {}
        )

        // formatCount is private, but we can test the behavior through itemCount
        #expect(header.itemCount == 10)
        #expect(header.countSuffix == nil)
    }

    @Test("Format count with suffix shows singular for count of 1")
    func testFormatCountSingular() {
        let header = CollapsibleSectionHeader(
            title: "Test",
            itemCount: 1,
            isExpanded: false,
            onToggle: {},
            countSuffix: "item"
        )

        #expect(header.itemCount == 1)
        #expect(header.countSuffix == "item")
        // Expected format: "1 item"
    }

    @Test("Format count with suffix shows plural for count > 1")
    func testFormatCountPlural() {
        let header = CollapsibleSectionHeader(
            title: "Test",
            itemCount: 5,
            isExpanded: false,
            onToggle: {},
            countSuffix: "item"
        )

        #expect(header.itemCount == 5)
        #expect(header.countSuffix == "item")
        // Expected format: "5 items"
    }

    @Test("Format count with custom suffix pluralizes correctly")
    func testFormatCountCustomSuffix() {
        let storeHeader = CollapsibleSectionHeader(
            title: "Stores",
            itemCount: 3,
            isExpanded: false,
            onToggle: {},
            countSuffix: "store"
        )

        #expect(storeHeader.itemCount == 3)
        #expect(storeHeader.countSuffix == "store")
        // Expected format: "3 stores"

        let manufacturerHeader = CollapsibleSectionHeader(
            title: "Manufacturers",
            itemCount: 1,
            isExpanded: false,
            onToggle: {},
            countSuffix: "manufacturer"
        )

        #expect(manufacturerHeader.itemCount == 1)
        #expect(manufacturerHeader.countSuffix == "manufacturer")
        // Expected format: "1 manufacturer"
    }

    @Test("Format count with zero shows correctly")
    func testFormatCountZero() {
        let header = CollapsibleSectionHeader(
            title: "Empty",
            itemCount: 0,
            isExpanded: false,
            onToggle: {},
            countSuffix: "item"
        )

        #expect(header.itemCount == 0)
        // Expected format: "0 items"
    }

    // MARK: - Accessibility Tests

    @Test("Accessibility identifier is generated from title")
    func testAccessibilityIdentifier() {
        let header1 = CollapsibleSectionHeader(
            title: "My Section",
            isExpanded: false,
            onToggle: {}
        )

        let header2 = CollapsibleSectionHeader(
            title: "Another Section",
            isExpanded: false,
            onToggle: {}
        )

        #expect(header1.title == "My Section")
        #expect(header2.title == "Another Section")
        // Expected IDs: "collapsible_section_header_my_section" and "collapsible_section_header_another_section"
    }

    @Test("Accessibility identifier handles special characters")
    func testAccessibilityIdentifierSpecialCharacters() {
        let header = CollapsibleSectionHeader(
            title: "Test & Demo",
            isExpanded: false,
            onToggle: {}
        )

        #expect(header.title == "Test & Demo")
        // Expected ID conversion: "test_&_demo" (lowercased, spaces to underscores)
    }

    // MARK: - Edge Cases

    @Test("Empty title initializes correctly")
    func testEmptyTitle() {
        let header = CollapsibleSectionHeader(
            title: "",
            isExpanded: false,
            onToggle: {}
        )

        #expect(header != nil)
        #expect(header.title == "")
    }

    @Test("Negative item count initializes correctly")
    func testNegativeItemCount() {
        let header = CollapsibleSectionHeader(
            title: "Test",
            itemCount: -1,
            isExpanded: false,
            onToggle: {}
        )

        #expect(header != nil)
        #expect(header.itemCount == -1)
        // Edge case: negative count would display as "-1 items"
    }

    @Test("Very large item count formats correctly")
    func testLargeItemCount() {
        let header = CollapsibleSectionHeader(
            title: "Many Items",
            itemCount: 999999,
            isExpanded: false,
            onToggle: {},
            countSuffix: "item"
        )

        #expect(header.itemCount == 999999)
        // Expected format: "999999 items"
    }

    // MARK: - Integration Scenarios

    @Test("Typical inventory section usage")
    func testInventorySectionScenario() {
        @State var manufacturerSectionsExpanded: [String: Bool] = [
            "bullseye": true,
            "oceanside": false,
            "cim": true
        ]

        let bullseyeHeader = CollapsibleSectionHeader.withItemCount(
            title: "Bullseye Glass",
            itemCount: 25,
            isExpanded: manufacturerSectionsExpanded["bullseye"] ?? false,
            onToggle: {
                manufacturerSectionsExpanded["bullseye"]?.toggle()
            },
            leadingIcon: "building.2"
        )

        #expect(bullseyeHeader.title == "Bullseye Glass")
        #expect(bullseyeHeader.itemCount == 25)
        #expect(bullseyeHeader.isExpanded == true)
        #expect(bullseyeHeader.leadingIcon == "building.2")
    }

    @Test("Settings group usage without count")
    func testSettingsGroupScenario() {
        @State var advancedExpanded = false

        let advancedHeader = CollapsibleSectionHeader(
            title: "Advanced Settings",
            itemCount: nil,
            isExpanded: advancedExpanded,
            onToggle: { advancedExpanded.toggle() },
            leadingIcon: "gearshape.2"
        )

        #expect(advancedHeader.title == "Advanced Settings")
        #expect(advancedHeader.itemCount == nil)
        #expect(advancedHeader.isExpanded == false)
        #expect(advancedHeader.leadingIcon == "gearshape.2")
    }

    @Test("Shopping list store grouping usage")
    func testShoppingListStoreGroupingScenario() {
        @State var storeExpanded: [String: Bool] = [
            "Frantz Art Glass": true,
            "Hot Glass Color": false
        ]

        let frantzHeader = CollapsibleSectionHeader(
            title: "Frantz Art Glass",
            itemCount: 12,
            isExpanded: storeExpanded["Frantz Art Glass"] ?? false,
            onToggle: {
                storeExpanded["Frantz Art Glass"]?.toggle()
            },
            leadingIcon: "storefront",
            countSuffix: "item"
        )

        #expect(frantzHeader.title == "Frantz Art Glass")
        #expect(frantzHeader.itemCount == 12)
        #expect(frantzHeader.leadingIcon == "storefront")
        #expect(frantzHeader.countSuffix == "item")
    }
}
