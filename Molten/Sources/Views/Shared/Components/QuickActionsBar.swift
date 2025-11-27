//
//  QuickActionsBar.swift
//  Molten
//
//  Horizontal bar of quick action buttons for detail views
//  Provides easy access to common actions like adding inventory, shopping list items, or notes
//

import SwiftUI

/// Configuration for a quick action button
struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}

/// Horizontal bar of quick action buttons
/// Used below the hero header in detail views
struct QuickActionsBar: View {
    let actions: [QuickAction]

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ForEach(actions) { action in
                QuickActionButton(
                    title: action.title,
                    icon: action.icon,
                    action: action.action
                )
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}

/// Individual quick action button with icon and label
private struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(DesignSystem.Typography.listItemCaption)
                    .fontWeight(DesignSystem.FontWeight.medium)
            }
            .foregroundColor(DesignSystem.Colors.accentPrimary)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.tintPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Quick Actions Bar") {
    VStack(spacing: 20) {
        QuickActionsBar(actions: [
            QuickAction(title: "Inventory", icon: "archivebox.fill") { },
            QuickAction(title: "Shopping", icon: "cart.fill") { },
            QuickAction(title: "Note", icon: "note.text") { }
        ])

        QuickActionsBar(actions: [
            QuickAction(title: "Add", icon: "plus") { },
            QuickAction(title: "Edit", icon: "pencil") { }
        ])
    }
    .padding()
}
