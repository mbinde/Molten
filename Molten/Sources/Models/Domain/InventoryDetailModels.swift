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

/// Inventory consistency validation result
nonisolated struct InventoryConsistencyValidation {
    let stableId: String
    let isValid: Bool
    let errors: [String]
}
