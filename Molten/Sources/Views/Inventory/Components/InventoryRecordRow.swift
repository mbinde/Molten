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
            VStack(alignment: .leading, spacing: 4) {
                // Show type if requested (when grouped by location)
                if showType {
                    Text((record.type ?? "").capitalized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                // Show subtype if present
                if let subtype = record.subtype {
                    Text(subtype.capitalized)
                        .font(showType ? .caption : .subheadline)
                        .fontWeight(showType ? .regular : .medium)
                        .foregroundColor(showType ? .secondary : .primary)
                }

                // Show dimensions if present
                if let dimensions = record.dimensions, !dimensions.isEmpty {
                    Text(GlassItemTypeSystem.formatDimensions(dimensions, for: record.type ?? ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Show location if requested (when grouped by type)
                if showLocation, let location = record.location {
                    Text("📍 \(location)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(record.formattedQuantityDisplay())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
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
                .accessibilityIdentifier("inventory_record_delete")
            }
        } else {
            content
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityIdentifier("inventory_record_delete")
                }
        }
    }
}
