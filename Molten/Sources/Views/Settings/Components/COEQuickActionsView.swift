//
//  COEQuickActionsView.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct COEQuickActionsView: View {
    @State private var selectedCount: Int = 0

    var body: some View {
        HStack {
            Button("Select All") {
                let allTypes = Set(COEGlassType.allCases)
                COEGlassPreference.setSelectedCOETypes(allTypes)
                NotificationCenter.default.post(name: .coeSelectionChanged, object: nil)
            }
            .buttonStyle(.bordered)
            .disabled(selectedCount == COEGlassType.allCases.count)

            Spacer()

            Button("Select None") {
                COEGlassPreference.setSelectedCOETypes(Set())
                NotificationCenter.default.post(name: .coeSelectionChanged, object: nil)
            }
            .buttonStyle(.bordered)
            .disabled(selectedCount == 0)
        }
        .padding(.top, 8)
        .onAppear {
            selectedCount = COEGlassPreference.selectedCOETypes.count
        }
        .onReceive(NotificationCenter.default.publisher(for: .coeSelectionChanged)) { _ in
            selectedCount = COEGlassPreference.selectedCOETypes.count
        }
    }
}
