//
//  InventoryDetailView_EntitlementTests.swift
//  MoltenTests
//
//  Tests for InventoryDetailView entitlement and subscription tier enforcement
//

import Testing
import SwiftUI
@testable import Molten

@Suite("InventoryDetailView Entitlement Tests")
@MainActor
struct InventoryDetailView_EntitlementTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    // MARK: - Test Helpers

    func createTestItem() -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "test", sku: "001"),
            name: "Test Glass Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: ["blue", "transparent"],
            userTags: []
        )
    }

    func createEntitlementService(tier: SubscriptionTier) -> EntitlementService {
        return EntitlementService(tier: tier)
    }

    // MARK: - Subscription Tier Tests

    @Test("EntitlementService initializes with free tier by default")
    func testEntitlementServiceDefaultTier() {
        let service = EntitlementService()
        #expect(service.currentTier == .free)
    }

    @Test("EntitlementService initializes with specified tier")
    func testEntitlementServiceCustomTier() {
        let freeService = EntitlementService(tier: .free)
        #expect(freeService.currentTier == .free)

        let premiumService = EntitlementService(tier: .premium)
        #expect(premiumService.currentTier == .premium)
    }

    @Test("Update subscription tier")
    func testUpdateSubscriptionTier() {
        let service = EntitlementService(tier: .free)
        #expect(service.currentTier == .free)

        service.updateTier(.premium)
        #expect(service.currentTier == .premium)

        service.updateTier(.free)
        #expect(service.currentTier == .free)
    }

    // MARK: - Inventory Limit Tests - Free Tier

    @Test("Free tier has inventory limit")
    func testFreeTierHasInventoryLimit() {
        let service = createEntitlementService(tier: .free)
        let limit = service.getInventoryLimit()

        #expect(limit != nil)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxInventoryItems)
    }

    @Test("Free tier can add inventory when under limit")
    func testFreeTierCanAddInventoryUnderLimit() {
        let service = createEntitlementService(tier: .free)
        let limit = service.getInventoryLimit()!

        // Test one below limit
        let canAdd = service.canAddInventoryItem(currentCount: limit - 1)
        #expect(canAdd == true)

        // Test well under limit
        let canAddZero = service.canAddInventoryItem(currentCount: 0)
        #expect(canAddZero == true)
    }

    @Test("Free tier cannot add inventory at limit")
    func testFreeTierCannotAddInventoryAtLimit() {
        let service = createEntitlementService(tier: .free)
        let limit = service.getInventoryLimit()!

        // At limit
        let canAddAtLimit = service.canAddInventoryItem(currentCount: limit)
        #expect(canAddAtLimit == false)

        // Over limit
        let canAddOverLimit = service.canAddInventoryItem(currentCount: limit + 1)
        #expect(canAddOverLimit == false)
    }

    @Test("Free tier enforceInventoryLimit throws at limit")
    func testFreeTierEnforceInventoryLimitThrows() {
        let service = createEntitlementService(tier: .free)
        let limit = service.getInventoryLimit()!

        // Should not throw when under limit
        do {
            try service.enforceInventoryLimit(currentCount: limit - 1)
            // Success - no error thrown
        } catch {
            Issue.record("Should not throw when under limit")
        }

        // Should throw when at limit
        do {
            try service.enforceInventoryLimit(currentCount: limit)
            Issue.record("Should throw when at limit")
        } catch let error as EntitlementError {
            if case .inventoryLimitReached(let reportedLimit) = error {
                #expect(reportedLimit == limit)
            } else {
                Issue.record("Wrong error type thrown")
            }
        } catch {
            Issue.record("Wrong error type thrown")
        }
    }

    // MARK: - Inventory Limit Tests - Premium Tier

    @Test("Premium tier has unlimited inventory")
    func testPremiumTierHasUnlimitedInventory() {
        let service = createEntitlementService(tier: .premium)
        let limit = service.getInventoryLimit()

        #expect(limit == nil) // nil means unlimited
    }

    @Test("Premium tier can add inventory at any count")
    func testPremiumTierCanAddInventoryUnlimited() {
        let service = createEntitlementService(tier: .premium)

        // Test various high counts
        #expect(service.canAddInventoryItem(currentCount: 0) == true)
        #expect(service.canAddInventoryItem(currentCount: 100) == true)
        #expect(service.canAddInventoryItem(currentCount: 1000) == true)
        #expect(service.canAddInventoryItem(currentCount: 10000) == true)
    }

    @Test("Premium tier never throws inventory limit errors")
    func testPremiumTierNeverThrowsInventoryLimit() {
        let service = createEntitlementService(tier: .premium)

        // Should never throw regardless of count
        do {
            try service.enforceInventoryLimit(currentCount: 0)
            try service.enforceInventoryLimit(currentCount: 1000)
            try service.enforceInventoryLimit(currentCount: 100000)
            // Success - no errors
        } catch {
            Issue.record("Premium tier should never throw inventory limit errors")
        }
    }

    // MARK: - Shopping List Limit Tests

    @Test("Free tier has shopping list limit")
    func testFreeTierShoppingListLimit() {
        let service = createEntitlementService(tier: .free)
        let limit = service.getShoppingListLimit()

        #expect(limit != nil)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxShoppingListItems)
    }

    @Test("Premium tier has unlimited shopping list")
    func testPremiumTierUnlimitedShoppingList() {
        let service = createEntitlementService(tier: .premium)
        let limit = service.getShoppingListLimit()

        #expect(limit == nil)
    }

    @Test("Free tier shopping list enforcement")
    func testFreeTierShoppingListEnforcement() {
        let service = createEntitlementService(tier: .free)
        let limit = service.getShoppingListLimit()!

        // Under limit - OK
        #expect(service.canAddShoppingListItem(currentCount: limit - 1) == true)

        // At limit - blocked
        #expect(service.canAddShoppingListItem(currentCount: limit) == false)
    }

    // MARK: - Projects Limit Tests

    @Test("Free tier has projects limit")
    func testFreeTierProjectsLimit() {
        let service = createEntitlementService(tier: .free)
        let limit = service.getProjectsLimit()

        #expect(limit != nil)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxProjects)
    }

    @Test("Premium tier has unlimited projects")
    func testPremiumTierUnlimitedProjects() {
        let service = createEntitlementService(tier: .premium)
        let limit = service.getProjectsLimit()

        #expect(limit == nil)
    }

    // MARK: - Logbook Entries Limit Tests

    @Test("Free tier has logbook entries limit")
    func testFreeTierLogbookEntriesLimit() {
        let service = createEntitlementService(tier: .free)
        let limit = service.getLogbookEntriesLimit()

        #expect(limit != nil)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxLogbookEntries)
    }

    @Test("Premium tier has unlimited logbook entries")
    func testPremiumTierUnlimitedLogbookEntries() {
        let service = createEntitlementService(tier: .premium)
        let limit = service.getLogbookEntriesLimit()

        #expect(limit == nil)
    }

    // MARK: - Feature Access Tests

    @Test("Free tier cannot use batch label printing")
    func testFreeTierBatchLabelPrinting() {
        let service = createEntitlementService(tier: .free)
        #expect(service.canUseBatchLabelPrinting() == false)
    }

    @Test("Premium tier can use batch label printing")
    func testPremiumTierBatchLabelPrinting() {
        let service = createEntitlementService(tier: .premium)
        #expect(service.canUseBatchLabelPrinting() == true)
    }

    @Test("CSV import available to all tiers")
    func testCSVImportAvailableToAll() {
        let freeService = createEntitlementService(tier: .free)
        let premiumService = createEntitlementService(tier: .premium)

        #expect(freeService.canUseCSVImport() == true)
        #expect(premiumService.canUseCSVImport() == true)
    }

    @Test("Bulk editing available to all tiers")
    func testBulkEditingAvailableToAll() {
        let freeService = createEntitlementService(tier: .free)
        let premiumService = createEntitlementService(tier: .premium)

        #expect(freeService.canUseBulkEditing() == true)
        #expect(premiumService.canUseBulkEditing() == true)
    }

    @Test("Free tier cannot use QR code scanning")
    func testFreeTierQRCodeScanning() {
        let service = createEntitlementService(tier: .free)
        #expect(service.canUseQRCodeScanning() == false)
    }

    @Test("Premium tier can use QR code scanning")
    func testPremiumTierQRCodeScanning() {
        let service = createEntitlementService(tier: .premium)
        #expect(service.canUseQRCodeScanning() == true)
    }

    @Test("Free tier cannot add custom tags to inventory")
    func testFreeTierCustomInventoryTags() {
        let service = createEntitlementService(tier: .free)
        #expect(service.canAddCustomTagsToInventory() == false)
    }

    @Test("Premium tier can add custom tags to inventory")
    func testPremiumTierCustomInventoryTags() {
        let service = createEntitlementService(tier: .premium)
        #expect(service.canAddCustomTagsToInventory() == true)
    }

    @Test("Free tier cannot add images to inventory")
    func testFreeTierInventoryImages() {
        let service = createEntitlementService(tier: .free)
        #expect(service.canAddImagesToInventory() == false)
    }

    @Test("Premium tier can add images to inventory")
    func testPremiumTierInventoryImages() {
        let service = createEntitlementService(tier: .premium)
        #expect(service.canAddImagesToInventory() == true)
    }

    @Test("Free tier cannot add custom notes to inventory")
    func testFreeTierCustomInventoryNotes() {
        let service = createEntitlementService(tier: .free)
        #expect(service.canAddCustomNotesToInventory() == false)
    }

    @Test("Premium tier can add custom notes to inventory")
    func testPremiumTierCustomInventoryNotes() {
        let service = createEntitlementService(tier: .premium)
        #expect(service.canAddCustomNotesToInventory() == true)
    }

    @Test("Free tier cannot use custom fields")
    func testFreeTierCustomFields() {
        let service = createEntitlementService(tier: .free)
        #expect(service.canUseCustomFields() == false)
    }

    @Test("Premium tier can use custom fields")
    func testPremiumTierCustomFields() {
        let service = createEntitlementService(tier: .premium)
        #expect(service.canUseCustomFields() == true)
    }

    // MARK: - Feature Enforcement Tests

    @Test("Enforce batch label printing feature")
    func testEnforceBatchLabelPrinting() {
        let freeService = createEntitlementService(tier: .free)
        let premiumService = createEntitlementService(tier: .premium)

        // Free tier should throw
        do {
            try freeService.enforceFeatureAccess(.batchLabelPrinting)
            Issue.record("Free tier should throw for batch label printing")
        } catch let error as EntitlementError {
            if case .featureRequiresPremium(let feature) = error {
                #expect(feature == .batchLabelPrinting)
            }
        } catch {
            Issue.record("Wrong error type")
        }

        // Premium tier should not throw
        do {
            try premiumService.enforceFeatureAccess(.batchLabelPrinting)
            // Success
        } catch {
            Issue.record("Premium tier should not throw for batch label printing")
        }
    }

    @Test("Enforce custom fields feature")
    func testEnforceCustomFields() {
        let freeService = createEntitlementService(tier: .free)

        do {
            try freeService.enforceFeatureAccess(.customFields)
            Issue.record("Should throw for free tier")
        } catch let error as EntitlementError {
            if case .featureRequiresPremium(let feature) = error {
                #expect(feature == .customFields)
            }
        } catch {
            Issue.record("Wrong error type")
        }
    }

    // MARK: - Error Message Tests

    @Test("Inventory limit error message includes limit")
    func testInventoryLimitErrorMessage() {
        let error = EntitlementError.inventoryLimitReached(limit: 25)
        let message = error.errorDescription ?? ""

        #expect(message.contains("25"))
        #expect(message.contains("inventory"))
        #expect(message.contains("upgrade") || message.contains("Upgrade"))
    }

    @Test("Shopping list limit error message includes limit")
    func testShoppingListLimitErrorMessage() {
        let error = EntitlementError.shoppingListLimitReached(limit: 15)
        let message = error.errorDescription ?? ""

        #expect(message.contains("15"))
        #expect(message.contains("shopping"))
    }

    @Test("Feature requires premium error message includes feature name")
    func testFeatureRequiresPremiumErrorMessage() {
        let error = EntitlementError.featureRequiresPremium(feature: .batchLabelPrinting)
        let message = error.errorDescription ?? ""

        #expect(message.contains("Batch Label Printing"))
        #expect(message.contains("premium") || message.contains("Premium"))
    }

    // MARK: - Subscription Config Tests

    @Test("Free tier inventory limit matches config")
    func testFreeTierInventoryLimitConfig() {
        let limit = SubscriptionConfig.inventoryLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxInventoryItems)
    }

    @Test("Premium tier inventory limit is nil (unlimited)")
    func testPremiumTierInventoryLimitConfig() {
        let limit = SubscriptionConfig.inventoryLimit(for: .premium)
        #expect(limit == nil)
    }

    @Test("Free tier shopping list limit matches config")
    func testFreeTierShoppingListLimitConfig() {
        let limit = SubscriptionConfig.shoppingListLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxShoppingListItems)
    }

    @Test("Free tier projects limit matches config")
    func testFreeTierProjectsLimitConfig() {
        let limit = SubscriptionConfig.projectsLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxProjects)
    }

    @Test("Free tier logbook entries limit matches config")
    func testFreeTierLogbookEntriesLimitConfig() {
        let limit = SubscriptionConfig.logbookEntriesLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxLogbookEntries)
    }

    // MARK: - Tier Comparison Tests

    @Test("SubscriptionTier equality")
    func testSubscriptionTierEquality() {
        #expect(SubscriptionTier.free == SubscriptionTier.free)
        #expect(SubscriptionTier.premium == SubscriptionTier.premium)
        #expect(SubscriptionTier.free != SubscriptionTier.premium)
        #expect(SubscriptionTier.premium != SubscriptionTier.free)
    }

    // MARK: - Inventory Count Calculation Tests

    @Test("Count unique items with inventory")
    func testCountUniqueItemsWithInventory() async throws {
        let service = deps.inventoryTrackingService

        // Create test items
        let item1 = createTestItem()

        // Add inventory to item1
        _ = try await service.addInventory(
            quantity: 5.0,
            type: "rod",
            toItem: item1.glassItem.stable_id,
            atLocation: nil
        )

        // Search for items with inventory
        let itemsWithInventory = try await service.searchItems(text: "", hasInventory: true)

        // Should have at least 1 item with inventory
        #expect(itemsWithInventory.count >= 1)

        // Verify our item is in the list
        let hasOurItem = itemsWithInventory.contains { $0.glassItem.stable_id == item1.glassItem.stable_id }
        #expect(hasOurItem)
    }

    @Test("Inventory count excludes items without inventory")
    func testInventoryCountExcludesEmpty() async throws {
        let service = deps.inventoryTrackingService

        // Create item without inventory
        let item = createTestItem()

        // Search for items with inventory
        let itemsWithInventory = try await service.searchItems(text: "", hasInventory: true)

        // Our item should NOT be in the list (no inventory added)
        let hasOurItem = itemsWithInventory.contains { $0.glassItem.stable_id == item.glassItem.stable_id }
        #expect(!hasOurItem)
    }

    // MARK: - Premium Feature Set Tests

    @Test("All premium features enabled for premium tier")
    func testAllPremiumFeaturesEnabled() {
        let service = createEntitlementService(tier: .premium)

        #expect(service.canUseBatchLabelPrinting() == true)
        #expect(service.canUseQRCodeScanning() == true)
        #expect(service.canAddCustomTagsToInventory() == true)
        #expect(service.canAddImagesToInventory() == true)
        #expect(service.canAddCustomNotesToInventory() == true)
        #expect(service.canUseCustomFields() == true)
    }

    @Test("Premium tier has all unlimited limits")
    func testPremiumTierAllUnlimited() {
        let service = createEntitlementService(tier: .premium)

        #expect(service.getInventoryLimit() == nil)
        #expect(service.getShoppingListLimit() == nil)
        #expect(service.getProjectsLimit() == nil)
        #expect(service.getLogbookEntriesLimit() == nil)
    }

    @Test("Free tier has all premium features disabled")
    func testFreeTierPremiumFeaturesDisabled() {
        let service = createEntitlementService(tier: .free)

        #expect(service.canUseBatchLabelPrinting() == false)
        #expect(service.canUseQRCodeScanning() == false)
        #expect(service.canAddCustomTagsToInventory() == false)
        #expect(service.canAddImagesToInventory() == false)
        #expect(service.canAddCustomNotesToInventory() == false)
        #expect(service.canUseCustomFields() == false)
    }

    @Test("Free tier has all numeric limits set")
    func testFreeTierAllLimitsSet() {
        let service = createEntitlementService(tier: .free)

        #expect(service.getInventoryLimit() != nil)
        #expect(service.getShoppingListLimit() != nil)
        #expect(service.getProjectsLimit() != nil)
        #expect(service.getLogbookEntriesLimit() != nil)
    }
}
