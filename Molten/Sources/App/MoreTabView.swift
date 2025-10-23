//
//  MoreTabView.swift
//  Molten
//
//  Created by Assistant on 10/22/25.
//

import SwiftUI

/// View shown in the "More" tab that displays additional tabs
struct MoreTabView: View {
    @Binding var selectedTab: DefaultTab
    var config: TabConfiguration
    let onTabSelect: (DefaultTab) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Show tabs in More menu with their position indicators
                ForEach(config.moreTabs, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        onTabSelect(tab)
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: tab.systemImage)
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tab.displayName)
                                    .font(DesignSystem.Typography.rowTitle)
                                    .foregroundColor(.primary)

                                // Show position hint
                                if let index = config.tabs.firstIndex(of: tab) {
                                    Text("Position \(index + 1)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if selectedTab == tab {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, DesignSystem.Padding.compact)
                    }
                }

                // Link to customize tabs
                Section {
                    NavigationLink {
                        TabCustomizationView()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title3)
                                .foregroundColor(.gray)
                                .frame(width: 30)

                            Text("Edit Tabs...")
                                .font(DesignSystem.Typography.rowTitle)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, DesignSystem.Padding.compact)
                    }
                }
            }
            .navigationTitle("More")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
