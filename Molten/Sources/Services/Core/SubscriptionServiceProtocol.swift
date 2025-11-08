import Foundation

/// Protocol for subscription management
@MainActor
public protocol SubscriptionServiceProtocol: Sendable {
    /// Check if user has active Pro entitlement
    func hasProAccess() async -> Bool

    /// Get current subscription status
    func getSubscriptionStatus() async -> SubscriptionStatus

    /// Get customer info (for displaying in UI)
    func getCustomerInfo() async throws -> CustomerInfo

    /// Present paywall (iOS 15+ with RevenueCat Paywalls)
    func presentPaywall() async throws

    /// Present customer center for managing subscription
    func presentCustomerCenter() async throws

    /// Restore purchases
    func restorePurchases() async throws -> CustomerInfo

    /// Check specific entitlement
    func checkEntitlement(_ identifier: String) async -> Bool
}

/// Customer information model
public struct CustomerInfo: Sendable {
    public let originalAppUserId: String
    public let subscriptionStatus: SubscriptionStatus
    public let activeEntitlements: [EntitlementInfo]

    public init(
        originalAppUserId: String,
        subscriptionStatus: SubscriptionStatus,
        activeEntitlements: [EntitlementInfo]
    ) {
        self.originalAppUserId = originalAppUserId
        self.subscriptionStatus = subscriptionStatus
        self.activeEntitlements = activeEntitlements
    }
}
