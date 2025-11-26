//
//  TerminologySettingsView.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct TerminologySettingsView: View {
    @ObservedObject var settings = GlassTerminologySettings.shared

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Customize how different rod sizes are labeled in the app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Large Rods")
                        Text("12mm+ diameter")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 140, alignment: .leading)
                    Spacer()
                    TextField("Bar", text: $settings.bigRodDisplayName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 150)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Standard Rods")
                        Text("5-6mm diameter")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 140, alignment: .leading)
                    Spacer()
                    TextField("Rod", text: $settings.rodDisplayName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 150)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Display Names")
            } footer: {
                Text("Customize how different rod sizes are labeled throughout the app.")
            }

            Section {
                Button {
                    settings.resetToDefaults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Defaults")
                    }
                }
                .accessibilityIdentifier("terminology_reset_defaults")
            } footer: {
                Text("Reset display names to \"Bar\" and \"Rod\"")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Changing display names only affects how products are labeled in the interface.")
                                .font(.callout)
                                .foregroundStyle(.primary)

                            Text("Your stored inventory data will not be affected, so you can safely customize terminology at any time.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Glass Terminology")
    }
}
