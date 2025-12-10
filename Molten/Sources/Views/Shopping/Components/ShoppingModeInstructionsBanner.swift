//
//  ShoppingModeInstructionsBanner.swift
//  Flameworker
//
//  Created by Assistant on 1/18/25.
//

import SwiftUI

struct ShoppingModeInstructionsBanner: View {
    @Binding var isExpanded: Bool
    let itemsInBasketCount: Int
    let totalItemsInViewCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "cart.fill")
                        .foregroundColor(.green)
                    Text("Shopping Mode")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("•")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("\(itemsInBasketCount)/\(totalItemsInViewCount) in basket")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .secondaryCaptionStyle()
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shopping_mode_instructions_toggle")

            if isExpanded {
                Text("Tap on items to confirm that you've added them to your basket. When you're done, click \"Checkout\" and they'll be removed from your list and added to your inventory.")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.accentSuccess.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .padding(.horizontal, DesignSystem.Padding.standard)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}
