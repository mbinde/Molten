import Foundation
#if canImport(UIKit)
import UIKit
#endif
import RevenueCat
import RevenueCatUI

/// Production implementation using RevenueCat SDK
@MainActor
public final class RevenueCatSubscriptionService: SubscriptionServiceProtocol, Sendable {

    private let proEntitlementIdentifier = "Molten Glass Pro"

    public init() {}

    public func hasProAccess() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            print("🔍 [RevenueCat] Checking Pro access for entitlement: '\(proEntitlementIdentifier)'")
            print("🔍 [RevenueCat] Available entitlements: \(customerInfo.entitlements.all.keys.sorted())")
            print("🔍 [RevenueCat] Active entitlements: \(customerInfo.entitlements.all.filter { $0.value.isActive }.keys.sorted())")

            if let proEntitlement = customerInfo.entitlements[proEntitlementIdentifier] {
                print("🔍 [RevenueCat] Pro entitlement found - isActive: \(proEntitlement.isActive)")
                return proEntitlement.isActive
            } else {
                print("⚠️ [RevenueCat] Pro entitlement '\(proEntitlementIdentifier)' not found in customer entitlements")
                return false
            }
        } catch {
            print("❌ [RevenueCat] Error checking Pro access: \(error)")
            return false
        }
    }

    public func getSubscriptionStatus() async -> SubscriptionInfo {
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
            print("Error getting subscription status: \(error)")
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
        print("🔵 [RevenueCat] presentPaywall() called")

        // RevenueCat Paywalls (modern approach with default offering)
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("❌ [RevenueCat] Could not find windowScene")
            throw SubscriptionServiceError.configurationError
        }

        guard let rootViewController = await windowScene.windows.first?.rootViewController else {
            print("❌ [RevenueCat] Could not find rootViewController")
            throw SubscriptionServiceError.configurationError
        }

        // Find the topmost presented view controller (important for sheets/modals)
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }

        print("✅ [RevenueCat] Found topmost view controller: \(type(of: topViewController))")
        let paywallViewController = PaywallViewController()

        // Handle purchase completion
        paywallViewController.delegate = PaywallViewControllerDelegateHandler.shared

        print("🎬 [RevenueCat] Presenting paywall from topmost view controller...")
        await topViewController.present(paywallViewController, animated: true)
        print("✅ [RevenueCat] Paywall presented")
    }

    public func presentCustomerCenter() async throws {
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
            print("Error checking entitlement '\(identifier)': \(error)")
            return false
        }
    }
}

// MARK: - PaywallViewController Delegate Handler

@MainActor
private class PaywallViewControllerDelegateHandler: NSObject, PaywallViewControllerDelegate {
    static let shared = PaywallViewControllerDelegateHandler()

    func paywallViewController(_ controller: PaywallViewController,
                              didFinishPurchasingWith customerInfo: RevenueCat.CustomerInfo) {
        print("✅ [RevenueCat] Purchase completed successfully!")
        print("✅ [RevenueCat] Customer has entitlements: \(customerInfo.entitlements.all.keys.sorted())")
        print("✅ [RevenueCat] Active entitlements: \(customerInfo.entitlements.all.filter { $0.value.isActive }.keys.sorted())")

        controller.dismiss(animated: true)

        // Post notification to reload subscription status
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }

    func paywallViewController(_ controller: PaywallViewController,
                              didFailPurchasingWith error: Error) {
        print("❌ [RevenueCat] Purchase failed: \(error)")
    }
}

// Notification for subscription status changes
extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}
