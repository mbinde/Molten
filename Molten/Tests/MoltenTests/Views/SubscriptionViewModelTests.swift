import Testing
import Foundation
@testable import Molten

@Suite("SubscriptionViewModel Tests")
@MainActor
struct SubscriptionViewModelTests {

    // MARK: - Production ViewModel Tests

    @Test("ViewModel should load subscription status for free user")
    func testLoadStatusFreeUser() async throws {
        let mockService = MockSubscriptionService(hasProAccess: false)
        let viewModel = SubscriptionViewModel(subscriptionService: mockService)

        await viewModel.loadSubscriptionInfo()

        #expect(viewModel.hasProAccess == false)
        #expect(viewModel.subscriptionStatus.isActive == false)
        #expect(viewModel.isLoading == false)
    }

    @Test("ViewModel should load subscription status for Pro user")
    func testLoadStatusProUser() async throws {
        let mockService = MockSubscriptionService(hasProAccess: true)
        let viewModel = SubscriptionViewModel(subscriptionService: mockService)

        await viewModel.loadSubscriptionInfo()

        #expect(viewModel.hasProAccess == true)
        #expect(viewModel.subscriptionStatus.isActive == true)
        #expect(viewModel.isLoading == false)
    }

    @Test("ViewModel should handle paywall presentation")
    func testShowPaywall() async throws {
        let mockService = MockSubscriptionService(hasProAccess: false)
        let viewModel = SubscriptionViewModel(subscriptionService: mockService)

        await viewModel.showPaywall()

        // After showing paywall, status should be reloaded
        #expect(viewModel.errorMessage == nil)
    }

    @Test("ViewModel should handle customer center presentation")
    func testShowCustomerCenter() async throws {
        let mockService = MockSubscriptionService(hasProAccess: true)
        let viewModel = SubscriptionViewModel(subscriptionService: mockService)

        await viewModel.showCustomerCenter()

        // After showing customer center, status should be reloaded
        #expect(viewModel.errorMessage == nil)
    }

    @Test("ViewModel should handle restore purchases")
    func testRestorePurchases() async throws {
        let mockService = MockSubscriptionService(hasProAccess: false)
        let viewModel = SubscriptionViewModel(subscriptionService: mockService)

        await viewModel.restorePurchases()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("ViewModel should set loading state during operations")
    func testLoadingState() async throws {
        let mockService = MockSubscriptionService(hasProAccess: false)
        let viewModel = SubscriptionViewModel(subscriptionService: mockService)

        // Initially not loading
        #expect(viewModel.isLoading == false)

        // Start loading
        Task {
            await viewModel.loadSubscriptionInfo()
        }

        // Wait a moment then check final state
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Mock ViewModel Tests

    @Test("MockViewModel should initialize with free user")
    func testMockViewModelFreeUser() {
        let viewModel = MockSubscriptionViewModel(hasProAccess: false)

        #expect(viewModel.hasProAccess == false)
        #expect(viewModel.subscriptionStatus.isActive == false)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("MockViewModel should initialize with Pro user")
    func testMockViewModelProUser() {
        let viewModel = MockSubscriptionViewModel(hasProAccess: true)

        #expect(viewModel.hasProAccess == true)
        #expect(viewModel.subscriptionStatus.isActive == true)
        #expect(viewModel.subscriptionStatus.productIdentifier == "monthly")
    }

    @Test("MockViewModel should initialize with custom subscription status")
    func testMockViewModelCustomStatus() {
        let customStatus = SubscriptionInfo(
            isActive: true,
            productIdentifier: "lifetime",
            expirationDate: nil,
            willRenew: false
        )

        let viewModel = MockSubscriptionViewModel(
            hasProAccess: true,
            subscriptionStatus: customStatus
        )

        #expect(viewModel.subscriptionStatus.productIdentifier == "lifetime")
        #expect(viewModel.subscriptionStatus.expirationDate == nil)
    }

    @Test("MockViewModel should simulate purchase on showPaywall")
    func testMockViewModelSimulatePurchase() async {
        let viewModel = MockSubscriptionViewModel(hasProAccess: false)

        // Initially free
        #expect(viewModel.hasProAccess == false)

        // Simulate paywall purchase
        await viewModel.showPaywall()

        // Now has Pro access
        #expect(viewModel.hasProAccess == true)
        #expect(viewModel.subscriptionStatus.isActive == true)
    }

    @Test("MockViewModel should support error state")
    func testMockViewModelErrorState() {
        let viewModel = MockSubscriptionViewModel(
            hasProAccess: false,
            errorMessage: "Network connection failed"
        )

        #expect(viewModel.errorMessage == "Network connection failed")
    }

    @Test("MockViewModel should support loading state")
    func testMockViewModelLoadingState() {
        let viewModel = MockSubscriptionViewModel(
            hasProAccess: false,
            isLoading: true
        )

        #expect(viewModel.isLoading == true)
    }
}
