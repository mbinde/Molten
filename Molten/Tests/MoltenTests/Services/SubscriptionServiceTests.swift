import Testing
import Foundation
@testable import Molten

@Suite("SubscriptionService Tests")
@MainActor
struct SubscriptionServiceTests {

    // MARK: - Mock Service Tests

    @Test("MockSubscriptionService should initialize with free user")
    func testMockServiceFreeUser() async {
        let deps = AppDependencies(persistenceController: .createTestController())
        let service = MockSubscriptionService(hasProAccess: false)

        let hasAccess = await service.hasProAccess()
        let status = await service.getSubscriptionStatus()

        #expect(hasAccess == false)
        #expect(status.isActive == false)
        #expect(status.productIdentifier == nil)
    }

    @Test("MockSubscriptionService should initialize with Pro user")
    func testMockServiceProUser() async {
        let deps = AppDependencies(persistenceController: .createTestController())
        let service = MockSubscriptionService(hasProAccess: true)

        let hasAccess = await service.hasProAccess()
        let status = await service.getSubscriptionStatus()

        #expect(hasAccess == true)
        #expect(status.isActive == true)
        #expect(status.productIdentifier == "monthly")
    }

    @Test("MockSubscriptionService should provide customer info")
    func testMockServiceCustomerInfo() async throws {
        let deps = AppDependencies(persistenceController: .createTestController())
        let service = MockSubscriptionService(hasProAccess: true)

        let customerInfo = try await service.getCustomerInfo()

        #expect(customerInfo.originalAppUserId == "test-user-123")
        #expect(customerInfo.subscriptionStatus.isActive == true)
        #expect(customerInfo.activeEntitlements.count > 0)
    }

    @Test("MockSubscriptionService should check entitlements correctly")
    func testMockServiceCheckEntitlement() async {
        let deps = AppDependencies(persistenceController: .createTestController())
        let service = MockSubscriptionService(hasProAccess: true)

        let hasProEntitlement = await service.checkEntitlement("molten_glass_pro")
        let hasOtherEntitlement = await service.checkEntitlement("other_entitlement")

        #expect(hasProEntitlement == true)
        #expect(hasOtherEntitlement == false)
    }

    @Test("MockSubscriptionService should handle restore purchases")
    func testMockServiceRestorePurchases() async throws {
        let deps = AppDependencies(persistenceController: .createTestController())
        let service = MockSubscriptionService(hasProAccess: false)

        let customerInfo = try await service.restorePurchases()

        #expect(customerInfo.originalAppUserId == "test-user-123")
    }

    @Test("MockSubscriptionService should simulate Pro purchase")
    func testMockServiceSimulatePurchase() async {
        let deps = AppDependencies(persistenceController: .createTestController())
        let service = MockSubscriptionService(hasProAccess: false)

        // Initially free
        var hasAccess = await service.hasProAccess()
        #expect(hasAccess == false)

        // Simulate purchase
        service.simulateProPurchase()

        // Now Pro
        hasAccess = await service.hasProAccess()
        let status = await service.getSubscriptionStatus()

        #expect(hasAccess == true)
        #expect(status.isActive == true)
    }

    @Test("MockSubscriptionService should simulate subscription expiration")
    func testMockServiceSimulateExpiration() async {
        let deps = AppDependencies(persistenceController: .createTestController())
        let service = MockSubscriptionService(hasProAccess: true)

        // Initially Pro
        var hasAccess = await service.hasProAccess()
        #expect(hasAccess == true)

        // Simulate expiration
        service.simulateSubscriptionExpiration()

        // Now expired
        hasAccess = await service.hasProAccess()
        let status = await service.getSubscriptionStatus()

        #expect(hasAccess == false)
        #expect(status.isActive == false)
    }

    @Test("MockSubscriptionService should support custom subscription status")
    func testMockServiceCustomStatus() async {
        let deps = AppDependencies(persistenceController: .createTestController())
        let customStatus = SubscriptionInfo(
            isActive: true,
            productIdentifier: "lifetime",
            expirationDate: nil,
            willRenew: false
        )

        let service = MockSubscriptionService(
            hasProAccess: true,
            subscriptionStatus: customStatus
        )

        let status = await service.getSubscriptionStatus()

        #expect(status.productIdentifier == "lifetime")
        #expect(status.expirationDate == nil)
        #expect(status.willRenew == false)
    }

    // MARK: - CustomerInfo Tests

    @Test("CustomerInfo should contain subscription status and entitlements")
    func testCustomerInfoStructure() {
        let deps = AppDependencies(persistenceController: .createTestController())
        let status = SubscriptionInfo(
            isActive: true,
            productIdentifier: "monthly",
            expirationDate: Date().addingTimeInterval(86400 * 30),
            willRenew: true
        )

        let entitlements = [
            EntitlementInfo(identifier: "molten_glass_pro", isActive: true)
        ]

        let customerInfo = CustomerInfo(
            originalAppUserId: "user-456",
            subscriptionStatus: status,
            activeEntitlements: entitlements
        )

        #expect(customerInfo.originalAppUserId == "user-456")
        #expect(customerInfo.subscriptionStatus.isActive == true)
        #expect(customerInfo.activeEntitlements.count == 1)
        #expect(customerInfo.activeEntitlements[0].identifier == "molten_glass_pro")
    }
}
