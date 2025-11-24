import Testing
import Foundation
@testable import Molten

@Suite("EntitlementService Tests")
@MainActor
struct EntitlementServiceTests {

    // MARK: - Shopping List Limit Tests

    @Test("Free tier should have 10 item shopping list limit")
    func testFreeTierShoppingListLimit() {
        let service = EntitlementService(tier: .free)

        let limit = service.getShoppingListLimit()

        #expect(limit == 10)
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

        let canAdd = service.canAddShoppingListItem(currentCount: 5)

        #expect(canAdd == true)
    }

    @Test("Free tier can add shopping list item when at limit minus one")
    func testCanAddShoppingListItemAtLimitMinusOne() {
        let service = EntitlementService(tier: .free)

        let canAdd = service.canAddShoppingListItem(currentCount: 9)

        #expect(canAdd == true)
    }

    @Test("Free tier cannot add shopping list item when at limit")
    func testCannotAddShoppingListItemAtLimit() {
        let service = EntitlementService(tier: .free)

        let canAdd = service.canAddShoppingListItem(currentCount: 10)

        #expect(canAdd == false)
    }

    @Test("Free tier cannot add shopping list item when over limit")
    func testCannotAddShoppingListItemOverLimit() {
        let service = EntitlementService(tier: .free)

        let canAdd = service.canAddShoppingListItem(currentCount: 15)

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

        #expect(throws: EntitlementError.self) {
            try service.enforceShoppingListLimit(currentCount: 10)
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

        do {
            try service.enforceShoppingListLimit(currentCount: 10)
            Issue.record("Expected error to be thrown")
        } catch let error as EntitlementError {
            let message = error.errorDescription ?? ""
            #expect(message.contains("10"))
            #expect(message.contains("shopping list"))
            #expect(message.contains("premium"))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Inventory Limit Tests

    @Test("Free tier should have 50 item inventory limit")
    func testFreeTierInventoryLimit() {
        let service = EntitlementService(tier: .free)

        let limit = service.getInventoryLimit()

        #expect(limit == 50)
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

        let canAdd = service.canAddInventoryItem(currentCount: 25)

        #expect(canAdd == true)
    }

    @Test("Free tier cannot add inventory item when at limit")
    func testCannotAddInventoryItemAtLimit() {
        let service = EntitlementService(tier: .free)

        let canAdd = service.canAddInventoryItem(currentCount: 50)

        #expect(canAdd == false)
    }

    @Test("Pro tier can add unlimited inventory items")
    func testProTierCanAddUnlimitedInventoryItems() {
        let service = EntitlementService(tier: .premium)

        let canAdd = service.canAddInventoryItem(currentCount: 1000)

        #expect(canAdd == true)
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

        // Initially free tier - has limit
        var limit = service.getShoppingListLimit()
        #expect(limit == 10)

        // Cannot add when at limit
        var canAdd = service.canAddShoppingListItem(currentCount: 10)
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
        #expect(limit == 50)

        // Cannot add when at limit
        var canAdd = service.canAddInventoryItem(currentCount: 50)
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

    // MARK: - Feature Access Tests

    @Test("Free tier has limited features")
    func testFreeTierFeatureAccess() {
        let service = EntitlementService(tier: .free)

        #expect(service.canUseBatchLabelPrinting() == false)
        #expect(service.canUseCSVImport() == false)
        #expect(service.canUseBulkEditing() == false)
        #expect(service.canUseCustomFields() == false)
    }

    @Test("Pro tier has all features")
    func testProTierFeatureAccess() {
        let service = EntitlementService(tier: .premium)

        #expect(service.canUseBatchLabelPrinting() == true)
        #expect(service.canUseCSVImport() == true)
        #expect(service.canUseBulkEditing() == true)
        #expect(service.canUseCustomFields() == true)
    }

    @Test("Feature enforcement throws for free tier")
    func testFeatureEnforcementThrowsForFreeTier() {
        let service = EntitlementService(tier: .free)

        #expect(throws: EntitlementError.self) {
            try service.enforceFeatureAccess(.batchLabelPrinting)
        }

        #expect(throws: EntitlementError.self) {
            try service.enforceFeatureAccess(.csvImport)
        }
    }

    @Test("Feature enforcement succeeds for pro tier")
    func testFeatureEnforcementSucceedsForProTier() throws {
        let service = EntitlementService(tier: .premium)

        try service.enforceFeatureAccess(.batchLabelPrinting)
        try service.enforceFeatureAccess(.csvImport)
        try service.enforceFeatureAccess(.bulkEditing)
        try service.enforceFeatureAccess(.customFields)
    }
}
