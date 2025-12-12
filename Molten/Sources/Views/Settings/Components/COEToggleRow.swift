//
//  COEToggleRow.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct COEToggleRow: View {
    let coeType: COEGlassType
    @State private var isSelected: Bool = false

    var body: some View {
        HStack {
            Text(coeType.displayName)

            Spacer()

            Toggle("", isOn: $isSelected)
                .labelsHidden()
                .onChange(of: isSelected) { _, newValue in
                    if newValue {
                        COEGlassPreference.addCOEType(coeType)
                    } else {
                        COEGlassPreference.removeCOEType(coeType)
                    }
                }
                .accessibilityIdentifier("coe_toggle_\(coeType.displayName.lowercased().replacingOccurrences(of: " ", with: "_"))")
                .accessibilityLabel("Show \(coeType.displayName) glass")
                .accessibilityHint(isSelected ? "Double tap to hide \(coeType.displayName) glass from catalog" : "Double tap to show \(coeType.displayName) glass in catalog")
        }
        .onAppear {
            isSelected = COEGlassPreference.selectedCOETypes.contains(coeType)
        }
        .onReceive(NotificationCenter.default.publisher(for: .coeSelectionChanged)) { _ in
            isSelected = COEGlassPreference.selectedCOETypes.contains(coeType)
        }
    }
}
