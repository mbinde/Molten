import Foundation
import Observation

/// Production ViewModel for subscription management
@MainActor
@Observable
public final class SubscriptionViewModel: SubscriptionViewModelProtocol {

    private let subscriptionService: SubscriptionServiceProtocol

    public var hasProAccess: Bool = false
    public var subscriptionStatus: SubscriptionStatus = SubscriptionStatus(
        isActive: false,
        productIdentifier: nil,
        expirationDate: nil,
        willRenew: false
    )
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    public init(subscriptionService: SubscriptionServiceProtocol = RepositoryFactory.createSubscriptionService()) {
        self.subscriptionService = subscriptionService
    }

    public func loadSubscriptionStatus() async {
        isLoading = true
        errorMessage = nil

        do {
            hasProAccess = await subscriptionService.hasProAccess()
            subscriptionStatus = await subscriptionService.getSubscriptionStatus()
        } catch {
            errorMessage = "Failed to load subscription status"
            print("Error loading subscription status: \(error)")
        }

        isLoading = false
    }

    public func showPaywall() async {
        do {
            try await subscriptionService.presentPaywall()
            // Reload status after paywall dismisses
            await loadSubscriptionStatus()
        } catch {
            errorMessage = "Failed to show subscription options"
            print("Error presenting paywall: \(error)")
        }
    }

    public func showCustomerCenter() async {
        do {
            try await subscriptionService.presentCustomerCenter()
            await loadSubscriptionStatus()
        } catch {
            errorMessage = "Failed to show customer center"
            print("Error presenting customer center: \(error)")
        }
    }

    public func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await subscriptionService.restorePurchases()
            await loadSubscriptionStatus()
            errorMessage = nil // Success - clear any previous errors
        } catch {
            errorMessage = "Failed to restore purchases. Please try again."
            print("Error restoring purchases: \(error)")
        }

        isLoading = false
    }
}
