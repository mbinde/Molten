import Foundation
import Observation

/// Mock ViewModel for testing and SwiftUI previews
@MainActor
@Observable
public final class MockSubscriptionViewModel: SubscriptionViewModelProtocol {

    public var hasProAccess: Bool
    public var subscriptionStatus: SubscriptionStatus
    public var isLoading: Bool
    public var errorMessage: String?

    public init(
        hasProAccess: Bool = false,
        subscriptionStatus: SubscriptionStatus? = nil,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.hasProAccess = hasProAccess
        self.subscriptionStatus = subscriptionStatus ?? SubscriptionStatus(
            isActive: hasProAccess,
            productIdentifier: hasProAccess ? "monthly" : nil,
            expirationDate: hasProAccess ? Date().addingTimeInterval(86400 * 30) : nil,
            willRenew: hasProAccess
        )
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }

    public func loadSubscriptionStatus() async {
        // Mock - no actual loading
    }

    public func showPaywall() async {
        // Mock - simulate purchase
        hasProAccess = true
        subscriptionStatus = SubscriptionStatus(
            isActive: true,
            productIdentifier: "monthly",
            expirationDate: Date().addingTimeInterval(86400 * 30),
            willRenew: true
        )
    }

    public func showCustomerCenter() async {
        // Mock - no actual action
    }

    public func restorePurchases() async {
        // Mock - no actual restoration
    }
}
