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
            let terms = SearchUtilities.parseSearchTerms(query)
            guard !terms.isEmpty else { return false }
            
            // Build a list of searchable fields (lowercased) for this item
            let fieldsLower: [String] = {
                var f: [String] = []
                f.append(item.name)
                f.append(item.baseCode)
                f.append(item.manufacturerShort)
                f.append(item.manufacturerFull)
                f.append(contentsOf: item.tags)
                f.append(contentsOf: item.synonyms)
                f.append(itemId)
                // Include manufacturer-prefixed variants
                f.append("\(item.manufacturerShort.lowercased())-\(item.baseCode.lowercased())")
                f.append("\(item.manufacturerFull.lowercased())-\(item.baseCode.lowercased())")
                return f.map { $0.lowercased() }
            }()
            
            // AND logic: all terms must be found in at least one field
            return terms.allSatisfy { term in
                fieldsLower.contains { $0.contains(term) }
            }
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

