//
//  KilnRatesSettingsView.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct KilnRatesSettingsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configure your kiln's maximum heating and cooling rates for different temperature ranges.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("These rates are used when you enter 9999 as a ramp rate in a schedule segment, providing more accurate duration estimates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                TemperatureRateRow(
                    label: "20°C - 260°C",
                    value: Binding(
                        get: { UserSettings.shared.kilnHeatupRate20to260 },
                        set: { UserSettings.shared.kilnHeatupRate20to260 = $0 }
                    ),
                    placeholder: "222"
                )

                TemperatureRateRow(
                    label: "260°C - 540°C",
                    value: Binding(
                        get: { UserSettings.shared.kilnHeatupRate260to540 },
                        set: { UserSettings.shared.kilnHeatupRate260to540 = $0 }
                    ),
                    placeholder: "222"
                )

                TemperatureRateRow(
                    label: "540°C - 815°C",
                    value: Binding(
                        get: { UserSettings.shared.kilnHeatupRate540to815 },
                        set: { UserSettings.shared.kilnHeatupRate540to815 = $0 }
                    ),
                    placeholder: "222"
                )

                TemperatureRateRow(
                    label: "815°C+",
                    value: Binding(
                        get: { UserSettings.shared.kilnHeatupRate815Plus },
                        set: { UserSettings.shared.kilnHeatupRate815Plus = $0 }
                    ),
                    placeholder: "222"
                )
            } header: {
                Text("Heat Up Rates (°C/hour)")
            } footer: {
                Text("Default: 222°C/hour (≈400°F/hour)")
            }

            Section {
                TemperatureRateRow(
                    label: "20°C - 260°C",
                    value: Binding(
                        get: { UserSettings.shared.kilnCooldownRate20to260 },
                        set: { UserSettings.shared.kilnCooldownRate20to260 = $0 }
                    ),
                    placeholder: "56"
                )

                TemperatureRateRow(
                    label: "260°C - 540°C",
                    value: Binding(
                        get: { UserSettings.shared.kilnCooldownRate260to540 },
                        set: { UserSettings.shared.kilnCooldownRate260to540 = $0 }
                    ),
                    placeholder: "167"
                )

                TemperatureRateRow(
                    label: "540°C - 815°C",
                    value: Binding(
                        get: { UserSettings.shared.kilnCooldownRate540to815 },
                        set: { UserSettings.shared.kilnCooldownRate540to815 = $0 }
                    ),
                    placeholder: "167"
                )

                TemperatureRateRow(
                    label: "815°C+",
                    value: Binding(
                        get: { UserSettings.shared.kilnCooldownRate815Plus },
                        set: { UserSettings.shared.kilnCooldownRate815Plus = $0 }
                    ),
                    placeholder: "167"
                )
            } header: {
                Text("Cool Down Rates (°C/hour)")
            } footer: {
                Text("Defaults: 56°C/hour (≈100°F/hour) for 20-260°C, 167°C/hour (≈300°F/hour) for higher ranges")
            }
        }
        .navigationTitle("Kiln Max Rates")
    }
}
