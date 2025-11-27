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

    /// CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    // MARK: - Test Setup

    init() {
        // Ensure debug subscription tier override is disabled for tests
        // This prevents UserDefaults from polluting test results
        DebugConfig.debugOverrideSubscriptionTier = false
    }

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

    /// Get a real catalog item for tests that need to add inventory (catalog is read-only)
    func getRealCatalogItem() async throws -> GlassItemModel {
        let catalogService = deps.catalogService
        let catalogItems = try await catalogService.getGlassItemsLightweight()

        guard let glassItem = catalogItems.first(where: { $0.sku != nil }) else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No catalog items available for testing"])
        }

        return glassItem
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
        #expect(limit == 25)
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
        #expect(limit == 5)
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
        #expect(limit == 10)
    }

    @Test("Premium tier has unlimited logbook entries")
    func testPremiumTierUnlimitedLogbookEntries() {
        let service = createEntitlementService(tier: .premium)
        let limit = service.getLogbookEntriesLimit()

        #expect(limit == nil)
    }

    // MARK: - Versioned Cloud Backups Feature Tests

    @Test("Free tier cannot use versioned cloud backups")
    func testFreeTierCannotUseVersionedCloudBackups() {
        let service = createEntitlementService(tier: .free)
        #expect(service.canUseVersionedCloudBackups() == false)
    }

    @Test("Premium tier can use versioned cloud backups")
    func testPremiumTierCanUseVersionedCloudBackups() {
        let service = createEntitlementService(tier: .premium)
        #expect(service.canUseVersionedCloudBackups() == true)
    }

    @Test("Enforce versioned cloud backups feature")
    func testEnforceVersionedCloudBackups() {
        let freeService = createEntitlementService(tier: .free)
        let premiumService = createEntitlementService(tier: .premium)

        // Free tier should throw
        do {
            try freeService.enforceFeatureAccess(.versionedCloudBackups)
            Issue.record("Free tier should throw for versioned cloud backups")
        } catch let error as EntitlementError {
            if case .featureRequiresPro(let feature) = error {
                #expect(feature == .versionedCloudBackups)
            }
        } catch {
            Issue.record("Wrong error type")
        }

        // Premium tier should not throw
        do {
            try premiumService.enforceFeatureAccess(.versionedCloudBackups)
            // Success
        } catch {
            Issue.record("Premium tier should not throw for versioned cloud backups")
        }
    }

    // MARK: - Error Message Tests

    @Test("Inventory limit error message includes limit")
    func testInventoryLimitErrorMessage() {
        let error = EntitlementError.inventoryLimitReached(limit: 25)
        let message = error.errorDescription ?? ""

        #expect(message.contains("25"))
        #expect(message.contains("inventory"))
    }

    @Test("Shopping list limit error message includes limit")
    func testShoppingListLimitErrorMessage() {
        let error = EntitlementError.shoppingListLimitReached(limit: 15)
        let message = error.errorDescription ?? ""

        #expect(message.contains("15"))
        #expect(message.contains("shopping"))
    }

    @Test("Feature requires pro error message includes feature name")
    func testFeatureRequiresProErrorMessage() {
        let error = EntitlementError.featureRequiresPro(feature: .versionedCloudBackups)
        let message = error.errorDescription ?? ""

        #expect(message.contains("Versioned Cloud Backups"))
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

        // Get a real catalog item (catalog is read-only, can't create test items)
        let glassItem = try await getRealCatalogItem()

        // Add inventory to the item
        _ = try await service.addInventory(
            quantity: 5.0,
            type: "rod",
            toItem: glassItem.stable_id,
            atLocation: nil
        )

        // Search for items with inventory
        let itemsWithInventory = try await service.searchItems(text: "", hasInventory: true)

        // Should have at least 1 item with inventory
        #expect(itemsWithInventory.count >= 1)

        // Verify our item is in the list
        let hasOurItem = itemsWithInventory.contains { $0.glassItem.stable_id == glassItem.stable_id }
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

    // MARK: - Premium Tier Tests

    @Test("Premium tier has all unlimited limits")
    func testPremiumTierAllUnlimited() {
        let service = createEntitlementService(tier: .premium)

        #expect(service.getInventoryLimit() == nil)
        #expect(service.getShoppingListLimit() == nil)
        #expect(service.getProjectsLimit() == nil)
        #expect(service.getLogbookEntriesLimit() == nil)
    }

    @Test("Free tier has all numeric limits set")
    func testFreeTierAllLimitsSet() {
        let service = createEntitlementService(tier: .free)

        #expect(service.getInventoryLimit() != nil)
        #expect(service.getShoppingListLimit() != nil)
        #expect(service.getProjectsLimit() != nil)
        #expect(service.getLogbookEntriesLimit() != nil)
    }

    // MARK: - Universal Features Tests

    @Test("Universal features available to all tiers via config")
    func testUniversalFeaturesViaConfig() {
        // These features are now universal (available to all tiers)
        #expect(SubscriptionConfig.UniversalFeatures.catalogAccess == true)
        #expect(SubscriptionConfig.UniversalFeatures.cloudKitSync == true)
        #expect(SubscriptionConfig.UniversalFeatures.exportData == true)
        #expect(SubscriptionConfig.UniversalFeatures.labelPrinting == true)
        #expect(SubscriptionConfig.UniversalFeatures.qrCodeScanning == true)
        #expect(SubscriptionConfig.UniversalFeatures.customInventoryTags == true)
        #expect(SubscriptionConfig.UniversalFeatures.inventoryItemImages == true)
        #expect(SubscriptionConfig.UniversalFeatures.customInventoryNotes == true)
    }
}
