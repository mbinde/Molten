//
//  TabCustomizationView.swift
//  Molten
//
//  Created by Assistant on 10/22/25.
//

import SwiftUI

/// Settings view for customizing which tabs are visible and their order
struct TabCustomizationView: View {
    @State private var config = TabConfiguration.shared
    @State private var showResetAlert = false

    var body: some View {
        List {
            // Tab bar preview section
            tabBarPreviewSection

            // Visible tabs section
            visibleTabsSection

            // Hidden tabs section
            hiddenTabsSection

            // Reset button section
            resetSection
        }
        .navigationTitle("Customize Tabs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Reset Tab Configuration?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                config.resetToDefaults()
            }
        } message: {
            Text("This will restore the default tab configuration. Your custom order and visibility settings will be lost.")
        }
    }

    // MARK: - Tab Bar Preview

    private var tabBarPreviewSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Tab Bar Preview")
                    .font(DesignSystem.Typography.label)
                    .fontWeight(DesignSystem.FontWeight.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Preview of tab bar
                TabBarPreviewView(config: config)
            }
            .padding(.vertical, DesignSystem.Padding.compact)
        } footer: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Up to \(config.maxVisibleTabs) tabs can be shown in the tab bar.")
                if config.needsMoreTab {
                    Text("Additional tabs will appear in the \"More\" menu.")
                }
            }
        }
    }

    // MARK: - Visible Tabs Section

    private var visibleTabsSection: some View {
        Section {
            ForEach(config.visibleTabs, id: \.self) { tab in
                TabConfigurationRow(
                    tab: tab,
                    isVisible: true,
                    isInTabBar: config.tabBarTabs.contains(tab),
                    onToggle: {
                        withAnimation {
                            config.hideTab(tab)
                        }
                    }
                )
            }
            .onMove { source, destination in
                config.moveVisibleTab(from: source, to: destination)
            }
        } header: {
            Text("Visible Tabs")
        } footer: {
            Text("Drag to reorder. Tabs are shown in this order from left to right.")
        }
    }

    // MARK: - Hidden Tabs Section

    private var hiddenTabsSection: some View {
        Section {
            if config.hiddenTabs.isEmpty {
                Text("No hidden tabs")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(config.hiddenTabs, id: \.self) { tab in
                    TabConfigurationRow(
                        tab: tab,
                        isVisible: false,
                        isInTabBar: false,
                        onToggle: {
                            withAnimation {
                                config.showTab(tab)
                            }
                        }
                    )
                }
                .onMove { source, destination in
                    config.moveHiddenTab(from: source, to: destination)
                }
            }
        } header: {
            Text("Hidden Tabs")
        } footer: {
            Text("Hidden tabs can be accessed from the \"More\" menu.")
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Defaults")
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Tab Configuration Row

private struct TabConfigurationRow: View {
    let tab: DefaultTab
    let isVisible: Bool
    let isInTabBar: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Tab icon and name
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: tab.systemImage)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.displayName)
                        .font(DesignSystem.Typography.rowTitle)

                    if !isVisible {
                        Text("Hidden")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if !isInTabBar {
                        Text("In More menu")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Show/Hide toggle
            Button {
                onToggle()
            } label: {
                Image(systemName: isVisible ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(isVisible ? .blue : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Tab Bar Preview

private struct TabBarPreviewView: View {
    var config: TabConfiguration

    var body: some View {
        HStack(spacing: 0) {
            // Show tabs that will appear in tab bar
            ForEach(config.tabBarTabs, id: \.self) { tab in
                tabButton(for: tab)
            }

            // Show More button if needed
            if config.needsMoreTab {
                moreButton
            }
        }
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private func tabButton(for tab: DefaultTab) -> some View {
        VStack(spacing: 4) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 20, weight: .medium))
            Text(tab.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.primary)
        .frame(maxWidth: .infinity)
    }

    private var moreButton: some View {
        VStack(spacing: 4) {
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .medium))
            Text("More")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.primary)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TabCustomizationView()
    }
}
