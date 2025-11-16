//
//  UpgradePromptView.swift
//  Molten
//
//  Upgrade prompt with StoreKit integration
//

import SwiftUI
import StoreKit

struct UpgradePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager

    let feature: String  // "inventory", "shopping", "projects", etc.
    let currentCount: Int
    let limit: Int

    @State private var selectedProduct: Product?
    @State private var showingPurchaseError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow, .orange.opacity(0.3))
                    .padding(.top, 40)

                // Title
                Text("Upgrade to Premium")
                    .font(.title.bold())

                // Message
                VStack(spacing: 12) {
                    Text("You've reached the free tier limit")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("\(currentCount) / \(limit) \(feature) items")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                }

                // Benefits list
                VStack(alignment: .leading, spacing: 16) {
                    BenefitRow(icon: "infinity", text: "Unlimited \(feature) items")
                    BenefitRow(icon: "square.stack.3d.up.fill", text: "Unlimited projects & logbook entries")
                    BenefitRow(icon: "printer.fill", text: "Batch label printing")
                    BenefitRow(icon: "qrcode.viewfinder", text: "QR code scanning for inventory")
                    BenefitRow(icon: "tag.fill", text: "Custom tags & notes for inventory")
                    BenefitRow(icon: "photo.fill", text: "Add images to inventory items")
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)

                Spacer()

                // Product selection
                if subscriptionManager.isLoading {
                    ProgressView()
                        .padding()
                } else if !subscriptionManager.products.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(subscriptionManager.products, id: \.id) { product in
                            ProductButton(
                                product: product,
                                isSelected: selectedProduct?.id == product.id,
                                onTap: {
                                    selectedProduct = product
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 32)

                    Text("Cancel anytime")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await handlePurchase()
                        }
                    } label: {
                        if subscriptionManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Upgrade to Premium")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedProduct != nil ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(selectedProduct == nil || subscriptionManager.isLoading)

                    Button {
                        dismiss()
                    } label: {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Purchase Failed", isPresented: $showingPurchaseError) {
                Button("OK") { showingPurchaseError = false }
            } message: {
                if let error = subscriptionManager.errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                // Pre-select the monthly product by default
                if selectedProduct == nil {
                    selectedProduct = subscriptionManager.monthlyProduct
                }
            }
        }
    }

    // MARK: - Helpers

    private func handlePurchase() async {
        guard let product = selectedProduct else { return }

        let success = await subscriptionManager.purchase(product)
        if success {
            dismiss()
        } else {
            showingPurchaseError = true
        }
    }
}

// MARK: - Product Button

struct ProductButton: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let subscription = product.subscription {
                        Text(subscriptionPeriodText(subscription.subscriptionPeriod))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.title3.bold())
                        .foregroundColor(.primary)

                    if let savings = savingsText(for: product) {
                        Text(savings)
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
            )
            .cornerRadius(12)
        }
    }

    private func subscriptionPeriodText(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .month:
            return "per month"
        case .year:
            return "per year"
        default:
            return ""
        }
    }

    private func savingsText(for product: Product) -> String? {
        // Show savings for annual plan
        if product.id == SubscriptionProduct.annual.rawValue {
            return "Save 17%"
        }
        return nil
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color.accentColor)
                .frame(width: 32)

            Text(text)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview("Inventory Limit") {
    UpgradePromptView(
        feature: "inventory",
        currentCount: 50,
        limit: 50
    )
}

#Preview("Projects Limit") {
    UpgradePromptView(
        feature: "projects",
        currentCount: 5,
        limit: 5
    )
}
