import SwiftUI

/// Example showing how to gate premium features with RevenueCat
///
/// This file provides reusable patterns for protecting Pro-only features.
/// Copy these patterns to your actual views where needed.

// MARK: - Example 1: Simple Feature Gate

struct ExampleFeatureGateView: View {
    private let subscriptionService: SubscriptionServiceProtocol
    @State private var hasProAccess = false

    init(subscriptionService: SubscriptionServiceProtocol) {
        self.subscriptionService = subscriptionService
    }

    init(deps: AppDependencies = .shared) {
        self.subscriptionService = deps.subscriptionService
    }

    var body: some View {
        VStack {
            // Regular content (always visible)
            Text("Free Features")

            // Pro-only feature
            if hasProAccess {
                Text("⭐ Pro Feature")
                    .foregroundStyle(.yellow)
            } else {
                proUpsellBanner
            }
        }
        .task {
            hasProAccess = await subscriptionService.hasProAccess()
        }
    }

    private var proUpsellBanner: some View {
        Button {
            Task {
                try? await subscriptionService.presentPaywall()
                // Reload access status after paywall dismisses
                hasProAccess = await subscriptionService.hasProAccess()
            }
        } label: {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("Unlock Pro Features")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .accessibilityIdentifier("example.proUpsell")
    }
}

// MARK: - Example 2: List with Pro-only Rows

struct ExampleListWithProFeatures: View {
    private let subscriptionService: SubscriptionServiceProtocol
    @State private var hasProAccess = false

    init(subscriptionService: SubscriptionServiceProtocol) {
        self.subscriptionService = subscriptionService
    }

    init(deps: AppDependencies = .shared) {
        self.subscriptionService = deps.subscriptionService
    }

    var body: some View {
        List {
            Section("Free Features") {
                Text("Feature 1")
                Text("Feature 2")
            }

            Section("Pro Features") {
                if hasProAccess {
                    NavigationLink("Advanced Filters") {
                        Text("Advanced Filters View")
                    }

                    NavigationLink("Batch Export") {
                        Text("Batch Export View")
                    }
                } else {
                    Button {
                        Task {
                            try? await subscriptionService.presentPaywall()
                            hasProAccess = await subscriptionService.hasProAccess()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text("Upgrade to unlock Pro features")
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            hasProAccess = await subscriptionService.hasProAccess()
        }
    }
}

// MARK: - Example 3: Conditional Navigation

struct ExampleConditionalNavigation: View {
    private let subscriptionService: SubscriptionServiceProtocol
    @State private var hasProAccess = false
    @State private var showingPaywall = false

    init(subscriptionService: SubscriptionServiceProtocol) {
        self.subscriptionService = subscriptionService
    }

    init(deps: AppDependencies = .shared) {
        self.subscriptionService = deps.subscriptionService
    }

    var body: some View {
        Button("Advanced Feature") {
            Task {
                if hasProAccess {
                    // Navigate to Pro feature
                    print("Navigate to advanced feature")
                } else {
                    // Show paywall
                    try? await subscriptionService.presentPaywall()
                    hasProAccess = await subscriptionService.hasProAccess()
                }
            }
        }
        .task {
            hasProAccess = await subscriptionService.hasProAccess()
        }
    }
}

// MARK: - Example 4: Quantity Limits

struct ExampleQuantityLimitView: View {
    private let subscriptionService: SubscriptionServiceProtocol
    @State private var hasProAccess = false
    @State private var currentCount = 5
    @State private var showingLimitAlert = false

    init(subscriptionService: SubscriptionServiceProtocol) {
        self.subscriptionService = subscriptionService
    }

    init(deps: AppDependencies = .shared) {
        self.subscriptionService = deps.subscriptionService
    }

    private var itemLimit: Int {
        hasProAccess ? Int.max : 10
    }

    var body: some View {
        VStack {
            Text("Items: \(currentCount) / \(hasProAccess ? "Unlimited" : "\(itemLimit)")")

            Button("Add Item") {
                if currentCount >= itemLimit {
                    showingLimitAlert = true
                } else {
                    currentCount += 1
                }
            }
        }
        .task {
            hasProAccess = await subscriptionService.hasProAccess()
        }
        .alert("Upgrade to Pro", isPresented: $showingLimitAlert) {
            Button("Upgrade") {
                Task {
                    try? await subscriptionService.presentPaywall()
                    hasProAccess = await subscriptionService.hasProAccess()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You've reached the free tier limit of \(itemLimit) items. Upgrade to Pro for unlimited items.")
        }
    }
}

// MARK: - Example 5: Reusable Pro Badge

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DesignSystem.Colors.accentWarning)
            .cornerRadius(4)
    }
}

// Example usage of ProBadge
struct ExampleWithProBadge: View {
    var body: some View {
        HStack {
            Text("Advanced Filters")
            ProBadge()
        }
    }
}

// MARK: - Previews

#Preview("Feature Gate - Free User") {
    ExampleFeatureGateView(
        subscriptionService: MockSubscriptionService(hasProAccess: false)
    )
}

#Preview("Feature Gate - Pro User") {
    ExampleFeatureGateView(
        subscriptionService: MockSubscriptionService(hasProAccess: true)
    )
}

#Preview("List with Pro Features - Free") {
    NavigationStack {
        ExampleListWithProFeatures(
            subscriptionService: MockSubscriptionService(hasProAccess: false)
        )
    }
}

#Preview("List with Pro Features - Pro") {
    NavigationStack {
        ExampleListWithProFeatures(
            subscriptionService: MockSubscriptionService(hasProAccess: true)
        )
    }
}

#Preview("Quantity Limit") {
    ExampleQuantityLimitView(
        subscriptionService: MockSubscriptionService(hasProAccess: false)
    )
}
