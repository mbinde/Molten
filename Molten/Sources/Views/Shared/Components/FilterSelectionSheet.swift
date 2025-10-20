//
//  FilterSelectionSheet.swift
//  Flameworker
//
//  Created by Assistant on 10/19/25.
//  Generic filter selection sheet for consistent filter UI across the app
//

import SwiftUI

/// Generic filter selection sheet that supports multiple selection with optional counts
/// Replaces TagSelectionSheet, COESelectionSheet, and ManufacturerSelectionSheet
struct FilterSelectionSheet<Item: Hashable>: View {
    let title: String
    let items: [Item]
    @Binding var selectedItems: Set<Item>
    let itemCounts: [Item: Int]?
    let itemDisplayText: (Item) -> String
    let leadingAccessory: ((Item) -> AnyView)?
    let trailingAccessory: ((Item) -> AnyView)?

    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        items: [Item],
        selectedItems: Binding<Set<Item>>,
        itemCounts: [Item: Int]? = nil,
        itemDisplayText: @escaping (Item) -> String,
        leadingAccessory: ((Item) -> AnyView)? = nil,
        trailingAccessory: ((Item) -> AnyView)? = nil
    ) {
        self.title = title
        self.items = items
        self._selectedItems = selectedItems
        self.itemCounts = itemCounts
        self.itemDisplayText = itemDisplayText
        self.leadingAccessory = leadingAccessory
        self.trailingAccessory = trailingAccessory
    }

    var body: some View {
        NavigationView {
            List {
                // Clear All button as first item
                if !selectedItems.isEmpty {
                    Button(action: {
                        selectedItems.removeAll()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red)
                            Text("Clear All")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }

                // Item list
                ForEach(items, id: \.self) { item in
                    Button(action: {
                        if selectedItems.contains(item) {
                            selectedItems.remove(item)
                        } else {
                            selectedItems.insert(item)
                        }
                    }) {
                        HStack(spacing: 8) {
                            // Optional leading accessory (e.g., color circles for tags)
                            if let accessory = leadingAccessory {
                                accessory(item)
                            }

                            // Item name with optional count
                            if let count = itemCounts?[item] {
                                Text("\(itemDisplayText(item)) (\(count))")
                                    .foregroundColor(.primary)
                            } else {
                                Text(itemDisplayText(item))
                                    .foregroundColor(.primary)
                            }

                            Spacer()

                            // Optional trailing accessory (e.g., user tag indicators)
                            if let accessory = trailingAccessory {
                                accessory(item)
                            }

                            // Checkmark for selected items
                            if selectedItems.contains(item) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension FilterSelectionSheet where Item == String {
    /// Tag filter selection with color circles
    static func tags(
        availableTags: [String],
        selectedTags: Binding<Set<String>>,
        userTags: Set<String> = [],
        itemCounts: [String: Int]? = nil
    ) -> FilterSelectionSheet<String> {
        FilterSelectionSheet(
            title: "Select Tags",
            items: availableTags,
            selectedItems: selectedTags,
            itemCounts: itemCounts,
            itemDisplayText: { tag in tag },
            leadingAccessory: { tag in
                AnyView(TagColorCircle(tag: tag, size: 12))
            },
            trailingAccessory: { tag in
                if userTags.contains(tag) {
                    return AnyView(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                    )
                }
                return AnyView(EmptyView())
            }
        )
    }

    /// Manufacturer filter selection with display name mapping
    static func manufacturers(
        availableManufacturers: [String],
        selectedManufacturers: Binding<Set<String>>,
        manufacturerDisplayName: @escaping (String) -> String,
        itemCounts: [String: Int]? = nil
    ) -> FilterSelectionSheet<String> {
        FilterSelectionSheet(
            title: "Select Manufacturers",
            items: availableManufacturers,
            selectedItems: selectedManufacturers,
            itemCounts: itemCounts,
            itemDisplayText: manufacturerDisplayName
        )
    }

    /// Store filter selection (for shopping lists)
    static func stores(
        availableStores: [String],
        selectedStores: Binding<Set<String>>,
        itemCounts: [String: Int]? = nil
    ) -> FilterSelectionSheet<String> {
        FilterSelectionSheet(
            title: "Select Stores",
            items: availableStores,
            selectedItems: selectedStores,
            itemCounts: itemCounts,
            itemDisplayText: { store in store }
        )
    }
}

extension FilterSelectionSheet where Item == Int32 {
    /// COE filter selection
    static func coes(
        availableCOEs: [Int32],
        selectedCOEs: Binding<Set<Int32>>,
        itemCounts: [Int32: Int]? = nil
    ) -> FilterSelectionSheet<Int32> {
        FilterSelectionSheet(
            title: "Select COE",
            items: availableCOEs.sorted(),
            selectedItems: selectedCOEs,
            itemCounts: itemCounts,
            itemDisplayText: { coe in "COE \(coe)" }
        )
    }
}

// MARK: - Preview

#Preview("Tag Selection") {
    @Previewable @State var selectedTags: Set<String> = ["clear", "transparent"]

    return FilterSelectionSheet.tags(
        availableTags: ["clear", "opaque", "transparent", "blue", "red"],
        selectedTags: $selectedTags,
        userTags: ["transparent"],
        itemCounts: ["clear": 15, "opaque": 8, "transparent": 23, "blue": 5, "red": 12]
    )
}

#Preview("COE Selection") {
    @Previewable @State var selectedCOEs: Set<Int32> = [104]

    return FilterSelectionSheet.coes(
        availableCOEs: [90, 96, 104],
        selectedCOEs: $selectedCOEs,
        itemCounts: [90: 5, 96: 12, 104: 45]
    )
}

#Preview("Manufacturer Selection") {
    @Previewable @State var selectedManufacturers: Set<String> = ["be"]

    return FilterSelectionSheet.manufacturers(
        availableManufacturers: ["be", "cim", "ef", "ga"],
        selectedManufacturers: $selectedManufacturers,
        manufacturerDisplayName: { code in
            switch code {
            case "be": return "Bullseye Glass Co"
            case "cim": return "Creation is Messy"
            case "ef": return "Effetre"
            case "ga": return "Glass Alchemy"
            default: return code.uppercased()
            }
        },
        itemCounts: ["be": 34, "cim": 18, "ef": 9, "ga": 6]
    )
}
