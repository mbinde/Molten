//
//  InventoryDetailModels.swift
//  Molten
//
//  Created by Architecture Refactoring on 2025-11-08.
//  Moved from InventoryTrackingService.swift to Domain layer
//

import Foundation

// MARK: - Inventory Detail Domain Models

/// Low stock item with contextual information
nonisolated struct LowStockDetailModel {
    let glassItem: GlassItemModel
    let type: String
    let currentQuantity: Double
    let threshold: Double
    let tags: [String]

    nonisolated var shortfall: Double {
        threshold - currentQuantity
    }
}

// MARK: - Sorting Logic (Business Rules)

extension LowStockDetailModel: Comparable {
    /// Sort low stock items by currentQuantity (ascending)
    /// Business rule: Items with lowest stock should appear first (highest priority)
    static func < (lhs: LowStockDetailModel, rhs: LowStockDetailModel) -> Bool {
        lhs.currentQuantity < rhs.currentQuantity
    }

    static func == (lhs: LowStockDetailModel, rhs: LowStockDetailModel) -> Bool {
        lhs.glassItem.stable_id == rhs.glassItem.stable_id && lhs.type == rhs.type
    }
}

/// Inventory consistency validation result
nonisolated struct InventoryConsistencyValidation {
    let stableId: String
    let isValid: Bool
    let errors: [String]
}
