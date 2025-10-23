//
//  TabCustomizationView.swift
//  Molten
//
//  Created by Assistant on 10/22/25.
//

import SwiftUI

/// View for customizing tab bar appearance and order
struct TabCustomizationView: View {
    @Bindable var config = TabConfiguration.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Tab bar size section
            Section {
                HStack {
                    Text("Tabs in Tab Bar")
                        .font(DesignSystem.Typography.label)

                    Spacer()

                    Stepper("\(config.maxVisibleTabs)", value: $config.maxVisibleTabs, in: 3...8)
                        .labelsHidden()
                }

                Text("Choose how many tabs to show in the tab bar. Additional tabs will appear in the More menu.")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                // Live preview of tab bar
                VStack(spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TabBarPreview(config: config)
                        .padding(.vertical, 8)
                }
                .padding(.top, 8)
            } header: {
                Text("Tab Bar Size")
            }

            // Tab order section
            Section {
                ForEach(Array(config.tabs.enumerated()), id: \.element) { index, tab in
                    HStack(spacing: DesignSystem.Spacing.md) {
                        // Drag handle
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        // Tab icon
                        Image(systemName: tab.systemImage)
                            .foregroundColor(.blue)
                            .frame(width: 24)

                        // Tab name
                        Text(tab.displayName)
                            .font(DesignSystem.Typography.rowTitle)

                        Spacer()

                        // Position indicator
                        if index < config.maxVisibleTabs {
                            // In tab bar
                            Text("Tab Bar")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            // In More menu
                            Text("More")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onMove { source, destination in
                    config.moveTabs(from: source, to: destination)
                }
            } header: {
                Text("Tab Order")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Drag to reorder tabs. The first \(config.maxVisibleTabs) tabs will appear in the tab bar, and the rest in the More menu.")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    HStack(spacing: 16) {
                        Label {
                            Text("In Tab Bar")
                                .font(.caption)
                        } icon: {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 8, height: 8)
                        }

                        Label {
                            Text("In More Menu")
                                .font(.caption)
                        } icon: {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }

            // Reset section
            Section {
                Button(role: .destructive) {
                    config.resetToDefaults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Defaults")
                    }
                }
            }
        }
        .navigationTitle("Edit Tabs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .environment(\.editMode, .constant(.active))
    }
}

// MARK: - Tab Bar Preview

/// Live preview of what the tab bar will look like
struct TabBarPreview: View {
    let config: TabConfiguration

    var body: some View {
        HStack(spacing: 0) {
            // Show tabs that will be in tab bar
            ForEach(config.tabBarTabs, id: \.self) { tab in
                miniTabButton(for: tab)
            }

            // Show More button if needed
            if config.needsMoreTab {
                miniMoreButton
            }
        }
        .frame(height: 50)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(10)
    }

    private func miniTabButton(for tab: DefaultTab) -> some View {
        VStack(spacing: 3) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.blue)
            Text(tab.displayName)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var miniMoreButton: some View {
        VStack(spacing: 3) {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            Text("More")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        TabCustomizationView()
    }
}
