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
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .padding(.horizontal)
                }

                // Loading Indicator
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
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
