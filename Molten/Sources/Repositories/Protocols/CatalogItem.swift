//
//  CatalogItem.swift
//  Molten
//
//  Protocol defining the common interface for all catalog item types
//  (glass items, coatings, tools)
//

import Foundation

/// Protocol for all catalog item types (glass, coatings, tools)
/// Defines the common properties shared across all catalog items
nonisolated protocol CatalogItem: Identifiable, Equatable, Hashable, Sendable where ID == String {
    /// Stable ID - PRIMARY KEY (6-character hash like "abc123")
    var stable_id: String { get }

    /// Item name
    var name: String { get }

    /// Manufacturer SKU (optional - some manufacturers don't use SKUs)
    var sku: String? { get }

    /// Manufacturer identifier (abbreviated, e.g., "be", "cim", "ef")
    var manufacturer: String { get }

    /// Manufacturer notes/description
    var mfr_notes: String? { get }

    /// Manufacturer URL
    var url: String? { get }

    /// URI for deep linking (e.g., "moltenglass:item?abc123")
    var uri: String { get }

    /// Manufacturer status (available, discontinued, etc.)
    var mfr_status: String { get }

    /// Image URL (external)
    var image_url: String? { get }

    /// Image path (local)
    var image_path: String? { get }
}
