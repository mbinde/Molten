//
//  UsageRow.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct UsageRow: View {
    let icon: String
    let title: String
    let current: Int
    let limit: Int?

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundColor(Color.accentColor)

            Text(title)

            Spacer()

            if let limit = limit {
                Text("\(current) / \(limit)")
                    .foregroundColor(usageColor)
                    .font(.subheadline.bold())
            } else {
                Text("Unlimited")
                    .foregroundColor(.green)
                    .font(.subheadline.bold())
            }
        }
    }

    private var usagePercentage: Double {
        guard let limit = limit, limit > 0 else { return 0 }
        return Double(current) / Double(limit)
    }

    private var usageColor: Color {
        let percentage = usagePercentage
        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }
}
