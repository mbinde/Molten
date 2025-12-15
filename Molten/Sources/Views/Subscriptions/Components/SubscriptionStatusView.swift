// SubscriptionStatusView.swift
import SwiftUI

/// View displaying subscription status and actions
struct SubscriptionStatusView<ViewModel: SubscriptionViewModelProtocol>: View {
    var viewModel: ViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Status Icon
                Image(systemName: viewModel.hasProAccess ? "checkmark.seal.fill" : "lock.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(viewModel.hasProAccess ? .green : .gray)
                    .padding(.top, DesignSystem.Spacing.xl)

                // Status Text
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(viewModel.hasProAccess ? "Pro Access Active" : "Free Version")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(viewModel.subscriptionStatus.displayStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Action Buttons
                VStack(spacing: DesignSystem.Spacing.md) {
                    if !viewModel.hasProAccess {
                        Button {
                            Task {
                                await viewModel.showPaywall()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                Text("Upgrade to Pro")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        .accessibilityIdentifier("subscription.upgradeButton")
                    }

                    if viewModel.hasProAccess {
                        // RevenueCat Customer Center
                        Button {
                            Task {
                                await viewModel.showCustomerCenter()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                Text("Manage Subscription")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        .accessibilityIdentifier("subscription.manageButton")

                        // Direct link to Apple subscription management (always works)
                        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                            HStack {
                                Image(systemName: "arrow.up.forward.app.fill")
                                Text("Manage in App Store")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundStyle(.primary)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        .accessibilityIdentifier("subscription.appStoreButton")
                    }

                    Button {
                        Task {
                            await viewModel.restorePurchases()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Restore Purchases")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundStyle(.primary)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                    .accessibilityIdentifier("subscription.restoreButton")
                }
                .padding(.horizontal)

                // Error Message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.accentDanger)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(DesignSystem.Colors.accentDanger.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .padding(.horizontal)
                }

                // Loading Indicator
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                }

                // Pro Features List
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Pro Features")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, DesignSystem.Spacing.lg)

                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(ProFeaturesList.all) { feature in
                            ProFeatureRow(icon: feature.icon, title: feature.title, freeLimit: feature.freeLimit)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSubscriptionStatus()
        }
    }
}

// MARK: - Previews

#Preview("Free User") {
    NavigationStack {
        SubscriptionStatusView(viewModel: MockSubscriptionViewModel(hasProAccess: false))
    }
}

#Preview("Pro User - Monthly") {
    NavigationStack {
        SubscriptionStatusView(
            viewModel: MockSubscriptionViewModel(
                hasProAccess: true,
                subscriptionStatus: SubscriptionInfo(
                    isActive: true,
                    productIdentifier: "monthly",
                    expirationDate: Date().addingTimeInterval(86400 * 30),
                    willRenew: true
                )
            )
        )
    }
}

#Preview("Pro User - Yearly") {
    NavigationStack {
        SubscriptionStatusView(
            viewModel: MockSubscriptionViewModel(
                hasProAccess: true,
                subscriptionStatus: SubscriptionInfo(
                    isActive: true,
                    productIdentifier: "yearly",
                    expirationDate: Date().addingTimeInterval(86400 * 365),
                    willRenew: true
                )
            )
        )
    }
}

#Preview("Pro User - Lifetime") {
    NavigationStack {
        SubscriptionStatusView(
            viewModel: MockSubscriptionViewModel(
                hasProAccess: true,
                subscriptionStatus: SubscriptionInfo(
                    isActive: true,
                    productIdentifier: "lifetime",
                    expirationDate: nil,
                    willRenew: false
                )
            )
        )
    }
}

#Preview("Loading State") {
    NavigationStack {
        SubscriptionStatusView(
            viewModel: MockSubscriptionViewModel(isLoading: true)
        )
    }
}

#Preview("Error State") {
    NavigationStack {
        SubscriptionStatusView(
            viewModel: MockSubscriptionViewModel(
                hasProAccess: false,
                errorMessage: "Network connection failed. Please try again."
            )
        )
    }
}

// MARK: - Pro Feature Row

private struct ProFeatureRow: View {
    let icon: String
    let title: String
    let freeLimit: String?

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.moltenTeal)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)

                if let freeLimit = freeLimit {
                    Text(freeLimit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}
