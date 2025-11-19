//
//  COESelectionFooter.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct COESelectionFooter: View {
    @State private var selectedCount: Int = 0

    var body: some View {
        let totalCount = COEGlassType.allCases.count
        let footerText = "\(SettingsViewHelpers.coeFilterSectionFooter) \(selectedCount) of \(totalCount) COE types selected."
        Text(footerText)
            .onAppear {
                selectedCount = COEGlassPreference.selectedCOETypes.count
            }
            .onReceive(NotificationCenter.default.publisher(for: .coeSelectionChanged)) { _ in
                selectedCount = COEGlassPreference.selectedCOETypes.count
            }
    }
}
