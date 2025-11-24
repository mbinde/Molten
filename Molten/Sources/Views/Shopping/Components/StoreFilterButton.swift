//
//  StoreFilterButton.swift
//  Flameworker
//
//  Created by Assistant on 1/18/25.
//

import SwiftUI

struct StoreFilterButton: View {
    let selectedStore: String?
    let onTap: () -> Void
    let onClear: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "building.2")
                    .font(DesignSystem.Typography.captionSmall)

                if let selectedStore = selectedStore {
                    Text(selectedStore)
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .lineLimit(1)

                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.caption)
                        .onTapGesture {
                            withAnimation {
                                onClear()
                            }
                        }
                        .accessibilityIdentifier("store_filter_clear")
                } else {
                    Text("All Stores")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
            }
            .foregroundColor(selectedStore == nil ? DesignSystem.Colors.textSecondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip + DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Padding.buttonVertical)
            .background(selectedStore == nil ? DesignSystem.Colors.backgroundInput : DesignSystem.Colors.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .accessibilityIdentifier("store_filter_button")
    }
}
