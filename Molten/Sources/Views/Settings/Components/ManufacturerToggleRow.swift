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
    let onToggle: (Bool) -> Void
    @State private var internalIsEnabled: Bool = false

    private var displayText: String {
        let fullName = GlassManufacturers.fullName(for: manufacturer) ?? manufacturer
        return fullName
    }

    var body: some View {
        HStack {
            Text(displayText)

            Spacer()

            Toggle("", isOn: Binding(
                get: { internalIsEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .onAppear {
            internalIsEnabled = ManufacturerFilterService.shared.isManufacturerEnabled(manufacturer)
        }
        .onReceive(NotificationCenter.default.publisher(for: .manufacturerSelectionChanged)) { _ in
            internalIsEnabled = ManufacturerFilterService.shared.isManufacturerEnabled(manufacturer)
        }
    }
}
