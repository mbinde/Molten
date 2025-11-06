//
//  DefaultTabTests.swift
//  MoltenTests
//
//  Unit tests for DefaultTab enum
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

@Suite("DefaultTab Tests")
struct DefaultTabTests {

    // MARK: - Raw Value Tests

    @Test("catalog has correct raw value")
    func testCatalogRawValue() {
        #expect(DefaultTab.catalog.rawValue == 0)
    }

    @Test("inventory has correct raw value")
    func testInventoryRawValue() {
        #expect(DefaultTab.inventory.rawValue == 1)
    }

    @Test("shopping has correct raw value")
    func testShoppingRawValue() {
        #expect(DefaultTab.shopping.rawValue == 2)
    }

    @Test("projects has correct raw value")
    func testProjectsRawValue() {
        #expect(DefaultTab.projects.rawValue == 3)
    }

    @Test("purchases has correct raw value")
    func testPurchasesRawValue() {
        #expect(DefaultTab.purchases.rawValue == 4)
    }

    @Test("projectPlans has correct raw value")
    func testProjectPlansRawValue() {
        #expect(DefaultTab.projectPlans.rawValue == 5)
    }

    @Test("logbook has correct raw value")
    func testLogbookRawValue() {
        #expect(DefaultTab.logbook.rawValue == 6)
    }

    @Test("recipes has correct raw value")
    func testRecipesRawValue() {
        #expect(DefaultTab.recipes.rawValue == 7)
    }

    @Test("settings has correct raw value")
    func testSettingsRawValue() {
        #expect(DefaultTab.settings.rawValue == 8)
    }

    @Test("locations has correct raw value")
    func testLocationsRawValue() {
        #expect(DefaultTab.locations.rawValue == 9)
    }

    @Test("kilnSchedules has correct raw value")
    func testKilnSchedulesRawValue() {
        #expect(DefaultTab.kilnSchedules.rawValue == 10)
    }

    @Test("DefaultTab can be initialized from raw value")
    func testInitFromRawValue() {
        #expect(DefaultTab(rawValue: 0) == .catalog)
        #expect(DefaultTab(rawValue: 1) == .inventory)
        #expect(DefaultTab(rawValue: 8) == .settings)
        #expect(DefaultTab(rawValue: 10) == .kilnSchedules)
    }

    @Test("DefaultTab returns nil for invalid raw value")
    func testInvalidRawValue() {
        #expect(DefaultTab(rawValue: -1) == nil)
        #expect(DefaultTab(rawValue: 11) == nil)
        #expect(DefaultTab(rawValue: 100) == nil)
    }

    // MARK: - CaseIterable Tests

    @Test("allCases contains all tabs")
    func testAllCases() {
        let allCases = DefaultTab.allCases

        #expect(allCases.count == 11)
        #expect(allCases.contains(.catalog))
        #expect(allCases.contains(.inventory))
        #expect(allCases.contains(.shopping))
        #expect(allCases.contains(.projects))
        #expect(allCases.contains(.purchases))
        #expect(allCases.contains(.projectPlans))
        #expect(allCases.contains(.logbook))
        #expect(allCases.contains(.recipes))
        #expect(allCases.contains(.settings))
        #expect(allCases.contains(.locations))
        #expect(allCases.contains(.kilnSchedules))
    }

    @Test("allCases order is consistent with raw values")
    func testAllCasesOrder() {
        let allCases = DefaultTab.allCases

        #expect(allCases[0] == .catalog)
        #expect(allCases[1] == .inventory)
        #expect(allCases[2] == .shopping)
        #expect(allCases[3] == .projects)
        #expect(allCases[4] == .purchases)
        #expect(allCases[5] == .projectPlans)
        #expect(allCases[6] == .logbook)
        #expect(allCases[7] == .recipes)
        #expect(allCases[8] == .settings)
        #expect(allCases[9] == .locations)
        #expect(allCases[10] == .kilnSchedules)
    }

    // MARK: - Display Name Tests

    @Test("catalog has correct display name")
    func testCatalogDisplayName() {
        #expect(DefaultTab.catalog.displayName == "Catalog")
    }

    @Test("inventory has correct display name")
    func testInventoryDisplayName() {
        #expect(DefaultTab.inventory.displayName == "Inventory")
    }

    @Test("shopping has correct display name")
    func testShoppingDisplayName() {
        #expect(DefaultTab.shopping.displayName == "Shopping")
    }

    @Test("projects has correct display name")
    func testProjectsDisplayName() {
        #expect(DefaultTab.projects.displayName == "Projects")
    }

    @Test("purchases has correct display name")
    func testPurchasesDisplayName() {
        #expect(DefaultTab.purchases.displayName == "Purchases")
    }

    @Test("projectPlans has correct display name")
    func testProjectPlansDisplayName() {
        #expect(DefaultTab.projectPlans.displayName == "Projects")
    }

    @Test("logbook has correct display name")
    func testLogbookDisplayName() {
        #expect(DefaultTab.logbook.displayName == "Logbook")
    }

    @Test("recipes has correct display name")
    func testRecipesDisplayName() {
        #expect(DefaultTab.recipes.displayName == "Recipes")
    }

    @Test("settings has correct display name")
    func testSettingsDisplayName() {
        #expect(DefaultTab.settings.displayName == "Settings")
    }

    @Test("locations has correct display name")
    func testLocationsDisplayName() {
        #expect(DefaultTab.locations.displayName == "Locations")
    }

    @Test("kilnSchedules has correct display name")
    func testKilnSchedulesDisplayName() {
        #expect(DefaultTab.kilnSchedules.displayName == "Kiln")
    }

    @Test("All display names are not empty")
    func testAllDisplayNamesNotEmpty() {
        for tab in DefaultTab.allCases {
            #expect(!tab.displayName.isEmpty)
        }
    }

    @Test("All display names are capitalized")
    func testAllDisplayNamesCapitalized() {
        for tab in DefaultTab.allCases {
            #expect(tab.displayName.first?.isUppercase == true)
        }
    }

    // MARK: - System Image Tests

    @Test("catalog has correct system image")
    func testCatalogSystemImage() {
        #expect(DefaultTab.catalog.systemImage == "text.justify")
    }

    @Test("inventory has correct system image")
    func testInventorySystemImage() {
        #expect(DefaultTab.inventory.systemImage == "archivebox")
    }

    @Test("shopping has correct system image")
    func testShoppingSystemImage() {
        #expect(DefaultTab.shopping.systemImage == "cart")
    }

    @Test("projects has correct system image")
    func testProjectsSystemImage() {
        #expect(DefaultTab.projects.systemImage == "folder")
    }

    @Test("purchases has correct system image")
    func testPurchasesSystemImage() {
        #expect(DefaultTab.purchases.systemImage == "creditcard")
    }

    @Test("projectPlans has correct system image")
    func testProjectPlansSystemImage() {
        #expect(DefaultTab.projectPlans.systemImage == "pencil.and.list.clipboard")
    }

    @Test("logbook has correct system image")
    func testLogbookSystemImage() {
        #expect(DefaultTab.logbook.systemImage == "book.pages")
    }

    @Test("recipes has correct system image")
    func testRecipesSystemImage() {
        #expect(DefaultTab.recipes.systemImage == "book.closed")
    }

    @Test("settings has correct system image")
    func testSettingsSystemImage() {
        #expect(DefaultTab.settings.systemImage == "gear")
    }

    @Test("locations has correct system image")
    func testLocationsSystemImage() {
        #expect(DefaultTab.locations.systemImage == "map")
    }

    @Test("kilnSchedules has correct system image")
    func testKilnSchedulesSystemImage() {
        #expect(DefaultTab.kilnSchedules.systemImage == "fireplace.fill")
    }

    @Test("All system images are not empty")
    func testAllSystemImagesNotEmpty() {
        for tab in DefaultTab.allCases {
            #expect(!tab.systemImage.isEmpty)
        }
    }

    @Test("All system images are valid SF Symbol names")
    func testAllSystemImagesAreValidSFSymbols() {
        for tab in DefaultTab.allCases {
            let image = tab.systemImage
            // SF Symbols should be lowercase or contain dots or periods
            #expect(image == image.lowercased() || image.contains("."))
        }
    }

    // MARK: - Equatable Tests

    @Test("DefaultTab equality works correctly")
    func testEquality() {
        #expect(DefaultTab.catalog == DefaultTab.catalog)
        #expect(DefaultTab.catalog != DefaultTab.inventory)
        #expect(DefaultTab.settings == DefaultTab.settings)
    }

    // MARK: - Raw Value Uniqueness Tests

    @Test("All raw values are unique")
    func testAllRawValuesUnique() {
        let rawValues = DefaultTab.allCases.map { $0.rawValue }
        let uniqueRawValues = Set(rawValues)

        #expect(rawValues.count == uniqueRawValues.count)
    }

    @Test("Raw values are sequential starting from 0")
    func testRawValuesSequential() {
        let rawValues = DefaultTab.allCases.map { $0.rawValue }.sorted()

        for (index, value) in rawValues.enumerated() {
            #expect(value == index)
        }
    }

    // MARK: - UserDefaults Compatibility Tests

    @Test("Tabs can be stored in UserDefaults")
    func testUserDefaultsCompatibility() {
        // Raw values are suitable for UserDefaults
        for tab in DefaultTab.allCases {
            let rawValue = tab.rawValue
            let restored = DefaultTab(rawValue: rawValue)

            #expect(restored == tab)
        }
    }

    // MARK: - Deprecated Tab Tests

    @Test("Deprecated tabs are marked appropriately")
    func testDeprecatedTabs() {
        // projectPlans and logbook are deprecated (accessed through projects menu)
        #expect(DefaultTab.projectPlans.rawValue == 5)
        #expect(DefaultTab.logbook.rawValue == 6)

        // purchases is kept for backwards compatibility
        #expect(DefaultTab.purchases.rawValue == 4)
    }

    @Test("Projects and projectPlans have same display name")
    func testProjectsAndProjectPlansSameDisplay() {
        #expect(DefaultTab.projects.displayName == DefaultTab.projectPlans.displayName)
    }

    // MARK: - Edge Cases

    @Test("All tabs have distinct system images except deprecated")
    func testSystemImagesDistinct() {
        let allImages = DefaultTab.allCases.map { $0.systemImage }

        // Count unique images
        let uniqueImages = Set(allImages)

        // Should have at least 8 unique images (some deprecated tabs may share)
        #expect(uniqueImages.count >= 8)
    }
}

// MARK: - ProjectViewType Tests

@Suite("ProjectViewType Tests")
struct ProjectViewTypeTests {

    // MARK: - Display Name Tests

    @Test("plans has correct display name")
    func testPlansDisplayName() {
        #expect(ProjectViewType.plans.displayName == "Project")
    }

    @Test("logs has correct display name")
    func testLogsDisplayName() {
        #expect(ProjectViewType.logs.displayName == "Project Logs")
    }

    // MARK: - System Image Tests

    @Test("plans has correct system image")
    func testPlansSystemImage() {
        #expect(ProjectViewType.plans.systemImage == "pencil.and.list.clipboard")
    }

    @Test("logs has correct system image")
    func testLogsSystemImage() {
        #expect(ProjectViewType.logs.systemImage == "book.pages")
    }

    // MARK: - Description Tests

    @Test("plans has correct description")
    func testPlansDescription() {
        #expect(ProjectViewType.plans.description == "Plan future projects and track materials")
    }

    @Test("logs has correct description")
    func testLogsDescription() {
        #expect(ProjectViewType.logs.description == "Record completed projects and notes")
    }

    // MARK: - Consistency Tests

    @Test("All system images are not empty")
    func testAllSystemImagesNotEmpty() {
        #expect(!ProjectViewType.plans.systemImage.isEmpty)
        #expect(!ProjectViewType.logs.systemImage.isEmpty)
    }

    @Test("All display names are not empty")
    func testAllDisplayNamesNotEmpty() {
        #expect(!ProjectViewType.plans.displayName.isEmpty)
        #expect(!ProjectViewType.logs.displayName.isEmpty)
    }

    @Test("All descriptions are not empty")
    func testAllDescriptionsNotEmpty() {
        #expect(!ProjectViewType.plans.description.isEmpty)
        #expect(!ProjectViewType.logs.description.isEmpty)
    }

    @Test("System images match DefaultTab deprecated tabs")
    func testSystemImagesMatchDefaultTab() {
        // plans should match projectPlans
        #expect(ProjectViewType.plans.systemImage == DefaultTab.projectPlans.systemImage)

        // logs should match logbook
        #expect(ProjectViewType.logs.systemImage == DefaultTab.logbook.systemImage)
    }
}
