//
//  COEFilterView.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct COEFilterView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note: COE (Coefficient of Expansion) filtering works alongside the manufacturer filter. Both filters must match for items to appear in the catalog.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                // Quick actions for all COE types
                COEQuickActionsView()

                if SettingsViewHelpers.shouldShowCOEFilterSection() {
                    ForEach(COEGlassType.allCases, id: \.self) { coeType in
                        COEToggleRow(coeType: coeType)
                    }

                } else {
                    Text("COE filtering is not available")
                        .foregroundColor(.secondary)
                }
            } footer: {
                if SettingsViewHelpers.shouldShowCOEFilterSection() {
                    COESelectionFooter()
                } else {
                    Text("COE glass filtering feature is currently disabled.")
                }
            }
        }
        .navigationTitle("COE Filter")
    }
}
