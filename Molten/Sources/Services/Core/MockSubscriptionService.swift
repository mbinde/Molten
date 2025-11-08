import Foundation

/// Mock implementation for testing
@MainActor
public final class MockSubscriptionService: SubscriptionServiceProtocol, Sendable {

    private var _hasProAccess: Bool
    private var _subscriptionStatus: SubscriptionStatus
    private var _customerInfo: CustomerInfo

    public init(
        hasProAccess: Bool = false,
        subscriptionStatus: SubscriptionStatus? = nil,
        customerInfo: CustomerInfo? = nil
    ) {
        self._hasProAccess = hasProAccess

        self._subscriptionStatus = subscriptionStatus ?? SubscriptionStatus(
            isActive: hasProAccess,
            productIdentifier: hasProAccess ? "monthly" : nil,
            expirationDate: hasProAccess ? Date().addingTimeInterval(86400 * 30) : nil,
            willRenew: hasProAccess
        )

        self._customerInfo = customerInfo ?? CustomerInfo(
            originalAppUserId: "test-user-123",
            subscriptionStatus: self._subscriptionStatus,
            activeEntitlements: hasProAccess ? [
                EntitlementInfo(identifier: "molten_glass_pro", isActive: true)
            ] : []
        )
    }

    public func hasProAccess() async -> Bool {
        return _hasProAccess
    }

    public func getSubscriptionStatus() async -> SubscriptionStatus {
        return _subscriptionStatus
    }

    public func getCustomerInfo() async throws -> CustomerInfo {
        return _customerInfo
    }

    public func presentPaywall() async throws {
        // Mock - no actual presentation in tests
        print("Mock: Presenting paywall")
    }

    public func presentCustomerCenter() async throws {
        // Mock - no actual presentation in tests
        print("Mock: Presenting customer center")
    }

    public func restorePurchases() async throws -> CustomerInfo {
        return _customerInfo
    }

    public func checkEntitlement(_ identifier: String) async -> Bool {
        return _customerInfo.activeEntitlements.contains { $0.identifier == identifier && $0.isActive }
    }

    // MARK: - Test Helpers

    /// Simulate a Pro purchase (useful for testing upgrade flows)
    public func simulateProPurchase() {
        _hasProAccess = true
        _subscriptionStatus = SubscriptionStatus(
            isActive: true,
            productIdentifier: "monthly",
            expirationDate: Date().addingTimeInterval(86400 * 30),
            willRenew: true
        )
        _customerInfo = CustomerInfo(
            originalAppUserId: _customerInfo.originalAppUserId,
            subscriptionStatus: _subscriptionStatus,
            activeEntitlements: [
                EntitlementInfo(identifier: "molten_glass_pro", isActive: true)
            ]
        )
    }

    /// Simulate subscription expiration (useful for testing expiration flows)
    public func simulateSubscriptionExpiration() {
        _hasProAccess = false
        _subscriptionStatus = SubscriptionStatus(
            isActive: false,
            productIdentifier: nil,
            expirationDate: Date().addingTimeInterval(-86400),
            willRenew: false
        )
        _customerInfo = CustomerInfo(
            originalAppUserId: _customerInfo.originalAppUserId,
            subscriptionStatus: _subscriptionStatus,
            activeEntitlements: []
        )
    }
}
