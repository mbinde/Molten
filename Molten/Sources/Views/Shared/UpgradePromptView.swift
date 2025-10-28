//
//  UpgradePromptView.swift
//  Molten
//
//  Simple upgrade prompt shown when user hits subscription limit
//

import SwiftUI

struct UpgradePromptView: View {
    @Environment(\.dismiss) private var dismiss

    let feature: String  // "inventory", "shopping", "projects", etc.
    let currentCount: Int
    let limit: Int

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
                    BenefitRow(icon: "arrow.up.doc.fill", text: "CSV import & bulk editing")
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)

                Spacer()

                // Pricing info
                VStack(spacing: 8) {
                    Text("$5/month or $50/year")
                        .font(.title2.bold())
                        .foregroundColor(.primary)

                    Text("Cancel anytime")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        // TODO: Navigate to subscription purchase
                        // For now, just dismiss
                        dismiss()
                    } label: {
                        Text("Upgrade to Premium")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

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
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
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
