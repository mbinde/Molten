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
    @State private var selectedCount: Int = 0

    var body: some View {
        HStack {
            Button("Select All") {
                let allManufacturerSet = Set(allManufacturers)
                ManufacturerFilterPreference.setSelectedManufacturers(allManufacturerSet)
                localEnabledManufacturers = allManufacturerSet
            }
            .buttonStyle(.bordered)
            .disabled(selectedCount == allManufacturers.count)

            Spacer()

            Button("Select None") {
                ManufacturerFilterPreference.setSelectedManufacturers(Set())
                localEnabledManufacturers.removeAll()
            }
            .buttonStyle(.bordered)
            .disabled(selectedCount == 0)
        }
        .padding(.top, 8)
        .onAppear {
            selectedCount = ManufacturerFilterService.shared.enabledManufacturers.count
        }
        .onReceive(NotificationCenter.default.publisher(for: .manufacturerSelectionChanged)) { _ in
            selectedCount = ManufacturerFilterService.shared.enabledManufacturers.count
        }
    }
}
