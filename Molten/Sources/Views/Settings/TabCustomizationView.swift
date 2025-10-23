//
//  TabCustomizationView.swift
//  Molten
//
//  Created by Assistant on 10/22/25.
//

import SwiftUI

/// View for customizing tab bar appearance and order
struct TabCustomizationView: View {
    @State private var config = TabConfiguration.shared
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

#Preview {
    NavigationStack {
        TabCustomizationView()
    }
}
