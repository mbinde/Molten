//
//  ExpandableSection.swift
//  Molten
//
//  Reusable expandable section component with animation
//

import SwiftUI

/// Expandable section with animation
struct ExpandableSection<Content: View>: View {
    let title: String
    let systemImage: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: systemImage)
                        .foregroundColor(.accentColor)
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .transition(.opacity.combined(with: .slide))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}
