//
//  InventoryRecordRow.swift
//  Molten
//
//  Row showing a single inventory record with edit/delete options
//

import SwiftUI

/// Row showing a single inventory record with edit/delete options
struct InventoryRecordRow: View {
    let record: InventoryModel
    let onDelete: () -> Void
    var showType: Bool = false  // Show type when grouped by location
    var showLocation: Bool = false  // Show location when grouped by type
    var onTap: (() -> Void)? = nil  // Optional tap handler for editing

    var body: some View {
        let content = HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Show type if requested (when grouped by location)
                if showType {
                    Text((record.type ?? "").capitalized)
                        .font(DesignSystem.Typography.formLabel)
                        .fontWeight(DesignSystem.FontWeight.semibold)
                }

                // Show subtype if present
                if let subtype = record.subtype {
                    Text(subtype.capitalized)
                        .font(showType ? DesignSystem.Typography.listItemCaption : DesignSystem.Typography.formLabel)
                        .fontWeight(showType ? .regular : DesignSystem.FontWeight.medium)
                        .foregroundColor(showType ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                }

                // Show dimensions if present
                if let dimensions = record.dimensions, !dimensions.isEmpty {
                    Text(GlassItemTypeSystem.formatDimensions(dimensions, for: record.type ?? ""))
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Show location if requested (when grouped by type)
                if showLocation, let location = record.location {
                    Text("📍 \(location)")
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            Text(record.formattedQuantityDisplay())
                .font(DesignSystem.Typography.prominentNumberSmall)
                .fontWeight(DesignSystem.FontWeight.semibold)
                .foregroundColor(DesignSystem.Colors.moltenTeal)
        }

        if let onTap = onTap {
            Button(action: onTap) {
                content
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            content
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }
}
