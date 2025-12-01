import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
import RevenueCatUI
#endif
import RevenueCat

/// Production implementation using RevenueCat SDK
@MainActor
public final class RevenueCatSubscriptionService: SubscriptionServiceProtocol, Sendable {

    private let proEntitlementIdentifier = "pro"

    public init() {}

    public func hasProAccess() async -> Bool {
        // Check debug override first (for testing)
        if UserDefaults.standard.bool(forKey: "debugOverrideSubscriptionTier") {
            let tierValue = UserDefaults.standard.integer(forKey: "debugSubscriptionTierValue")
            return tierValue == 1  // 1 = premium
        }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            if let proEntitlement = customerInfo.entitlements[proEntitlementIdentifier] {
                return proEntitlement.isActive
            } else {
                return false
            }
        } catch {
            // Error checking Pro access - fail closed
            return false
        }
    }

    public func getSubscriptionStatus() async -> SubscriptionInfo {
        // Check debug override first (for testing)
        if UserDefaults.standard.bool(forKey: "debugOverrideSubscriptionTier") {
            let tierValue = UserDefaults.standard.integer(forKey: "debugSubscriptionTierValue")
            if tierValue == 1 {
                return SubscriptionInfo(
                    isActive: true,
                    productIdentifier: "debug.premium",
                    expirationDate: Date().addingTimeInterval(86400 * 365),  // 1 year from now
                    willRenew: true
                )
            }
        }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()

            // Check for active subscription
            if let entitlement = customerInfo.entitlements[proEntitlementIdentifier],
               entitlement.isActive {

                return SubscriptionInfo(
                    isActive: true,
                    productIdentifier: entitlement.productIdentifier,
                    expirationDate: entitlement.expirationDate,
                    willRenew: entitlement.willRenew
                )
            }

            return SubscriptionInfo(
                isActive: false,
                productIdentifier: nil,
                expirationDate: nil,
                willRenew: false
            )
        } catch {
            // Error getting subscription status - fail closed
            return SubscriptionInfo(
                isActive: false,
                productIdentifier: nil,
                expirationDate: nil,
                willRenew: false
            )
        }
    }

    public func getCustomerInfo() async throws -> CustomerInfo {
        let customerInfo = try await Purchases.shared.customerInfo()
        let status = await getSubscriptionStatus()

        let entitlements = customerInfo.entitlements.all.values.map { entitlement in
            EntitlementInfo(
                identifier: entitlement.identifier,
                isActive: entitlement.isActive
            )
        }

        return CustomerInfo(
            originalAppUserId: customerInfo.originalAppUserId,
            subscriptionStatus: status,
            activeEntitlements: entitlements
        )
    }

    public func presentPaywall() async throws {
        #if canImport(UIKit)
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            throw SubscriptionServiceError.configurationError
        }

        guard let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw SubscriptionServiceError.configurationError
        }

        // Find the topmost presented view controller (important for sheets/modals)
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }

        // Use our custom SwiftUI paywall
        let paywallView = CustomPaywallView()
        let hostingController = UIHostingController(rootView: paywallView)
        hostingController.modalPresentationStyle = .pageSheet

        await topViewController.present(hostingController, animated: true)
        #else
        throw SubscriptionServiceError.configurationError
        #endif
    }

    public func presentCustomerCenter() async throws {
        #if canImport(UIKit)
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw SubscriptionServiceError.configurationError
        }

        // Find the topmost presented view controller (important for sheets/modals)
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }

        let customerCenterViewController = CustomerCenterViewController()
        await topViewController.present(customerCenterViewController, animated: true)
        #else
        throw SubscriptionServiceError.configurationError
        #endif
    }

    public func restorePurchases() async throws -> CustomerInfo {
        let customerInfo = try await Purchases.shared.restorePurchases()
        let status = await getSubscriptionStatus()

        let entitlements = customerInfo.entitlements.all.values.map { entitlement in
            EntitlementInfo(
                identifier: entitlement.identifier,
                isActive: entitlement.isActive
            )
        }

        return CustomerInfo(
            originalAppUserId: customerInfo.originalAppUserId,
            subscriptionStatus: status,
            activeEntitlements: entitlements
        )
    }

    public func checkEntitlement(_ identifier: String) async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            return customerInfo.entitlements[identifier]?.isActive == true
        } catch {
            // Error checking entitlement - fail closed
            return false
        }
    }
}

// MARK: - PaywallViewController Delegate Handler

#if canImport(UIKit)
@MainActor
private class PaywallViewControllerDelegateHandler: NSObject, PaywallViewControllerDelegate {
    static let shared = PaywallViewControllerDelegateHandler()

    func paywallViewController(_ controller: PaywallViewController,
                              didFinishPurchasingWith customerInfo: RevenueCat.CustomerInfo) {
        controller.dismiss(animated: true)

        // Post notification to reload subscription status
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }

    func paywallViewController(_ controller: PaywallViewController,
                              didFailPurchasingWith error: Error) {
        // Purchase failed - error silently handled
    }
}
#endif

// Notification for subscription status changes
extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}
