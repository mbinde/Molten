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
    case monthly = "monthly499"
    case annual = "annual3999"  // TODO: Create this in App Store Connect
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

    /// Flag to prevent concurrent subscription checks (prevents deadlocks)
    private var isCheckingSubscription = false

    /// Timestamp of last successful RevenueCat refresh
    private var lastRevenueCatRefresh: Date?

    /// Minimum interval between RevenueCat refreshes (30 seconds)
    /// This prevents blocking calls during rapid view redraws
    private let minimumRefreshInterval: TimeInterval = 30

    // MARK: - Initialization

    /// Initialize SubscriptionManager
    /// - Parameters:
    ///   - entitlementService: Service for managing entitlements
    ///   - subscriptionService: Service for checking subscription status (RevenueCat or mock)
    ///   - deferInitialCheck: If true, don't automatically check subscription status on init.
    ///                        Use this in production where RevenueCat isn't configured yet.
    ///                        The check will happen when the launch screen completes.
    init(entitlementService: EntitlementService,
         subscriptionService: SubscriptionServiceProtocol = AppDependencies.shared.subscriptionService,
         deferInitialCheck: Bool = false) {
        self.entitlementService = entitlementService
        self.subscriptionService = subscriptionService

        // Start monitoring subscription status (this just listens for notifications, doesn't call SDK)
        subscriptionTask = Task {
            await monitorSubscriptionChanges()
        }

        // Only do automatic subscription check if not deferred
        // When deferred, the check happens later (after launch screen) when RevenueCat is ready
        if !deferInitialCheck {
            Task {
                // Delay to let RevenueCat fully initialize
                // This prevents deadlocks when customerInfo() is called too early
                try? await Task.sleep(for: .milliseconds(500))
                await loadProducts()
                await checkSubscriptionStatus()
            }
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
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
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

                isLoading = false
                return true

            case .userCancelled:
                isLoading = false
                return false

            case .pending:
                errorMessage = "Purchase is pending approval"
                isLoading = false
                return false

            @unknown default:
                errorMessage = "Unknown error occurred"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
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
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Subscription Status

    /// Check current subscription status and update EntitlementService
    /// Uses local cache for immediate response, then refreshes from RevenueCat
    func checkSubscriptionStatus() async {
        // Prevent concurrent calls which can cause RevenueCat deadlocks
        guard !isCheckingSubscription else {
            return
        }
        isCheckingSubscription = true
        defer { isCheckingSubscription = false }

        // Step 1: Check local cache first for immediate response
        // This allows offline usage and prevents blocking on network
        let cache = EntitlementCache.shared
        let cachedPremium = cache.getEffectivePremiumStatus()

        if cachedPremium {
            // Use cached premium status immediately
            subscriptionStatus = .subscribed
            entitlementService.updateTier(.premium)
            print("🔐 [Subscription] Using cached premium status")
        }

        // Step 2: Check if we should skip RevenueCat refresh
        // Skip if we refreshed recently (prevents blocking during rapid view redraws)
        if let lastRefresh = lastRevenueCatRefresh {
            let timeSinceRefresh = Date().timeIntervalSince(lastRefresh)
            if timeSinceRefresh < minimumRefreshInterval {
                print("🔐 [Subscription] Skipping RevenueCat refresh (last refresh \(Int(timeSinceRefresh))s ago)")
                return
            }
        }

        // Step 3: Refresh from RevenueCat in a non-blocking task
        // Mark refresh time now to prevent concurrent attempts
        lastRevenueCatRefresh = Date()

        // Use a regular Task (not detached) so RevenueCat's internal observers
        // stay on the main actor and don't trigger "publishing from background thread" warnings.
        // The 30-second debounce above should prevent the mutex contention that caused deadlocks.
        // NOTE: If deadlocks return, try Task.detached(priority: .utility) here instead,
        // but that will trigger RevenueCat warnings about publishing from background threads.
        Task {
            do {
                let subscriptionInfo = await subscriptionService.getSubscriptionStatus()

                // Update cache with fresh data
                cache.updateCache(
                    isPremium: subscriptionInfo.isActive,
                    productIdentifier: subscriptionInfo.productIdentifier,
                    expirationDate: subscriptionInfo.expirationDate
                )

                // Update UI state with fresh data
                if subscriptionInfo.isActive {
                    subscriptionStatus = .subscribed
                    entitlementService.updateTier(.premium)
                } else {
                    subscriptionStatus = .notSubscribed
                    entitlementService.updateTier(.free)
                }

                print("🔐 [Subscription] Refreshed from RevenueCat: \(subscriptionInfo.isActive ? "Premium" : "Free")")

            } catch {
                // Network error - rely on cache
                print("🔐 [Subscription] Failed to refresh from RevenueCat: \(error.localizedDescription)")

                // If we don't have valid cached premium, ensure we're in free tier
                if !cachedPremium {
                    subscriptionStatus = .notSubscribed
                    entitlementService.updateTier(.free)
                }
                // If cachedPremium is true, we already set premium above - keep it
            }
        }
    }

    /// Whether the entitlement cache is expiring soon and user should connect to internet
    var shouldShowCacheExpiryWarning: Bool {
        EntitlementCache.shared.shouldShowExpiryWarning
    }

    /// Days until cached entitlement expires (nil if not applicable)
    var daysUntilCacheExpiry: Int? {
        EntitlementCache.shared.daysUntilExpiry
    }

    /// Monitor subscription status changes in real-time
    private func monitorSubscriptionChanges() async {
        // Listen for RevenueCat subscription changes via notification
        let center = NotificationCenter.default
        let notifications = center.notifications(named: .subscriptionStatusChanged)

        for await _ in notifications {
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
