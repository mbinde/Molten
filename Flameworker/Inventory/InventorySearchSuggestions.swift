import Foundation
import CoreData

// Adapter type for search-specific needs derived from the authoritative CatalogItemHelpers
struct SearchItemInfo {
    let name: String
    let baseCode: String
    let manufacturerShort: String
    let manufacturerFull: String
    let tags: [String]
    let synonyms: [String]
}

/// Create a SearchItemInfo derived from the unified CatalogItemHelpers.getItemDisplayInfo
private func makeSearchItemInfo(from item: CatalogItem) -> SearchItemInfo {
    let unified = CatalogItemHelpers.getItemDisplayInfo(item)
    // Derive a short manufacturer code from the full name when possible; fall back to the item's raw manufacturer or unified.manufacturer
    let short = GlassManufacturers.code(for: unified.manufacturerFullName) ?? (item.manufacturer ?? unified.manufacturer)
    return SearchItemInfo(
        name: unified.name,
        baseCode: unified.code,
        manufacturerShort: short,
        manufacturerFull: unified.manufacturerFullName,
        tags: unified.tags,
        synonyms: unified.synonyms
    )
}

public struct InventorySearchSuggestions {
    /// Returns filtered catalog items as suggestions for the given query and inventory items.
    /// - Parameters:
    ///   - query: The search string input by the user.
    ///   - inventoryItems: Array of InventoryItem currently in the inventory.
    ///   - catalogItems: Array of all CatalogItem to filter from.
    /// - Returns: Array of CatalogItem matching the query and not excluded by inventory.
    public static func suggestedCatalogItems(
        query: String,
        inventoryItems: [InventoryItem],
        catalogItems: [CatalogItem]
    ) -> [CatalogItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return []
        }

        // Build exclusion sets from inventory items to avoid suggesting duplicates
        var excludedKeys = Set<String>()
        for inventoryItem in inventoryItems {
            // Exclude any stored catalog code (may be base or manufacturer-prefixed) and the item id
            if let code = inventoryItem.catalog_code?.lowercased(), !code.isEmpty {
                excludedKeys.insert(code)
            }
            if let id = inventoryItem.id?.lowercased(), !id.isEmpty {
                excludedKeys.insert(id)
            }
        }

        func isExcluded(_ item: SearchItemInfo) -> Bool {
            let baseCode = item.baseCode.lowercased()
            if excludedKeys.contains(baseCode) {
                return true
            }
            let prefixedCode1 = "\(item.manufacturerShort.lowercased())-\(baseCode)"
            if excludedKeys.contains(prefixedCode1) {
                return true
            }
            let prefixedCode2 = "\(item.manufacturerFull.lowercased())-\(baseCode)"
            if excludedKeys.contains(prefixedCode2) {
                return true
            }
            return false
        }

        func matchesQuery(_ query: String, item: SearchItemInfo, itemId: String) -> Bool {
            let lowerQuery = query.lowercased()
            if item.name.lowercased().contains(lowerQuery) { return true }
            if item.baseCode.lowercased().contains(lowerQuery) { return true }
            if item.manufacturerShort.lowercased().contains(lowerQuery) { return true }
            if item.manufacturerFull.lowercased().contains(lowerQuery) { return true }
            if item.tags.contains(where: { $0.lowercased().contains(lowerQuery) }) { return true }
            if item.synonyms.contains(where: { $0.lowercased().contains(lowerQuery) }) { return true }
            if itemId.lowercased().contains(lowerQuery) { return true }
            let prefixedCode1 = "\(item.manufacturerShort.lowercased())-\(item.baseCode.lowercased())"
            if prefixedCode1.contains(lowerQuery) { return true }
            let prefixedCode2 = "\(item.manufacturerFull.lowercased())-\(item.baseCode.lowercased())"
            if prefixedCode2.contains(lowerQuery) { return true }
            if item.baseCode.lowercased().hasPrefix(lowerQuery) { return true }
            return false
        }

        var results: [CatalogItem] = []
        for catalogItem in catalogItems {
            let displayInfo = makeSearchItemInfo(from: catalogItem)
            if isExcluded(displayInfo) {
                continue
            }
            if matchesQuery(normalizedQuery, item: displayInfo, itemId: (catalogItem.id ?? "")) {
                results.append(catalogItem)
            }
        }
        return results
    }
}

