//
//  ManufacturerFilterModelTests.swift
//  MoltenTests
//
//  Tests for ManufacturerFilterModel business logic
//

import Testing
import Foundation
@testable import Molten

@Suite("ManufacturerFilterModel Tests")
struct ManufacturerFilterModelTests {

    @Test("Initialize with default selection (all manufacturers)")
    func testInitializeWithDefaultSelection() {
        let allManufacturers = ["EF", "DH", "BE", "CiM"]
        let model = ManufacturerFilterModel(
            availableManufacturers: allManufacturers,
            selectedManufacturers: nil  // nil = default to all
        )

        #expect(model.selectedManufacturers == Set(allManufacturers))
        #expect(model.isManufacturerEnabled("EF") == true)
        #expect(model.isManufacturerEnabled("DH") == true)
    }

    @Test("Initialize with specific selection")
    func testInitializeWithSpecificSelection() {
        let allManufacturers = ["EF", "DH", "BE", "CiM"]
        let selected = Set(["EF", "DH"])
        let model = ManufacturerFilterModel(
            availableManufacturers: allManufacturers,
            selectedManufacturers: selected
        )

        #expect(model.selectedManufacturers == selected)
        #expect(model.isManufacturerEnabled("EF") == true)
        #expect(model.isManufacturerEnabled("DH") == true)
        #expect(model.isManufacturerEnabled("BE") == false)
        #expect(model.isManufacturerEnabled("CiM") == false)
    }

    @Test("Enable manufacturer")
    func testEnableManufacturer() {
        let allManufacturers = ["EF", "DH", "BE"]
        var model = ManufacturerFilterModel(
            availableManufacturers: allManufacturers,
            selectedManufacturers: Set(["EF"])
        )

        model.enable("DH")

        #expect(model.isManufacturerEnabled("EF") == true)
        #expect(model.isManufacturerEnabled("DH") == true)
        #expect(model.isManufacturerEnabled("BE") == false)
    }

    @Test("Disable manufacturer")
    func testDisableManufacturer() {
        let allManufacturers = ["EF", "DH", "BE"]
        var model = ManufacturerFilterModel(
            availableManufacturers: allManufacturers,
            selectedManufacturers: Set(["EF", "DH"])
        )

        model.disable("EF")

        #expect(model.isManufacturerEnabled("EF") == false)
        #expect(model.isManufacturerEnabled("DH") == true)
    }

    @Test("Select all manufacturers")
    func testSelectAll() {
        let allManufacturers = ["EF", "DH", "BE", "CiM"]
        var model = ManufacturerFilterModel(
            availableManufacturers: allManufacturers,
            selectedManufacturers: Set(["EF"])
        )

        model.selectAll()

        #expect(model.selectedManufacturers == Set(allManufacturers))
        #expect(model.isManufacturerEnabled("EF") == true)
        #expect(model.isManufacturerEnabled("DH") == true)
        #expect(model.isManufacturerEnabled("BE") == true)
        #expect(model.isManufacturerEnabled("CiM") == true)
    }

    @Test("Select none (clear all)")
    func testSelectNone() {
        let allManufacturers = ["EF", "DH", "BE"]
        var model = ManufacturerFilterModel(
            availableManufacturers: allManufacturers,
            selectedManufacturers: Set(allManufacturers)
        )

        model.selectNone()

        #expect(model.selectedManufacturers.isEmpty)
        #expect(model.isManufacturerEnabled("EF") == false)
        #expect(model.isManufacturerEnabled("DH") == false)
        #expect(model.isManufacturerEnabled("BE") == false)
    }

    @Test("Should show item with enabled manufacturer")
    func testShouldShowItemWithEnabledManufacturer() {
        let model = ManufacturerFilterModel(
            availableManufacturers: ["EF", "DH"],
            selectedManufacturers: Set(["EF"])
        )

        #expect(model.shouldShowItem(manufacturer: "EF") == true)
        #expect(model.shouldShowItem(manufacturer: "DH") == false)
    }

    @Test("Should show item with nil manufacturer (always show)")
    func testShouldShowItemWithNilManufacturer() {
        let model = ManufacturerFilterModel(
            availableManufacturers: ["EF", "DH"],
            selectedManufacturers: Set(["EF"])
        )

        #expect(model.shouldShowItem(manufacturer: nil) == true)
    }

    @Test("Update available manufacturers (add new manufacturer, enable by default)")
    func testUpdateAvailableManufacturersAddsNew() {
        var model = ManufacturerFilterModel(
            availableManufacturers: ["EF", "DH"],
            selectedManufacturers: Set(["EF", "DH"])
        )

        model.updateAvailableManufacturers(["EF", "DH", "BE"])  // BE is new

        #expect(model.availableManufacturers == ["EF", "DH", "BE"])
        #expect(model.isManufacturerEnabled("EF") == true)
        #expect(model.isManufacturerEnabled("DH") == true)
        #expect(model.isManufacturerEnabled("BE") == true)  // New manufacturer enabled by default
    }

    @Test("Update available manufacturers (remove obsolete manufacturer)")
    func testUpdateAvailableManufacturersRemovesObsolete() {
        var model = ManufacturerFilterModel(
            availableManufacturers: ["EF", "DH", "BE"],
            selectedManufacturers: Set(["EF", "DH", "BE"])
        )

        model.updateAvailableManufacturers(["EF", "DH"])  // BE removed

        #expect(model.availableManufacturers == ["EF", "DH"])
        #expect(model.selectedManufacturers == Set(["EF", "DH"]))
        #expect(model.isManufacturerEnabled("BE") == false)
    }

    @Test("Get enabled manufacturers count")
    func testEnabledManufacturersCount() {
        let model = ManufacturerFilterModel(
            availableManufacturers: ["EF", "DH", "BE", "CiM"],
            selectedManufacturers: Set(["EF", "DH"])
        )

        #expect(model.enabledCount == 2)
    }

    @Test("Get total manufacturers count")
    func testTotalManufacturersCount() {
        let model = ManufacturerFilterModel(
            availableManufacturers: ["EF", "DH", "BE", "CiM"],
            selectedManufacturers: Set(["EF", "DH"])
        )

        #expect(model.totalCount == 4)
    }

    @Test("Check if all manufacturers are selected")
    func testIsAllSelected() {
        var model = ManufacturerFilterModel(
            availableManufacturers: ["EF", "DH"],
            selectedManufacturers: Set(["EF"])
        )

        #expect(model.isAllSelected == false)

        model.enable("DH")
        #expect(model.isAllSelected == true)
    }

    @Test("Check if no manufacturers are selected")
    func testIsNoneSelected() {
        var model = ManufacturerFilterModel(
            availableManufacturers: ["EF", "DH"],
            selectedManufacturers: Set(["EF"])
        )

        #expect(model.isNoneSelected == false)

        model.selectNone()
        #expect(model.isNoneSelected == true)
    }
}
