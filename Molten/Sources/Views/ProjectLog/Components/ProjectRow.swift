//
//  ProjectRow.swift
//  Molten
//
//  Project list row component
//  Extracted from ProjectsView.swift - fixed tag loading anti-pattern
//  Tags are now passed as a parameter instead of loaded per-row
//

import SwiftUI

/// Row view for displaying a project in a list
/// Displays thumbnail, title, summary, creation date, and tags
struct ProjectRow: View {
    let plan: ProjectModel
    let tags: [String]

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Thumbnail on the left
            #if canImport(UIKit)
            ProjectThumbnail(
                heroImageId: plan.heroImageId,
                projectId: plan.id,
                projectCategory: .plan,
                size: 60
            )
            #endif

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.headline)

                if let summary = plan.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }

                HStack {
                    Text(plan.dateCreated, style: .date)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    if !tags.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text(tags.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
