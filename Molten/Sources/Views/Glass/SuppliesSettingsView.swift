//
//  SuppliesSettingsView.swift
//  Molten
//
//  Settings specific to the Supplies tab
//

import SwiftUI

struct SuppliesSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // Settings
    @AppStorage("defaultUnits") private var defaultUnitsRawValue = DefaultUnits.grams.rawValue
    @AppStorage("defaultDimensionUnits") private var defaultDimensionUnitsRawValue = DefaultDimensionUnits.metric.rawValue
    @AppStorage("showRatingsInCatalog") private var showRatingsInCatalog = true

    @State private var colorChipDisplayMode: UserSettings.ColorChipDisplayMode = UserSettings.shared.colorChipDisplayMode

    private var defaultUnitsBinding: Binding<DefaultUnits> {
        Binding(
            get: { DefaultUnits(rawValue: defaultUnitsRawValue) ?? .grams },
            set: { defaultUnitsRawValue = $0.rawValue }
        )
    }

    private var defaultDimensionUnitsBinding: Binding<DefaultDimensionUnits> {
        Binding(
            get: { DefaultDimensionUnits(rawValue: defaultDimensionUnitsRawValue) ?? .metric },
            set: { defaultDimensionUnitsRawValue = $0.rawValue }
        )
    }

    private var colorChipDisplayModeBinding: Binding<UserSettings.ColorChipDisplayMode> {
        Binding(
            get: { colorChipDisplayMode },
            set: {
                colorChipDisplayMode = $0
                UserSettings.shared.colorChipDisplayMode = $0
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Units
                Section("Units") {
                    Picker("Weight", selection: defaultUnitsBinding) {
                        ForEach(DefaultUnits.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Dimensions", selection: defaultDimensionUnitsBinding) {
                        ForEach(DefaultDimensionUnits.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: - Display
                Section("Display") {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Picker("Color Chips", selection: colorChipDisplayModeBinding) {
                            ForEach(UserSettings.ColorChipDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(colorChipDisplayMode.description)
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    if FeatureFlags.ENABLE_RATINGS {
                        Toggle("Show Ratings", isOn: $showRatingsInCatalog)
                    }

                    Toggle("Expand Descriptions", isOn: Binding(
                        get: { UserSettings.shared.expandManufacturerDescriptionsByDefault },
                        set: { UserSettings.shared.expandManufacturerDescriptionsByDefault = $0 }
                    ))

                    Toggle("Expand My Notes", isOn: Binding(
                        get: { UserSettings.shared.expandUserNotesByDefault },
                        set: { UserSettings.shared.expandUserNotesByDefault = $0 }
                    ))
                }

                // MARK: - Global Filters
                Section {
                    NavigationLink {
                        COEFilterView()
                    } label: {
                        HStack {
                            Text("COE Filter")
                            Spacer()
                            Text(coeFilterSummary)
                                .font(DesignSystem.Typography.listItemCaption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    NavigationLink {
                        ManufacturerFilterView()
                    } label: {
                        HStack {
                            Text("Manufacturer Filter")
                            Spacer()
                            Text(manufacturerFilterSummary)
                                .font(DesignSystem.Typography.listItemCaption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    Toggle("Apply Filters to Inventory", isOn: Binding(
                        get: { UserSettings.shared.applyFiltersToInventory },
                        set: { UserSettings.shared.applyFiltersToInventory = $0 }
                    ))
                } header: {
                    Text("Global Filters")
                } footer: {
                    Text("Global filters limit which items appear throughout the app. Use these to focus on specific COE types or manufacturers you work with.")
                }
            }
            .navigationTitle("Supplies Settings")
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
        }
    }

    // MARK: - Filter Summaries

    private var coeFilterSummary: String {
        let selectedCOEs = COEGlassPreference.selectedCOETypes
        if selectedCOEs.isEmpty || selectedCOEs.count == COEGlassType.allCases.count {
            return "All"
        }
        return selectedCOEs.map { String($0.rawValue) }.sorted().joined(separator: ", ")
    }

    private var manufacturerFilterSummary: String {
        if let data = UserDefaults.standard.data(forKey: "selectedManufacturerFilter"),
           let selectedManufacturers = try? JSONDecoder().decode(Set<String>.self, from: data),
           !selectedManufacturers.isEmpty {
            if selectedManufacturers.count <= 2 {
                return selectedManufacturers.sorted().joined(separator: ", ")
            }
            return "\(selectedManufacturers.count) selected"
        }
        return "All"
    }
}

#Preview {
    SuppliesSettingsView()
}
