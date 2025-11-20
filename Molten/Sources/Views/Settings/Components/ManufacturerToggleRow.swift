//
//  ManufacturerToggleRow.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct ManufacturerToggleRow: View {
    let manufacturer: String
    let isEnabled: Bool
    let service: ManufacturerFilterService
    let onToggle: (Bool) -> Void

    init(
        manufacturer: String,
        isEnabled: Bool,
        service: ManufacturerFilterService = AppDependencies.shared.manufacturerFilterService,
        onToggle: @escaping (Bool) -> Void
    ) {
        self.manufacturer = manufacturer
        self.isEnabled = isEnabled
        self.service = service
        self.onToggle = onToggle
    }

    private var displayText: String {
        let fullName = GlassManufacturers.fullName(for: manufacturer) ?? manufacturer
        return fullName
    }

    var body: some View {
        HStack {
            Text(displayText)

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
    }
}
