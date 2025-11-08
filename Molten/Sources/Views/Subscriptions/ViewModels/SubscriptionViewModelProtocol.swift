import Foundation

/// Protocol for SubscriptionViewModel to enable testability
@MainActor
public protocol SubscriptionViewModelProtocol: ObservableObject {
    var hasProAccess: Bool { get }
    var subscriptionStatus: SubscriptionStatus { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    func loadSubscriptionStatus() async
    func showPaywall() async
    func showCustomerCenter() async
    func restorePurchases() async
}
