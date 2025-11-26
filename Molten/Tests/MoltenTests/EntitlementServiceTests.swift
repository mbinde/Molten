import Testing
import Foundation
@testable import Molten

@Suite("EntitlementService Tests")
@MainActor
struct EntitlementServiceTests {

    // MARK: - Shopping List Limit Tests

    @Test("Free tier should have shopping list limit matching FeatureFlags")
    func testFreeTierShoppingListLimit() {
        let service = EntitlementService(tier: .free)

        let limit = service.getShoppingListLimit()

        #expect(limit == FeatureFlags.FREE_TIER_SHOPPING_LIST_LIMIT)
    }

    @Test("Premium tier should have unlimited shopping list items")
    func testPremiumTierShoppingListLimit() {
        let service = EntitlementService(tier: .premium)

        let limit = service.getShoppingListLimit()

        #expect(limit == nil) // nil means unlimited
    }

    @Test("Free tier can add shopping list item when under limit")
    func testCanAddShoppingListItemUnderLimit() {
        let service = EntitlementService(tier: .free)
        let limit = FeatureFlags.FREE_TIER_SHOPPING_LIST_LIMIT

        let canAdd = service.canAddShoppingListItem(currentCount: limit / 2)

        #expect(canAdd == true)
    }

    @Test("Free tier can add shopping list item when at limit minus one")
    func testCanAddShoppingListItemAtLimitMinusOne() {
        let service = EntitlementService(tier: .free)
        let limit = FeatureFlags.FREE_TIER_SHOPPING_LIST_LIMIT

        let canAdd = service.canAddShoppingListItem(currentCount: limit - 1)

        #expect(canAdd == true)
    }

    @Test("Free tier cannot add shopping list item when at limit")
    func testCannotAddShoppingListItemAtLimit() {
        let service = EntitlementService(tier: .free)
        let limit = FeatureFlags.FREE_TIER_SHOPPING_LIST_LIMIT

        let canAdd = service.canAddShoppingListItem(currentCount: limit)

        #expect(canAdd == false)
    }

    @Test("Free tier cannot add shopping list item when over limit")
    func testCannotAddShoppingListItemOverLimit() {
        let service = EntitlementService(tier: .free)
        let limit = FeatureFlags.FREE_TIER_SHOPPING_LIST_LIMIT

        let canAdd = service.canAddShoppingListItem(currentCount: limit + 5)

        #expect(canAdd == false)
    }

    @Test("Pro tier can add unlimited shopping list items")
    func testProTierCanAddUnlimitedShoppingListItems() {
        let service = EntitlementService(tier: .premium)

        let canAdd1 = service.canAddShoppingListItem(currentCount: 10)
        let canAdd2 = service.canAddShoppingListItem(currentCount: 100)
        let canAdd3 = service.canAddShoppingListItem(currentCount: 1000)

        #expect(canAdd1 == true)
        #expect(canAdd2 == true)
        #expect(canAdd3 == true)
    }

    @Test("Free tier enforceShoppingListLimit throws when at limit")
    func testEnforceShoppingListLimitThrowsAtLimit() {
        let service = EntitlementService(tier: .free)
        let limit = FeatureFlags.FREE_TIER_SHOPPING_LIST_LIMIT

        #expect(throws: EntitlementError.self) {
            try service.enforceShoppingListLimit(currentCount: limit)
        }
    }

    @Test("Free tier enforceShoppingListLimit succeeds when under limit")
    func testEnforceShoppingListLimitSucceedsUnderLimit() throws {
        let service = EntitlementService(tier: .free)

        try service.enforceShoppingListLimit(currentCount: 5)
        // If we get here without throwing, the test passes
    }

    @Test("Pro tier enforceShoppingListLimit never throws")
    func testProTierEnforceShoppingListLimitNeverThrows() throws {
        let service = EntitlementService(tier: .premium)

        try service.enforceShoppingListLimit(currentCount: 100)
        try service.enforceShoppingListLimit(currentCount: 1000)
        // If we get here without throwing, the test passes
    }

    @Test("Shopping list limit error message is descriptive")
    func testShoppingListLimitErrorMessage() {
        let service = EntitlementService(tier: .free)
        let limit = FeatureFlags.FREE_TIER_SHOPPING_LIST_LIMIT

        do {
            try service.enforceShoppingListLimit(currentCount: limit)
            Issue.record("Expected error to be thrown")
        } catch let error as EntitlementError {
            let message = error.errorDescription ?? ""
            #expect(message.contains("\(limit)"))
            #expect(message.contains("shopping list"))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Inventory Limit Tests

    @Test("Free tier should have 25 item inventory limit")
    func testFreeTierInventoryLimit() {
        let service = EntitlementService(tier: .free)

        let limit = service.getInventoryLimit()

        #expect(limit == 25)
    }

    @Test("Pro tier should have unlimited inventory items")
    func testProTierInventoryLimit() {
        let service = EntitlementService(tier: .premium)

        let limit = service.getInventoryLimit()

        #expect(limit == nil) // nil means unlimited
    }

    @Test("Free tier can add inventory item when under limit")
    func testCanAddInventoryItemUnderLimit() {
        let service = EntitlementService(tier: .free)

        let canAdd = service.canAddInventoryItem(currentCount: 12)

        #expect(canAdd == true)
    }

    @Test("Free tier cannot add inventory item when at limit")
    func testCannotAddInventoryItemAtLimit() {
        let service = EntitlementService(tier: .free)

        let canAdd = service.canAddInventoryItem(currentCount: 25)

        #expect(canAdd == false)
    }

    @Test("Pro tier can add unlimited inventory items")
    func testProTierCanAddUnlimitedInventoryItems() {
        let service = EntitlementService(tier: .premium)

        let canAdd = service.canAddInventoryItem(currentCount: 1000)

        #expect(canAdd == true)
    }

    // MARK: - Projects Limit Tests

    @Test("Free tier should have 5 projects limit")
    func testFreeTierProjectsLimit() {
        let service = EntitlementService(tier: .free)

        let limit = service.getProjectsLimit()

        #expect(limit == 5)
    }

    @Test("Pro tier should have unlimited projects")
    func testProTierProjectsLimit() {
        let service = EntitlementService(tier: .premium)

        let limit = service.getProjectsLimit()

        #expect(limit == nil)
    }

    // MARK: - Logbook Entries Limit Tests

    @Test("Free tier should have 10 logbook entries limit")
    func testFreeTierLogbookEntriesLimit() {
        let service = EntitlementService(tier: .free)

        let limit = service.getLogbookEntriesLimit()

        #expect(limit == 10)
    }

    @Test("Pro tier should have unlimited logbook entries")
    func testProTierLogbookEntriesLimit() {
        let service = EntitlementService(tier: .premium)

        let limit = service.getLogbookEntriesLimit()

        #expect(limit == nil)
    }

    // MARK: - Tier Management Tests

    @Test("EntitlementService initializes with specified tier")
    func testInitializesWithTier() {
        let freeService = EntitlementService(tier: .free)
        let proService = EntitlementService(tier: .premium)

        #expect(freeService.tier == .free)
        #expect(proService.tier == .premium)
    }

    @Test("EntitlementService defaults to free tier")
    func testDefaultsToFreeTier() {
        let service = EntitlementService()

        #expect(service.tier == .free)
    }

    @Test("EntitlementService can update tier")
    func testCanUpdateTier() {
        let service = EntitlementService(tier: .free)

        #expect(service.tier == .free)

        service.updateTier(.premium)

        #expect(service.tier == .premium)
    }

    @Test("Updating tier affects shopping list limits")
    func testUpdatingTierAffectsShoppingListLimits() {
        let service = EntitlementService(tier: .free)
        let freeLimit = FeatureFlags.FREE_TIER_SHOPPING_LIST_LIMIT

        // Initially free tier - has limit
        var limit = service.getShoppingListLimit()
        #expect(limit == freeLimit)

        // Cannot add when at limit
        var canAdd = service.canAddShoppingListItem(currentCount: freeLimit)
        #expect(canAdd == false)

        // Upgrade to Pro
        service.updateTier(.premium)

        // Now unlimited
        limit = service.getShoppingListLimit()
        #expect(limit == nil)

        // Can add even when over old limit
        canAdd = service.canAddShoppingListItem(currentCount: 100)
        #expect(canAdd == true)
    }

    @Test("Updating tier affects inventory limits")
    func testUpdatingTierAffectsInventoryLimits() {
        let service = EntitlementService(tier: .free)

        // Initially free tier - has limit
        var limit = service.getInventoryLimit()
        #expect(limit == 25)

        // Cannot add when at limit
        var canAdd = service.canAddInventoryItem(currentCount: 25)
        #expect(canAdd == false)

        // Upgrade to Pro
        service.updateTier(.premium)

        // Now unlimited
        limit = service.getInventoryLimit()
        #expect(limit == nil)

        // Can add even when over old limit
        canAdd = service.canAddInventoryItem(currentCount: 100)
        #expect(canAdd == true)
    }

    // MARK: - Versioned Cloud Backups Tests

    @Test("Free tier cannot use versioned cloud backups")
    func testFreeTierCannotUseVersionedCloudBackups() {
        let service = EntitlementService(tier: .free)

        #expect(service.canUseVersionedCloudBackups() == false)
    }

    @Test("Pro tier can use versioned cloud backups")
    func testProTierCanUseVersionedCloudBackups() {
        let service = EntitlementService(tier: .premium)

        #expect(service.canUseVersionedCloudBackups() == true)
    }

    @Test("Feature enforcement throws for free tier on versioned cloud backups")
    func testFeatureEnforcementThrowsForFreeTier() {
        let service = EntitlementService(tier: .free)

        #expect(throws: EntitlementError.self) {
            try service.enforceFeatureAccess(.versionedCloudBackups)
        }
    }

    @Test("Feature enforcement succeeds for pro tier on versioned cloud backups")
    func testFeatureEnforcementSucceedsForProTier() throws {
        let service = EntitlementService(tier: .premium)

        try service.enforceFeatureAccess(.versionedCloudBackups)
    }
}
