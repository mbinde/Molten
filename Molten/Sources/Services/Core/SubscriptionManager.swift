//
//  SubscriptionManager.swift
//  Molten
//
//  Manages StoreKit 2 subscriptions and communicates with EntitlementService
//

import Foundation
import StoreKit
import Observation

/// Product identifiers for subscriptions
enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.moltenglass.premium.monthly"
    case annual = "com.moltenglass.premium.annual"
}

/// Manager for handling StoreKit 2 subscriptions
@Observable
@MainActor
class SubscriptionManager {

    // MARK: - Properties

    /// Available subscription products
    private(set) var products: [Product] = []

    /// Current subscription status
    private(set) var subscriptionStatus: SubscriptionStatus = .notSubscribed

    /// Is currently loading products or processing purchase
    private(set) var isLoading = false

    /// Error message for display
    private(set) var errorMessage: String?

    /// Reference to EntitlementService to update tier
    private let entitlementService: EntitlementService

    /// RevenueCat subscription service for checking Pro access
    private let subscriptionService: SubscriptionServiceProtocol

    /// Task handle for monitoring subscription changes
    private var subscriptionTask: Task<Void, Never>?

    // MARK: - Initialization

    init(entitlementService: EntitlementService, subscriptionService: SubscriptionServiceProtocol = AppDependencies.shared.subscriptionService) {
        self.entitlementService = entitlementService
        self.subscriptionService = subscriptionService

        // Start monitoring subscription status
        subscriptionTask = Task {
            await monitorSubscriptionChanges()
        }

        // Load products immediately
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    // Note: deinit is called from the main actor

    // MARK: - Product Loading

    /// Load available subscription products from the App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let productIdentifiers = SubscriptionProduct.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIdentifiers)
            print("✅ Loaded \(products.count) subscription products")
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("❌ Failed to load products: \(error)")
        }

        isLoading = false
    }

    // MARK: - Purchase Flow

    /// Purchase a subscription product
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)

                // Update subscription status
                await checkSubscriptionStatus()

                // Finish the transaction
                await transaction.finish()

                print("✅ Purchase successful: \(product.id)")
                isLoading = false
                return true

            case .userCancelled:
                print("ℹ️ User cancelled purchase")
                isLoading = false
                return false

            case .pending:
                print("⏳ Purchase pending approval")
                errorMessage = "Purchase is pending approval"
                isLoading = false
                return false

            @unknown default:
                print("❌ Unknown purchase result")
                errorMessage = "Unknown error occurred"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ Purchase failed: \(error)")
            isLoading = false
            return false
        }
    }

    /// Restore previous purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            print("✅ Purchases restored")
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("❌ Failed to restore purchases: \(error)")
        }

        isLoading = false
    }

    // MARK: - Subscription Status

    /// Check current subscription status and update EntitlementService
    func checkSubscriptionStatus() async {
        print("🔍 [SubscriptionManager] Checking subscription status via RevenueCat...")

        // Check RevenueCat for Pro access
        let hasProAccess = await subscriptionService.hasProAccess()

        // Update status based on RevenueCat entitlements
        if hasProAccess {
            subscriptionStatus = .subscribed
            entitlementService.updateTier(.premium)
            print("✅ [SubscriptionManager] Pro access confirmed - tier set to PREMIUM")
        } else {
            subscriptionStatus = .notSubscribed
            entitlementService.updateTier(.free)
            print("📊 [SubscriptionManager] No Pro access - tier set to FREE")
        }

        print("📊 [SubscriptionManager] Final subscription status: \(subscriptionStatus)")
    }

    /// Monitor subscription status changes in real-time
    private func monitorSubscriptionChanges() async {
        // Listen for RevenueCat subscription changes via notification
        let center = NotificationCenter.default
        let notifications = center.notifications(named: .subscriptionStatusChanged)

        for await _ in notifications {
            print("🔄 [SubscriptionManager] Subscription status changed notification received")
            await checkSubscriptionStatus()
        }
    }

    // MARK: - Verification

    /// Verify a transaction is valid and hasn't been tampered with
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Helpers

    /// Get the monthly product
    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.monthly.rawValue }
    }

    /// Get the annual product
    var annualProduct: Product? {
        products.first { $0.id == SubscriptionProduct.annual.rawValue }
    }

    /// Check if user has active subscription
    var hasActiveSubscription: Bool {
        subscriptionStatus == .subscribed
    }
}

// MARK: - Supporting Types

/// Subscription status enum
enum SubscriptionStatus: Equatable {
    case notSubscribed
    case subscribed
    case expired
}

/// Subscription-related errors
enum SubscriptionError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .productNotFound:
            return "Subscription product not found"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}
