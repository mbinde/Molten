import Testing
import Foundation
@testable import Molten

@Suite("SubscriptionManager Integration with RevenueCat")
@MainActor
struct SubscriptionManagerTests {

    // MARK: - Test Setup

    init() {
        // Ensure debug subscription tier override is disabled for tests
        // This prevents UserDefaults from polluting test results
        DebugConfig.debugOverrideSubscriptionTier = false
    }

    // MARK: - Initial Status Check Tests

    @Test("SubscriptionManager updates EntitlementService to premium when Pro access exists")
    func testProAccessUpdatesTierToPremium() async throws {
        // Arrange
        let entitlementService = EntitlementService(tier: .free)
        let mockSubscriptionService = MockSubscriptionService(hasProAccess: true)
        let manager = SubscriptionManager(
            entitlementService: entitlementService,
            subscriptionService: mockSubscriptionService
        )

        // Wait for initialization to complete
        try await Task.sleep(for: .milliseconds(100))

        // Act
        await manager.checkSubscriptionStatus()

        // Assert
        #expect(entitlementService.currentTier == .premium)
        #expect(manager.hasActiveSubscription == true)
    }

    @Test("SubscriptionManager updates EntitlementService to free when no Pro access")
    func testNoProAccessUpdatesTierToFree() async throws {
        // Arrange
        let entitlementService = EntitlementService(tier: .premium)
        let mockSubscriptionService = MockSubscriptionService(hasProAccess: false)
        let manager = SubscriptionManager(
            entitlementService: entitlementService,
            subscriptionService: mockSubscriptionService
        )

        // Wait for initialization to complete
        try await Task.sleep(for: .milliseconds(100))

        // Act
        await manager.checkSubscriptionStatus()

        // Assert
        #expect(entitlementService.currentTier == .free)
        #expect(manager.hasActiveSubscription == false)
    }

    @Test("SubscriptionManager initializes and checks status on creation")
    func testManagerInitializationChecksStatus() async throws {
        // Arrange
        let entitlementService = EntitlementService(tier: .free)
        let mockSubscriptionService = MockSubscriptionService(hasProAccess: true)

        // Act
        let manager = SubscriptionManager(
            entitlementService: entitlementService,
            subscriptionService: mockSubscriptionService
        )

        // Wait for async initialization with longer timeout and polling
        var attempts = 0
        while entitlementService.currentTier != .premium && attempts < 20 {
            try await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }

        // Assert - tier should be updated during initialization
        #expect(entitlementService.currentTier == .premium)
        #expect(manager.subscriptionStatus == .subscribed)
    }

    // MARK: - Status Change Tests

    @Test("SubscriptionManager responds to subscription status change notification")
    func testRespondsToStatusChangeNotification() async throws {
        // Arrange
        let entitlementService = EntitlementService(tier: .free)
        let mockSubscriptionService = MockSubscriptionService(hasProAccess: false)
        let manager = SubscriptionManager(
            entitlementService: entitlementService,
            subscriptionService: mockSubscriptionService
        )

        // Wait for initialization
        try await Task.sleep(for: .milliseconds(100))

        // Verify starting state
        #expect(entitlementService.currentTier == .free)

        // Act - simulate a purchase completing
        mockSubscriptionService.simulateProPurchase()

        // Post notification that subscription changed
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)

        // Wait for notification to be processed
        try await Task.sleep(for: .milliseconds(200))

        // Assert - tier should now be premium
        #expect(entitlementService.currentTier == .premium)
        #expect(manager.hasActiveSubscription == true)
    }

    @Test("SubscriptionManager responds to subscription expiration")
    func testRespondsToSubscriptionExpiration() async throws {
        // Arrange
        let entitlementService = EntitlementService(tier: .premium)
        let mockSubscriptionService = MockSubscriptionService(hasProAccess: true)
        let manager = SubscriptionManager(
            entitlementService: entitlementService,
            subscriptionService: mockSubscriptionService
        )

        // Wait for initialization
        try await Task.sleep(for: .milliseconds(100))

        // Verify starting state
        #expect(entitlementService.currentTier == .premium)

        // Act - simulate subscription expiring
        mockSubscriptionService.simulateSubscriptionExpiration()

        // Post notification that subscription changed
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)

        // Wait for notification to be processed
        try await Task.sleep(for: .milliseconds(200))

        // Assert - tier should now be free
        #expect(entitlementService.currentTier == .free)
        #expect(manager.hasActiveSubscription == false)
    }

    // MARK: - Edge Cases

    @Test("SubscriptionManager handles multiple status checks correctly")
    func testMultipleStatusChecks() async throws {
        // Arrange
        let entitlementService = EntitlementService(tier: .free)
        let mockSubscriptionService = MockSubscriptionService(hasProAccess: true)
        let manager = SubscriptionManager(
            entitlementService: entitlementService,
            subscriptionService: mockSubscriptionService
        )

        // Act - check status multiple times
        await manager.checkSubscriptionStatus()
        await manager.checkSubscriptionStatus()
        await manager.checkSubscriptionStatus()

        // Assert - should still be premium (idempotent)
        #expect(entitlementService.currentTier == .premium)
        #expect(manager.hasActiveSubscription == true)
    }

    @Test("SubscriptionManager correctly reflects subscription status property")
    func testSubscriptionStatusProperty() async throws {
        // Test with Pro access
        let entitlementService1 = EntitlementService(tier: .free)
        let mockService1 = MockSubscriptionService(hasProAccess: true)
        let manager1 = SubscriptionManager(
            entitlementService: entitlementService1,
            subscriptionService: mockService1
        )
        try await Task.sleep(for: .milliseconds(100))
        await manager1.checkSubscriptionStatus()
        #expect(manager1.hasActiveSubscription == true)

        // Test without Pro access
        let entitlementService2 = EntitlementService(tier: .free)
        let mockService2 = MockSubscriptionService(hasProAccess: false)
        let manager2 = SubscriptionManager(
            entitlementService: entitlementService2,
            subscriptionService: mockService2
        )
        try await Task.sleep(for: .milliseconds(100))
        await manager2.checkSubscriptionStatus()
        #expect(manager2.hasActiveSubscription == false)
    }
}
