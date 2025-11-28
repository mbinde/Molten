//
//  LabelCountCalculator.swift
//  Molten
//
//  Calculator for determining label counts based on inventory type
//  Handles the special case of weight-based types (frit, powder, enamel)
//  which need user input for label count rather than using quantity directly
//

import Foundation

/// Calculator for determining label counts based on inventory type
/// Handles the special case of weight-based types (frit, powder, enamel)
/// which need user input for label count rather than using quantity directly
struct LabelCountCalculator {

    /// Item that needs user input for label count
    struct WeightBasedItem: Identifiable {
        let item: CompleteInventoryItemModel
        let inventoryRecord: InventoryModel

        var id: String { "\(item.catalogItem.stable_id):\(inventoryRecord.type)" }
    }

    /// Calculate the number of labels for a single inventory item
    /// - Parameters:
    ///   - item: The inventory item
    ///   - userOverrides: Optional dictionary of user-specified label counts (key: "stableId:type")
    /// - Returns: Number of labels to print
    @MainActor
    static func calculateLabelCount(
        for item: CompleteInventoryItemModel,
        userOverrides: [String: Int] = [:]
    ) -> Int {
        var total = 0

        for inventory in item.inventory {
            let key = "\(item.catalogItem.stable_id):\(inventory.type)"

            // Check for user override first
            if let override = userOverrides[key] {
                total += override
                continue
            }

            if inventory.isWeightBasedType {
                // For weight-based types, use containerCount if available, otherwise default to 1
                if let containerCount = inventory.containerCount, containerCount > 0 {
                    total += Int(containerCount)
                } else {
                    total += 1  // Default to 1 label if no container count
                }
            } else {
                // For count-based types (rod, tube, sheet, etc.), use quantity directly
                total += Int(inventory.quantity)
            }
        }

        return max(total, 0)
    }

    /// Calculate total label count for multiple items
    @MainActor
    static func calculateTotalLabelCount(
        for items: [CompleteInventoryItemModel],
        userOverrides: [String: Int] = [:]
    ) -> Int {
        items.reduce(0) { total, item in
            total + calculateLabelCount(for: item, userOverrides: userOverrides)
        }
    }

    /// Get the list of items that need user input for label count
    /// These are weight-based items (frit, powder, enamel) without a containerCount set
    @MainActor
    static func itemsNeedingLabelCountInput(
        from items: [CompleteInventoryItemModel]
    ) -> [WeightBasedItem] {
        var result: [WeightBasedItem] = []

        for item in items {
            for inventory in item.inventory {
                if inventory.isWeightBasedType {
                    // Need input if containerCount is not set
                    if inventory.containerCount == nil || inventory.containerCount == 0 {
                        result.append(WeightBasedItem(item: item, inventoryRecord: inventory))
                    }
                }
            }
        }

        return result
    }

    /// Generate LabelData entries for items, with proper type info for QR codes
    /// Each label includes the inventory type/subtype/subsubtype for accurate QR encoding
    @MainActor
    static func generateLabelData(
        for items: [CompleteInventoryItemModel],
        userOverrides: [String: Int] = [:],
        location: String? = nil,
        owner: String? = nil
    ) -> [LabelData] {
        var labelData: [LabelData] = []

        for item in items {
            let glassItem = item.glassItem
            let itemLocation = item.locations.first ?? location

            for inventory in item.inventory {
                let key = "\(item.catalogItem.stable_id):\(inventory.type)"

                // Determine label count for this inventory record
                let labelCount: Int
                if let override = userOverrides[key] {
                    labelCount = override
                } else if inventory.isWeightBasedType {
                    if let containerCount = inventory.containerCount, containerCount > 0 {
                        labelCount = Int(containerCount)
                    } else {
                        labelCount = 1
                    }
                } else {
                    labelCount = Int(inventory.quantity)
                }

                // Create labels with type info
                for _ in 0..<labelCount {
                    labelData.append(LabelData(
                        stableId: glassItem.stable_id,
                        manufacturer: glassItem.manufacturer,
                        sku: glassItem.sku,
                        colorName: glassItem.name,
                        coe: "\(glassItem.coe)",
                        location: itemLocation,
                        owner: owner,
                        inventoryType: inventory.type,
                        inventorySubtype: inventory.subtype,
                        inventorySubsubtype: inventory.subsubtype
                    ))
                }
            }
        }

        return labelData
    }
}
