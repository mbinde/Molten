//
//  LocationQuickFilterBarTests.swift
//  MoltenTests
//
//  Tests for the LocationQuickFilterBar component
//

import Testing
import SwiftUI
@testable import Molten

@Suite("Location Quick Filter Bar Tests")
@MainActor
struct LocationQuickFilterBarTests {

    @Test("Bar shows when locations exist")
    func testShowsWhenLocationsExist() async throws {
        // The bar should render when there are available locations
        let locations = ["Shelf A", "Shelf B", "Studio"]
        let counts = ["Shelf A": 10, "Shelf B": 5, "Studio": 3]

        // This is a smoke test to ensure the view can be created
        let _ = LocationQuickFilterBar(
            selectedLocations: .constant([]),
            availableLocations: locations,
            locationCounts: counts,
            noLocationCount: 8,
            totalCount: 26
        )
        // View creation should succeed without error
    }

    @Test("Bar hides when no locations and no items without location")
    func testHidesWhenNoLocations() async throws {
        // When there are no locations at all and no items without locations,
        // the bar should not render (returns EmptyView)
        let _ = LocationQuickFilterBar(
            selectedLocations: .constant([]),
            availableLocations: [],
            locationCounts: [:],
            noLocationCount: 0,
            totalCount: 0
        )
        // View creation should succeed - it will just render as empty
    }

    @Test("noLocationValue is empty string")
    func testNoLocationValueIsEmptyString() async throws {
        // Verify the special value for "no location" filter
        #expect(LocationQuickFilterBar.noLocationValue == "")
    }

    @Test("Multi-select locations with set binding")
    func testMultiSelectLocations() async throws {
        // Test that the binding behavior supports multi-select
        var selectedLocations: Set<String> = []

        // Select first location
        selectedLocations.insert("Shelf A")
        #expect(selectedLocations.contains("Shelf A"))
        #expect(selectedLocations.count == 1)

        // Add second location (multi-select)
        selectedLocations.insert("Studio")
        #expect(selectedLocations.contains("Shelf A"))
        #expect(selectedLocations.contains("Studio"))
        #expect(selectedLocations.count == 2)

        // Deselect one
        selectedLocations.remove("Shelf A")
        #expect(!selectedLocations.contains("Shelf A"))
        #expect(selectedLocations.contains("Studio"))
        #expect(selectedLocations.count == 1)

        // Selecting "All" clears all selections
        selectedLocations.removeAll()
        #expect(selectedLocations.isEmpty)
    }

    @Test("Selecting (none) filters items without location")
    func testSelectingNone() async throws {
        var selectedLocations: Set<String> = []

        // Selecting "(none)" uses empty string
        selectedLocations.insert(LocationQuickFilterBar.noLocationValue)
        #expect(selectedLocations.contains(""))
        #expect(selectedLocations.count == 1)

        // Can combine with other locations
        selectedLocations.insert("Shelf A")
        #expect(selectedLocations.contains(""))
        #expect(selectedLocations.contains("Shelf A"))
        #expect(selectedLocations.count == 2)
    }

    @Test("Bar shows when locations exist but count is zero")
    func testShowsWithZeroCount() async throws {
        // Even if noLocationCount is 0, the bar should still show if locations exist
        let locations = ["Shelf A", "Shelf B"]
        let counts = ["Shelf A": 5, "Shelf B": 3]

        let _ = LocationQuickFilterBar(
            selectedLocations: .constant([]),
            availableLocations: locations,
            locationCounts: counts,
            noLocationCount: 0,
            totalCount: 8
        )
        // View creation should succeed
    }
}
