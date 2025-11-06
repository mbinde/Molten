//
//  SubscriptionConfigTests.swift
//  MoltenTests
//
//  Unit tests for SubscriptionConfig and SubscriptionTier
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

@Suite("SubscriptionConfig Tests")
struct SubscriptionConfigTests {

    // MARK: - SubscriptionTier Tests

    @Test("SubscriptionTier has all expected cases")
    func testSubscriptionTierAllCases() {
        let allCases = SubscriptionTier.allCases

        #expect(allCases.count == 2)
        #expect(allCases.contains(.free))
        #expect(allCases.contains(.premium))
    }

    @Test("SubscriptionTier cases are in expected order")
    func testSubscriptionTierOrder() {
        let allCases = SubscriptionTier.allCases

        #expect(allCases[0] == .free)
        #expect(allCases[1] == .premium)
    }

    @Test("SubscriptionTier equality works correctly")
    func testSubscriptionTierEquality() {
        #expect(SubscriptionTier.free == SubscriptionTier.free)
        #expect(SubscriptionTier.premium == SubscriptionTier.premium)
        #expect(SubscriptionTier.free != SubscriptionTier.premium)
    }

    // MARK: - FreeTierLimits Tests

    @Test("FreeTierLimits.maxInventoryItems has correct value")
    func testMaxInventoryItems() {
        #expect(SubscriptionConfig.FreeTierLimits.maxInventoryItems == 50)
    }

    @Test("FreeTierLimits.maxShoppingListItems has correct value")
    func testMaxShoppingListItems() {
        #expect(SubscriptionConfig.FreeTierLimits.maxShoppingListItems == 20)
    }

    @Test("FreeTierLimits.maxProjects has correct value")
    func testMaxProjects() {
        #expect(SubscriptionConfig.FreeTierLimits.maxProjects == 5)
    }

    @Test("FreeTierLimits.maxPhotosPerItem has correct value")
    func testMaxPhotosPerItem() {
        #expect(SubscriptionConfig.FreeTierLimits.maxPhotosPerItem == 1)
    }

    @Test("FreeTierLimits.maxCustomTags has correct value")
    func testMaxCustomTags() {
        #expect(SubscriptionConfig.FreeTierLimits.maxCustomTags == 10)
    }

    @Test("FreeTierLimits are all positive values")
    func testFreeTierLimitsPositive() {
        #expect(SubscriptionConfig.FreeTierLimits.maxInventoryItems > 0)
        #expect(SubscriptionConfig.FreeTierLimits.maxShoppingListItems > 0)
        #expect(SubscriptionConfig.FreeTierLimits.maxProjects > 0)
        #expect(SubscriptionConfig.FreeTierLimits.maxPhotosPerItem > 0)
        #expect(SubscriptionConfig.FreeTierLimits.maxCustomTags > 0)
    }

    // MARK: - PremiumFeatures Tests

    @Test("PremiumFeatures.allowsBatchLabelPrinting is true")
    func testAllowsBatchLabelPrinting() {
        #expect(SubscriptionConfig.PremiumFeatures.allowsBatchLabelPrinting == true)
    }

    @Test("PremiumFeatures.allowsAdvancedReports is true")
    func testAllowsAdvancedReports() {
        #expect(SubscriptionConfig.PremiumFeatures.allowsAdvancedReports == true)
    }

    @Test("PremiumFeatures.allowsCloudSync is true")
    func testAllowsCloudSync() {
        #expect(SubscriptionConfig.PremiumFeatures.allowsCloudSync == true)
    }

    @Test("PremiumFeatures.allowsDataExport is true")
    func testAllowsDataExport() {
        #expect(SubscriptionConfig.PremiumFeatures.allowsDataExport == true)
    }

    @Test("PremiumFeatures.allowsPrioritySupport is true")
    func testAllowsPrioritySupport() {
        #expect(SubscriptionConfig.PremiumFeatures.allowsPrioritySupport == true)
    }

    // MARK: - UniversalFeatures Tests

    @Test("UniversalFeatures.allowsBasicInventory is true")
    func testAllowsBasicInventory() {
        #expect(SubscriptionConfig.UniversalFeatures.allowsBasicInventory == true)
    }

    @Test("UniversalFeatures.allowsShoppingList is true")
    func testAllowsShoppingList() {
        #expect(SubscriptionConfig.UniversalFeatures.allowsShoppingList == true)
    }

    @Test("UniversalFeatures.allowsManualDataEntry is true")
    func testAllowsManualDataEntry() {
        #expect(SubscriptionConfig.UniversalFeatures.allowsManualDataEntry == true)
    }

    @Test("UniversalFeatures.allowsLocalStorage is true")
    func testAllowsLocalStorage() {
        #expect(SubscriptionConfig.UniversalFeatures.allowsLocalStorage == true)
    }

    // MARK: - Inventory Limit Tests

    @Test("inventoryLimit for free tier returns FreeTierLimits value")
    func testInventoryLimitForFree() {
        let limit = SubscriptionConfig.inventoryLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxInventoryItems)
        #expect(limit == 50)
    }

    @Test("inventoryLimit for premium tier returns nil (unlimited)")
    func testInventoryLimitForPremium() {
        let limit = SubscriptionConfig.inventoryLimit(for: .premium)
        #expect(limit == nil)
    }

    // MARK: - Shopping List Limit Tests

    @Test("shoppingListLimit for free tier returns FreeTierLimits value")
    func testShoppingListLimitForFree() {
        let limit = SubscriptionConfig.shoppingListLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxShoppingListItems)
        #expect(limit == 20)
    }

    @Test("shoppingListLimit for premium tier returns nil (unlimited)")
    func testShoppingListLimitForPremium() {
        let limit = SubscriptionConfig.shoppingListLimit(for: .premium)
        #expect(limit == nil)
    }

    // MARK: - Projects Limit Tests

    @Test("projectsLimit for free tier returns FreeTierLimits value")
    func testProjectsLimitForFree() {
        let limit = SubscriptionConfig.projectsLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxProjects)
        #expect(limit == 5)
    }

    @Test("projectsLimit for premium tier returns nil (unlimited)")
    func testProjectsLimitForPremium() {
        let limit = SubscriptionConfig.projectsLimit(for: .premium)
        #expect(limit == nil)
    }

    // MARK: - Photos Per Item Limit Tests

    @Test("photosPerItemLimit for free tier returns FreeTierLimits value")
    func testPhotosPerItemLimitForFree() {
        let limit = SubscriptionConfig.photosPerItemLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxPhotosPerItem)
        #expect(limit == 1)
    }

    @Test("photosPerItemLimit for premium tier returns nil (unlimited)")
    func testPhotosPerItemLimitForPremium() {
        let limit = SubscriptionConfig.photosPerItemLimit(for: .premium)
        #expect(limit == nil)
    }

    // MARK: - Custom Tags Limit Tests

    @Test("customTagsLimit for free tier returns FreeTierLimits value")
    func testCustomTagsLimitForFree() {
        let limit = SubscriptionConfig.customTagsLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxCustomTags)
        #expect(limit == 10)
    }

    @Test("customTagsLimit for premium tier returns nil (unlimited)")
    func testCustomTagsLimitForPremium() {
        let limit = SubscriptionConfig.customTagsLimit(for: .premium)
        #expect(limit == nil)
    }

    // MARK: - Batch Label Printing Tests

    @Test("allowsBatchLabelPrinting for free tier returns false")
    func testAllowsBatchLabelPrintingForFree() {
        let allowed = SubscriptionConfig.allowsBatchLabelPrinting(for: .free)
        #expect(allowed == false)
    }

    @Test("allowsBatchLabelPrinting for premium tier returns true")
    func testAllowsBatchLabelPrintingForPremium() {
        let allowed = SubscriptionConfig.allowsBatchLabelPrinting(for: .premium)
        #expect(allowed == true)
    }

    // MARK: - Advanced Reports Tests

    @Test("allowsAdvancedReports for free tier returns false")
    func testAllowsAdvancedReportsForFree() {
        let allowed = SubscriptionConfig.allowsAdvancedReports(for: .free)
        #expect(allowed == false)
    }

    @Test("allowsAdvancedReports for premium tier returns true")
    func testAllowsAdvancedReportsForPremium() {
        let allowed = SubscriptionConfig.allowsAdvancedReports(for: .premium)
        #expect(allowed == true)
    }

    // MARK: - Cloud Sync Tests

    @Test("allowsCloudSync for free tier returns false")
    func testAllowsCloudSyncForFree() {
        let allowed = SubscriptionConfig.allowsCloudSync(for: .free)
        #expect(allowed == false)
    }

    @Test("allowsCloudSync for premium tier returns true")
    func testAllowsCloudSyncForPremium() {
        let allowed = SubscriptionConfig.allowsCloudSync(for: .premium)
        #expect(allowed == true)
    }

    // MARK: - Data Export Tests

    @Test("allowsDataExport for free tier returns false")
    func testAllowsDataExportForFree() {
        let allowed = SubscriptionConfig.allowsDataExport(for: .free)
        #expect(allowed == false)
    }

    @Test("allowsDataExport for premium tier returns true")
    func testAllowsDataExportForPremium() {
        let allowed = SubscriptionConfig.allowsDataExport(for: .premium)
        #expect(allowed == true)
    }

    // MARK: - Priority Support Tests

    @Test("allowsPrioritySupport for free tier returns false")
    func testAllowsPrioritySupportForFree() {
        let allowed = SubscriptionConfig.allowsPrioritySupport(for: .free)
        #expect(allowed == false)
    }

    @Test("allowsPrioritySupport for premium tier returns true")
    func testAllowsPrioritySupportForPremium() {
        let allowed = SubscriptionConfig.allowsPrioritySupport(for: .premium)
        #expect(allowed == true)
    }

    // MARK: - Universal Features Tests (Available to All Tiers)

    @Test("Basic inventory available to all tiers")
    func testBasicInventoryUniversal() {
        // Not exposed as a method, but UniversalFeatures.allowsBasicInventory is true
        #expect(SubscriptionConfig.UniversalFeatures.allowsBasicInventory == true)
    }

    @Test("Shopping list available to all tiers")
    func testShoppingListUniversal() {
        #expect(SubscriptionConfig.UniversalFeatures.allowsShoppingList == true)
    }

    @Test("Manual data entry available to all tiers")
    func testManualDataEntryUniversal() {
        #expect(SubscriptionConfig.UniversalFeatures.allowsManualDataEntry == true)
    }

    @Test("Local storage available to all tiers")
    func testLocalStorageUniversal() {
        #expect(SubscriptionConfig.UniversalFeatures.allowsLocalStorage == true)
    }

    // MARK: - Comprehensive Tier Comparison Tests

    @Test("Free tier has all limits set")
    func testFreeTierHasLimits() {
        #expect(SubscriptionConfig.inventoryLimit(for: .free) != nil)
        #expect(SubscriptionConfig.shoppingListLimit(for: .free) != nil)
        #expect(SubscriptionConfig.projectsLimit(for: .free) != nil)
        #expect(SubscriptionConfig.photosPerItemLimit(for: .free) != nil)
        #expect(SubscriptionConfig.customTagsLimit(for: .free) != nil)
    }

    @Test("Premium tier has no limits (all nil)")
    func testPremiumTierHasNoLimits() {
        #expect(SubscriptionConfig.inventoryLimit(for: .premium) == nil)
        #expect(SubscriptionConfig.shoppingListLimit(for: .premium) == nil)
        #expect(SubscriptionConfig.projectsLimit(for: .premium) == nil)
        #expect(SubscriptionConfig.photosPerItemLimit(for: .premium) == nil)
        #expect(SubscriptionConfig.customTagsLimit(for: .premium) == nil)
    }

    @Test("Free tier has no premium features")
    func testFreeTierNoPremiumFeatures() {
        #expect(SubscriptionConfig.allowsBatchLabelPrinting(for: .free) == false)
        #expect(SubscriptionConfig.allowsAdvancedReports(for: .free) == false)
        #expect(SubscriptionConfig.allowsCloudSync(for: .free) == false)
        #expect(SubscriptionConfig.allowsDataExport(for: .free) == false)
        #expect(SubscriptionConfig.allowsPrioritySupport(for: .free) == false)
    }

    @Test("Premium tier has all premium features")
    func testPremiumTierAllFeatures() {
        #expect(SubscriptionConfig.allowsBatchLabelPrinting(for: .premium) == true)
        #expect(SubscriptionConfig.allowsAdvancedReports(for: .premium) == true)
        #expect(SubscriptionConfig.allowsCloudSync(for: .premium) == true)
        #expect(SubscriptionConfig.allowsDataExport(for: .premium) == true)
        #expect(SubscriptionConfig.allowsPrioritySupport(for: .premium) == true)
    }

    // MARK: - Real-World Usage Tests

    @Test("Free user can add items up to limit")
    func testFreeUserInventoryCheck() {
        let limit = SubscriptionConfig.inventoryLimit(for: .free)!
        let currentItems = 45

        #expect(currentItems < limit)  // Can add more
        #expect(limit == 50)
    }

    @Test("Free user at limit cannot add more")
    func testFreeUserAtLimit() {
        let limit = SubscriptionConfig.inventoryLimit(for: .free)!
        let currentItems = 50

        #expect(currentItems >= limit)  // At limit
    }

    @Test("Premium user has unlimited inventory")
    func testPremiumUserUnlimited() {
        let limit = SubscriptionConfig.inventoryLimit(for: .premium)
        let currentItems = 10000

        #expect(limit == nil)  // Unlimited
        // In real code: if limit == nil || currentItems < limit { /* allow */ }
    }

    @Test("Free user can create limited projects")
    func testFreeUserProjectsLimit() {
        let limit = SubscriptionConfig.projectsLimit(for: .free)!
        let currentProjects = 3

        #expect(currentProjects < limit)
        #expect(limit == 5)
    }

    @Test("Premium user export flow")
    func testPremiumUserCanExport() {
        let tier = SubscriptionTier.premium

        #expect(SubscriptionConfig.allowsDataExport(for: tier) == true)
    }

    @Test("Free user export blocked")
    func testFreeUserCannotExport() {
        let tier = SubscriptionTier.free

        #expect(SubscriptionConfig.allowsDataExport(for: tier) == false)
    }

    // MARK: - Edge Cases

    @Test("All limit values are reasonable")
    func testLimitValuesReasonable() {
        // Free tier limits should be reasonable for basic use
        #expect(SubscriptionConfig.FreeTierLimits.maxInventoryItems >= 10)
        #expect(SubscriptionConfig.FreeTierLimits.maxShoppingListItems >= 5)
        #expect(SubscriptionConfig.FreeTierLimits.maxProjects >= 1)
        #expect(SubscriptionConfig.FreeTierLimits.maxPhotosPerItem >= 1)
        #expect(SubscriptionConfig.FreeTierLimits.maxCustomTags >= 5)
    }

    @Test("Limits are not excessive")
    func testLimitsNotExcessive() {
        // Free tier shouldn't be unlimited (that's premium)
        #expect(SubscriptionConfig.FreeTierLimits.maxInventoryItems < 10000)
        #expect(SubscriptionConfig.FreeTierLimits.maxShoppingListItems < 1000)
        #expect(SubscriptionConfig.FreeTierLimits.maxProjects < 100)
        #expect(SubscriptionConfig.FreeTierLimits.maxPhotosPerItem < 100)
        #expect(SubscriptionConfig.FreeTierLimits.maxCustomTags < 1000)
    }

    @Test("Premium features are consistent")
    func testPremiumFeaturesConsistent() {
        // All premium feature flags should be true
        let features = [
            SubscriptionConfig.PremiumFeatures.allowsBatchLabelPrinting,
            SubscriptionConfig.PremiumFeatures.allowsAdvancedReports,
            SubscriptionConfig.PremiumFeatures.allowsCloudSync,
            SubscriptionConfig.PremiumFeatures.allowsDataExport,
            SubscriptionConfig.PremiumFeatures.allowsPrioritySupport
        ]

        #expect(features.allSatisfy { $0 == true })
    }

    @Test("Universal features are consistent")
    func testUniversalFeaturesConsistent() {
        // All universal features should be true (available to everyone)
        let features = [
            SubscriptionConfig.UniversalFeatures.allowsBasicInventory,
            SubscriptionConfig.UniversalFeatures.allowsShoppingList,
            SubscriptionConfig.UniversalFeatures.allowsManualDataEntry,
            SubscriptionConfig.UniversalFeatures.allowsLocalStorage
        ]

        #expect(features.allSatisfy { $0 == true })
    }
}
