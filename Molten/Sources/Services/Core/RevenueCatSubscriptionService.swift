import Foundation
import UIKit
import RevenueCat
import RevenueCatUI

/// Production implementation using RevenueCat SDK
@MainActor
public final class RevenueCatSubscriptionService: SubscriptionServiceProtocol, Sendable {

    private let proEntitlementIdentifier = "molten_glass_pro"

    public init() {}

    public func hasProAccess() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            return customerInfo.entitlements[proEntitlementIdentifier]?.isActive == true
        } catch {
            print("Error checking Pro access: \(error)")
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

        print("✅ [RevenueCat] Found rootViewController, creating PaywallViewController")
        let paywallViewController = PaywallViewController()

        // Handle purchase completion
        paywallViewController.delegate = PaywallViewControllerDelegateHandler.shared

        print("🎬 [RevenueCat] Presenting paywall...")
        await rootViewController.present(paywallViewController, animated: true)
        print("✅ [RevenueCat] Paywall presented")
    }

    public func presentCustomerCenter() async throws {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw SubscriptionServiceError.configurationError
        }

        let customerCenterViewController = CustomerCenterViewController()
        await rootViewController.present(customerCenterViewController, animated: true)
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
        controller.dismiss(animated: true)
        print("✅ Purchase completed successfully")
    }

    func paywallViewController(_ controller: PaywallViewController,
                              didFailPurchasingWith error: Error) {
        print("❌ Purchase failed: \(error)")
    }
}
