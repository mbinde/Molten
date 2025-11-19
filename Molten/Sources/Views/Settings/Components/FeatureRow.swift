//
//  FeatureRow.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct FeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundColor(Color.accentColor)

            Text(title)
        }
    }
}
