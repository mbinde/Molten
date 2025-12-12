//
//  InventoryHelpView.swift
//  Molten
//
//  Help sheet explaining how to use Inventory
//

import SwiftUI

struct InventoryHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Track your glass inventory, see what you have in stock, and manage your collection across multiple storage locations.")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Section("Managing Inventory") {
                    HelpRow(
                        icon: "plus.circle",
                        title: "Add inventory",
                        description: "Tap the + button to add glass from the catalog to your inventory"
                    )

                    HelpRow(
                        icon: "camera",
                        title: "Scan QR codes",
                        description: "Scan printed QR labels to quickly find or add items"
                    )

                    HelpRow(
                        icon: "location",
                        title: "Storage locations",
                        description: "Organize items by where they're stored - different drawers, bins, or shelves"
                    )
                }

                Section("Finding Items") {
                    HelpRow(
                        icon: "magnifyingglass",
                        title: "Search",
                        description: "Search by name, color, or manufacturer to find items quickly"
                    )

                    HelpRow(
                        icon: "arrow.up.arrow.down",
                        title: "Sort options",
                        description: "Sort by name, total quantity, manufacturer, or date added"
                    )

                    HelpRow(
                        icon: "line.3.horizontal.decrease.circle",
                        title: "Filter",
                        description: "Filter by manufacturer, COE, tags, or storage location"
                    )
                }

                Section("Sharing & Labels") {
                    HelpRow(
                        icon: "person.2",
                        title: "Inventory sharing",
                        description: "Share your inventory with others or sync across devices"
                    )

                    HelpRow(
                        icon: "qrcode",
                        title: "Print labels",
                        description: "Generate QR code labels to attach to your storage containers"
                    )
                }
            }
            .navigationTitle("Inventory Help")
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

#Preview {
    InventoryHelpView()
}
