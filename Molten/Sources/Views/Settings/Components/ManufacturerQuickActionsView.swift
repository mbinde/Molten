//
//  ManufacturerQuickActionsView.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct ManufacturerQuickActionsView: View {
    let allManufacturers: [String]
    @Binding var localEnabledManufacturers: Set<String>
    let service: ManufacturerFilterService

    init(
        allManufacturers: [String],
        localEnabledManufacturers: Binding<Set<String>>,
        service: ManufacturerFilterService = AppDependencies.shared.manufacturerFilterService
    ) {
        self.allManufacturers = allManufacturers
        self._localEnabledManufacturers = localEnabledManufacturers
        self.service = service
    }

    var body: some View {
        HStack {
            Button("Select All") {
                Task {
                    await service.selectAll()
                    await MainActor.run {
                        localEnabledManufacturers = Set(allManufacturers)
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(localEnabledManufacturers.count == allManufacturers.count)
            .accessibilityIdentifier("manufacturer_quick_actions_select_all")

            Spacer()

            Button("Select None") {
                Task {
                    await service.selectNone()
                    await MainActor.run {
                        localEnabledManufacturers.removeAll()
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(localEnabledManufacturers.isEmpty)
            .accessibilityIdentifier("manufacturer_quick_actions_select_none")
        }
        .padding(.top, 8)
    }
}
