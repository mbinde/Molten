//
//  CustomPaywallView.swift
//  Molten
//
//  Custom paywall UI that fetches offerings from RevenueCat
//

import SwiftUI
import RevenueCat

struct CustomPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var offerings: Offerings?
    @State private var selectedPackage: Package?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var purchaseSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background - subtle gradient with Molten orange
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.moltenOrange.opacity(0.15),
                        colorScheme == .dark ? Color.black : Color.white
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading...")
                        .tint(DesignSystem.Colors.moltenOrange)
                } else if let errorMessage = errorMessage {
                    errorView(message: errorMessage)
                } else if purchaseSuccess {
                    successView
                } else {
                    paywallContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadOfferings()
        }
    }

    // MARK: - Paywall Content

    private var paywallContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero section with Molten logo
                VStack(spacing: 16) {
                    // App icon
                    Image("AppIconImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: DesignSystem.Colors.moltenOrange.opacity(0.3), radius: 10, y: 5)

                    Text("Molten Pro")
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)

                    Text("Unlock the full potential of your glass studio")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)

                // Features list
                VStack(alignment: .leading, spacing: 16) {
                    PaywallFeatureRow(icon: "archivebox.fill", title: "Unlimited Inventory", description: "Track unlimited items (free: 25 items)")
                    PaywallFeatureRow(icon: "cart.fill", title: "Unlimited Shopping Lists", description: "Add unlimited items to your list (free: 10 items)")
                    PaywallFeatureRow(icon: "clock.arrow.circlepath", title: "Cloud Backups", description: "Automatic versioned backups with restore")
                }
                .padding(.horizontal)

                // Package selection
                if let offering = offerings?.current {
                    VStack(spacing: 12) {
                        ForEach(offering.availablePackages, id: \.identifier) { package in
                            PackageOptionView(
                                package: package,
                                isSelected: selectedPackage?.identifier == package.identifier,
                                onSelect: { selectedPackage = package }
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                // Purchase button
                Button {
                    Task {
                        await purchase()
                    }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("Subscribe Now")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedPackage != nil ? DesignSystem.Colors.moltenOrange : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.CornerRadius.large)
                }
                .disabled(selectedPackage == nil || isPurchasing)
                .padding(.horizontal)

                // Restore purchases
                Button {
                    Task {
                        await restorePurchases()
                    }
                } label: {
                    Text("Restore Purchases")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Legal text
                VStack(spacing: 8) {
                    Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text("To cancel, go to Settings > [Your Name] > Subscriptions on your device.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // Links
                HStack(spacing: 20) {
                    Link("Privacy Policy", destination: URL(string: "https://moltenglass.app/privacy/")!)
                    Link("Terms of Use (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }
                .font(.caption)
                .foregroundColor(.accentColor)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(DesignSystem.Colors.accentSuccess)

            Text("Welcome to Pro!")
                .font(.title.bold())

            Text("You now have access to all Pro features.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                dismiss()
            } label: {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignSystem.Colors.moltenOrange)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.CornerRadius.large)
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Unable to Load")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await loadOfferings()
                }
            } label: {
                Text("Try Again")
                    .fontWeight(.semibold)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func loadOfferings() async {
        isLoading = true
        errorMessage = nil

        do {
            offerings = try await Purchases.shared.offerings()

            #if DEBUG
            print("📦 [Paywall] Loaded offerings: \(offerings?.current?.identifier ?? "nil")")
            print("📦 [Paywall] Available packages: \(offerings?.current?.availablePackages.map { $0.identifier } ?? [])")
            #endif

            // Auto-select the first package (usually monthly or the best value)
            if let current = offerings?.current {
                // Prefer annual if available, otherwise first package
                selectedPackage = current.annual ?? current.availablePackages.first
                #if DEBUG
                print("📦 [Paywall] Selected package: \(selectedPackage?.identifier ?? "nil")")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ [Paywall] Failed to load offerings: \(error)")
            #endif
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func purchase() async {
        guard let package = selectedPackage else {
            #if DEBUG
            print("❌ [Paywall] purchase() called but no package selected!")
            #endif
            return
        }

        #if DEBUG
        print("🛒 [Paywall] Starting purchase for: \(package.identifier)")
        #endif

        isPurchasing = true

        do {
            let result = try await Purchases.shared.purchase(package: package)
            let proActive = result.customerInfo.entitlements["pro"]?.isActive ?? false
            #if DEBUG
            print("✅ [Paywall] Purchase completed, pro active: \(proActive), userCancelled: \(result.userCancelled)")
            #endif

            // Only show success if user didn't cancel
            // (entitlement may take a moment to sync, but purchase is confirmed)
            if !result.userCancelled {
                purchaseSuccess = true
                NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
            }
            // If user cancelled, do nothing - they stay on the paywall
        } catch {
            if let rcError = error as? RevenueCat.ErrorCode, rcError == .purchaseCancelledError {
                // User cancelled - do nothing
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isPurchasing = false
    }

    private func restorePurchases() async {
        isPurchasing = true

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()

            if customerInfo.entitlements["pro"]?.isActive == true {
                purchaseSuccess = true
                NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)

                // Auto-dismiss after brief success display
                try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 seconds
                dismiss()
            } else {
                errorMessage = "No active subscription found"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isPurchasing = false
    }
}

// MARK: - Paywall Feature Row

private struct PaywallFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(DesignSystem.Colors.moltenOrange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Package Option View

private struct PackageOptionView: View {
    let package: Package
    let isSelected: Bool
    let onSelect: () -> Void

    private var pricePerMonth: String {
        let product = package.storeProduct

        // Calculate monthly price for comparison
        if package.packageType == .annual {
            let monthlyPrice = product.price as Decimal / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = product.priceFormatter?.locale ?? .current
            return formatter.string(from: monthlyPrice as NSDecimalNumber) ?? ""
        }

        return product.localizedPriceString
    }

    private var savingsText: String? {
        if package.packageType == .annual {
            return "Save 17%"
        }
        return nil
    }

    private var packageTitle: String {
        switch package.packageType {
        case .monthly:
            return "Monthly"
        case .annual:
            return "Annual"
        case .lifetime:
            return "Lifetime"
        default:
            return package.identifier
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(packageTitle)
                            .font(.headline)

                        if let savings = savingsText {
                            Text(savings)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.accentSuccess)
                                .cornerRadius(4)
                        }
                    }

                    if package.packageType == .annual {
                        Text("\(pricePerMonth)/month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.title3.bold())

                    if package.packageType == .annual {
                        Text("per year")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if package.packageType == .monthly {
                        Text("per month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(isSelected ? DesignSystem.Colors.moltenOrange.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .stroke(isSelected ? DesignSystem.Colors.moltenOrange : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())  // Ensure entire area is tappable
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CustomPaywallView()
}
