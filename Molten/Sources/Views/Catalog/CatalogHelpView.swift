//
//  CatalogHelpView.swift
//  Molten
//
//  Help sheet explaining how to use the Catalog
//

import SwiftUI

struct CatalogHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Browse the glass catalog to discover items from various manufacturers. Tap any item to view details or add it to your inventory.")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Section("Searching") {
                    HelpRow(
                        icon: "magnifyingglass",
                        title: "Search by name or SKU",
                        description: "Type in the search bar to find items by name, color, or SKU number"
                    )

                    HelpRow(
                        icon: "line.3.horizontal.decrease.circle",
                        title: "Filter by manufacturer",
                        description: "Tap the manufacturer chips to show only items from specific brands"
                    )

                    HelpRow(
                        icon: "tag",
                        title: "Filter by tags",
                        description: "Use tags to find items by category like 'transparent', 'opal', or 'striker'"
                    )
                }

                Section("Sorting") {
                    HelpRow(
                        icon: "arrow.up.arrow.down",
                        title: "Sort options",
                        description: "Tap the sort button to arrange items by name, SKU, manufacturer, or recently viewed"
                    )
                }

                Section("Adding to Inventory") {
                    HelpRow(
                        icon: "plus.circle",
                        title: "Add to inventory",
                        description: "Tap an item, then tap 'Add to Inventory' to track it in your collection"
                    )
                }
            }
            .navigationTitle("Catalog Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Help Row Component

struct HelpRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(DesignSystem.Colors.moltenOrange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CatalogHelpView()
}
