//
//  MoreTabView.swift
//  Molten
//
//  Created by Assistant on 10/22/25.
//

import SwiftUI

/// View shown in the "More" popup that displays additional tabs
struct MoreTabView: View {
    @Binding var selectedTab: DefaultTab
    var config: TabConfiguration
    let onTabSelect: (DefaultTab) -> Void

    @State private var showingTabCustomization = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("More")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.vertical, DesignSystem.Padding.compact)
            .background(Color.gray.opacity(0.1))

            Divider()

            // Tabs list
            VStack(spacing: 0) {
                ForEach(config.moreTabs, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        onTabSelect(tab)
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: tab.systemImage)
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 28)

                            Text(tab.displayName)
                                .font(DesignSystem.Typography.rowTitle)
                                .foregroundColor(.primary)

                            Spacer()

                            if selectedTab == tab {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Padding.standard)
                        .padding(.vertical, 12)
                        .background(selectedTab == tab ? Color.blue.opacity(0.08) : Color.clear)
                    }
                    .buttonStyle(.plain)

                    if tab != config.moreTabs.last {
                        Divider()
                            .padding(.leading, DesignSystem.Padding.standard + 28 + DesignSystem.Spacing.md)
                    }
                }

                if !config.moreTabs.isEmpty {
                    Divider()
                }

                // Edit Tabs button
                Button {
                    showingTabCustomization = true
                } label: {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 28)

                        Text("Edit Tabs...")
                            .font(DesignSystem.Typography.rowTitle)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Padding.standard)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 250)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        .sheet(isPresented: $showingTabCustomization) {
            NavigationStack {
                TabCustomizationView()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MoreTabView(
        selectedTab: .constant(.catalog),
        config: TabConfiguration.preview(),
        onTabSelect: { _ in }
    )
}
