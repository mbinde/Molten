//
//  EntitlementServiceTests.swift
//  MoltenTests
//
//  Tests for subscription entitlement checking logic
//

import Testing
import Foundation
@testable import Molten

@Suite("EntitlementService Tests")
struct EntitlementServiceTests {

    // MARK: - Tier Detection Tests

    @MainActor
    @Test("Free tier user has correct subscription tier")
    func testFreeTierDetection() async throws {
        let service = EntitlementService(tier: .free)
        let tier = await service.currentTier
        #expect(tier == .free)
    }

    @MainActor
    @Test("Premium tier user has correct subscription tier")
    func testPremiumTierDetection() async throws {
        let service = EntitlementService(tier: .premium)
        let tier = await service.currentTier
        #expect(tier == .premium)
    }

    // MARK: - Inventory Limit Tests

    @MainActor
    @Test("Free tier can add inventory when under limit")
    func testFreeTierCanAddInventoryUnderLimit() async throws {
        let service = EntitlementService(tier: .free)
        let canAdd = await service.canAddInventoryItem(currentCount: 10)
        #expect(canAdd == true)
    }

    @MainActor
    @Test("Free tier cannot add inventory when at limit")
    func testFreeTierCannotAddInventoryAtLimit() async throws {
        let service = EntitlementService(tier: .free)
        let canAdd = await service.canAddInventoryItem(currentCount: 50)
        #expect(canAdd == false)
    }

    @MainActor
    @Test("Premium tier can add unlimited inventory")
    func testPremiumTierUnlimitedInventory() async throws {
        let service = EntitlementService(tier: .premium)
        let canAdd = await service.canAddInventoryItem(currentCount: 10000)
        #expect(canAdd == true)
    }

    // MARK: - Shopping List Limit Tests

    @MainActor
    @Test("Free tier can add shopping list item when under limit")
    func testFreeTierCanAddShoppingListItemUnderLimit() async throws {
        let service = EntitlementService(tier: .free)
        let canAdd = await service.canAddShoppingListItem(currentCount: 10)
        #expect(canAdd == true)
    }

    @MainActor
    @Test("Free tier cannot add shopping list item when at limit")
    func testFreeTierCannotAddShoppingListItemAtLimit() async throws {
        let service = EntitlementService(tier: .free)
        let canAdd = await service.canAddShoppingListItem(currentCount: 15)
        #expect(canAdd == false)
    }

    @MainActor
    @Test("Premium tier can add unlimited shopping list items")
    func testPremiumTierUnlimitedShoppingList() async throws {
        let service = EntitlementService(tier: .premium)
        let canAdd = await service.canAddShoppingListItem(currentCount: 10000)
        #expect(canAdd == true)
    }

    // MARK: - Projects Limit Tests

    @MainActor
    @Test("Free tier can add project when under limit")
    func testFreeTierCanAddProjectUnderLimit() async throws {
        let service = EntitlementService(tier: .free)
        let canAdd = await service.canAddProject(currentCount: 3)
        #expect(canAdd == true)
    }

    @MainActor
    @Test("Free tier cannot add project when at limit")
    func testFreeTierCannotAddProjectAtLimit() async throws {
        let service = EntitlementService(tier: .free)
        let canAdd = await service.canAddProject(currentCount: 5)
        #expect(canAdd == false)
    }

    @MainActor
    @Test("Premium tier can add unlimited projects")
    func testPremiumTierUnlimitedProjects() async throws {
        let service = EntitlementService(tier: .premium)
        let canAdd = await service.canAddProject(currentCount: 10000)
        #expect(canAdd == true)
    }

    // MARK: - Logbook Entries Limit Tests

    @MainActor
    @Test("Free tier can add logbook entry when under limit")
    func testFreeTierCanAddLogbookEntryUnderLimit() async throws {
        let service = EntitlementService(tier: .free)
        let canAdd = await service.canAddLogbookEntry(currentCount: 20)
        #expect(canAdd == true)
    }

    @MainActor
    @Test("Free tier cannot add logbook entry when at limit")
    func testFreeTierCannotAddLogbookEntryAtLimit() async throws {
        let service = EntitlementService(tier: .free)
        let canAdd = await service.canAddLogbookEntry(currentCount: 30)
        #expect(canAdd == false)
    }

    @MainActor
    @Test("Premium tier can add unlimited logbook entries")
    func testPremiumTierUnlimitedLogbookEntries() async throws {
        let service = EntitlementService(tier: .premium)
        let canAdd = await service.canAddLogbookEntry(currentCount: 10000)
        #expect(canAdd == true)
    }

    // MARK: - Feature Access Tests

    @MainActor
    @Test("Free tier cannot use batch label printing")
    func testFreeTierCannotUseBatchLabelPrinting() async throws {
        let service = EntitlementService(tier: .free)
        let canUse = await service.canUseBatchLabelPrinting()
        #expect(canUse == false)
    }

    @MainActor
    @Test("Premium tier can use batch label printing")
    func testPremiumTierCanUseBatchLabelPrinting() async throws {
        let service = EntitlementService(tier: .premium)
        let canUse = await service.canUseBatchLabelPrinting()
        #expect(canUse == true)
    }

    @MainActor
    @Test("Free tier can use CSV import (universal feature)")
    func testFreeTierCanUseCSVImport() async throws {
        let service = EntitlementService(tier: .free)
        let canUse = await service.canUseCSVImport()
        #expect(canUse == true)  // CSV Import is now universal
    }

    @MainActor
    @Test("Premium tier can use CSV import")
    func testPremiumTierCanUseCSVImport() async throws {
        let service = EntitlementService(tier: .premium)
        let canUse = await service.canUseCSVImport()
        #expect(canUse == true)
    }

    @MainActor
    @Test("Free tier can use bulk editing (universal feature)")
    func testFreeTierCanUseBulkEditing() async throws {
        let service = EntitlementService(tier: .free)
        let canUse = await service.canUseBulkEditing()
        #expect(canUse == true)  // Bulk Editing is now universal
    }

    @MainActor
    @Test("Premium tier can use bulk editing")
    func testPremiumTierCanUseBulkEditing() async throws {
        let service = EntitlementService(tier: .premium)
        let canUse = await service.canUseBulkEditing()
        #expect(canUse == true)
    }

    @MainActor
    @Test("Free tier cannot use custom fields")
    func testFreeTierCannotUseCustomFields() async throws {
        let service = EntitlementService(tier: .free)
        let canUse = await service.canUseCustomFields()
        #expect(canUse == false)
    }

    @MainActor
    @Test("Premium tier can use custom fields")
    func testPremiumTierCanUseCustomFields() async throws {
        let service = EntitlementService(tier: .premium)
        let canUse = await service.canUseCustomFields()
        #expect(canUse == true)
    }

    // MARK: - Limit Retrieval Tests

    @MainActor
    @Test("Get correct inventory limit for free tier")
    func testGetInventoryLimitForFreeTier() async throws {
        let service = EntitlementService(tier: .free)
        let limit = await service.getInventoryLimit()
        #expect(limit == 50)
    }

    @MainActor
    @Test("Get unlimited inventory for premium tier")
    func testGetInventoryLimitForPremiumTier() async throws {
        let service = EntitlementService(tier: .premium)
        let limit = await service.getInventoryLimit()
        #expect(limit == nil)
    }

    @MainActor
    @Test("Get correct shopping list limit for free tier")
    func testGetShoppingListLimitForFreeTier() async throws {
        let service = EntitlementService(tier: .free)
        let limit = await service.getShoppingListLimit()
        #expect(limit == 15)
    }

    @MainActor
    @Test("Get unlimited shopping list for premium tier")
    func testGetShoppingListLimitForPremiumTier() async throws {
        let service = EntitlementService(tier: .premium)
        let limit = await service.getShoppingListLimit()
        #expect(limit == nil)
    }

    @MainActor
    @Test("Get correct projects limit for free tier")
    func testGetProjectsLimitForFreeTier() async throws {
        let service = EntitlementService(tier: .free)
        let limit = await service.getProjectsLimit()
        #expect(limit == 5)
    }

    @MainActor
    @Test("Get unlimited projects for premium tier")
    func testGetProjectsLimitForPremiumTier() async throws {
        let service = EntitlementService(tier: .premium)
        let limit = await service.getProjectsLimit()
        #expect(limit == nil)
    }

    @MainActor
    @Test("Get correct logbook entries limit for free tier")
    func testGetLogbookEntriesLimitForFreeTier() async throws {
        let service = EntitlementService(tier: .free)
        let limit = await service.getLogbookEntriesLimit()
        #expect(limit == 30)
    }

    @MainActor
    @Test("Get unlimited logbook entries for premium tier")
    func testGetLogbookEntriesLimitForPremiumTier() async throws {
        let service = EntitlementService(tier: .premium)
        let limit = await service.getLogbookEntriesLimit()
        #expect(limit == nil)
    }
}
