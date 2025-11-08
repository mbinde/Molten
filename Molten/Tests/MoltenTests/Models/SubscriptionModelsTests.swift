import Testing
import Foundation
@testable import Molten

@Suite("Subscription Domain Models")
struct SubscriptionModelsTests {

    // MARK: - SubscriptionInfo Tests

    @Test("SubscriptionInfo should identify active subscription")
    func testActiveSubscription() {
        let status = SubscriptionInfo(
            isActive: true,
            productIdentifier: "monthly",
            expirationDate: Date().addingTimeInterval(86400 * 30),
            willRenew: true
        )

        #expect(status.isActive == true)
        #expect(status.productIdentifier == "monthly")
        #expect(status.willRenew == true)
    }

    @Test("SubscriptionInfo should identify expired subscription")
    func testExpiredSubscription() {
        let status = SubscriptionInfo(
            isActive: false,
            productIdentifier: nil,
            expirationDate: Date().addingTimeInterval(-86400),
            willRenew: false
        )

        #expect(status.isActive == false)
        #expect(status.productIdentifier == nil)
    }

    @Test("SubscriptionInfo should identify lifetime purchase")
    func testLifetimePurchase() {
        let status = SubscriptionInfo(
            isActive: true,
            productIdentifier: "lifetime",
            expirationDate: nil, // Lifetime has no expiration
            willRenew: false
        )

        #expect(status.isActive == true)
        #expect(status.expirationDate == nil)
        #expect(status.willRenew == false)
    }

    @Test("SubscriptionInfo should show correct display status for inactive")
    func testDisplayStatusInactive() {
        let status = SubscriptionInfo(
            isActive: false,
            productIdentifier: nil,
            expirationDate: nil,
            willRenew: false
        )

        #expect(status.displayStatus == "No Active Subscription")
    }

    @Test("SubscriptionInfo should show correct display status for lifetime")
    func testDisplayStatusLifetime() {
        let status = SubscriptionInfo(
            isActive: true,
            productIdentifier: "lifetime",
            expirationDate: nil,
            willRenew: false
        )

        #expect(status.displayStatus == "Lifetime Access")
    }

    @Test("SubscriptionInfo should show correct display status for renewing subscription")
    func testDisplayStatusRenewing() {
        let futureDate = Date().addingTimeInterval(86400 * 30)
        let status = SubscriptionInfo(
            isActive: true,
            productIdentifier: "monthly",
            expirationDate: futureDate,
            willRenew: true
        )

        #expect(status.displayStatus.contains("Active (Renews"))
    }

    @Test("SubscriptionInfo should show correct display status for expiring subscription")
    func testDisplayStatusExpiring() {
        let futureDate = Date().addingTimeInterval(86400 * 7)
        let status = SubscriptionInfo(
            isActive: true,
            productIdentifier: "monthly",
            expirationDate: futureDate,
            willRenew: false
        )

        #expect(status.displayStatus.contains("Active (Expires"))
    }

    // MARK: - EntitlementInfo Tests

    @Test("EntitlementInfo should track Pro entitlement")
    func testProEntitlement() {
        let entitlement = EntitlementInfo(
            identifier: "molten_glass_pro",
            isActive: true
        )

        #expect(entitlement.identifier == "molten_glass_pro")
        #expect(entitlement.isActive == true)
    }

    @Test("EntitlementInfo should handle inactive entitlement")
    func testInactiveEntitlement() {
        let entitlement = EntitlementInfo(
            identifier: "molten_glass_pro",
            isActive: false
        )

        #expect(entitlement.isActive == false)
    }

    // MARK: - SubscriptionError Tests

    @Test("SubscriptionError should provide proper error descriptions")
    func testErrorDescriptions() {
        let configError = SubscriptionError.configurationError
        #expect(configError.errorDescription?.contains("not configured") == true)

        let cancelledError = SubscriptionError.purchaseCancelled
        #expect(cancelledError.errorDescription?.contains("cancelled") == true)

        let networkError = SubscriptionError.networkError
        #expect(networkError.errorDescription?.contains("Network") == true)
    }
}
