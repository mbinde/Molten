import Foundation

// Adapter type for search-specific needs derived from glass item information
struct SearchItemInfo {
    let name: String
    let naturalKey: String
    let sku: String
    let manufacturerShort: String
    let manufacturerFull: String
    let tags: [String]
    let coe: Int32
    let url: String?
}

/// Create a SearchItemInfo derived from a GlassItemModel using business models
private func makeSearchItemInfo(from item: GlassItemModel, tags: [String] = []) -> SearchItemInfo {
    return SearchItemInfo(
        name: item.name,
        naturalKey: item.natural_key,
        sku: item.sku,
        manufacturerShort: item.manufacturer,
        manufacturerFull: item.manufacturer,
        tags: tags,
        coe: item.coe,
        url: item.url
    )
}

struct InventorySearchSuggestions {
    /// Returns filtered glass items as suggestions for the given query and inventory items using business models.
    /// - Parameters:
    ///   - query: The search string input by the user.
    ///   - inventoryModels: Array of InventoryModel currently in the inventory.
    ///   - completeItems: Array of all CompleteInventoryItemModel to filter from.
    /// - Returns: Array of CompleteInventoryItemModel matching the query and not excluded by inventory.
    static func suggestedGlassItems(
        query: String,
        inventoryModels: [InventoryModel],
        completeItems: [CompleteInventoryItemModel]
    ) -> [CompleteInventoryItemModel] {
        let normalizedQuery = query.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return []
        }

        // Build exclusion sets from inventory items to avoid suggesting duplicates
        var excludedKeys = Set<String>()
        for inventoryModel in inventoryModels {
            // Exclude the item natural key
            let naturalKey = inventoryModel.item_natural_key.lowercased()
            if !naturalKey.isEmpty {
                excludedKeys.insert(naturalKey)
            }
        }

        func isExcluded(_ item: SearchItemInfo) -> Bool {
            let naturalKey = item.naturalKey.lowercased()
            if excludedKeys.contains(naturalKey) {
                return true
            }
            return false
        }

        func matchesQuery(_ query: String, item: SearchItemInfo) -> Bool {
            let terms = SearchUtilities.parseSearchTerms(query)
            guard !terms.isEmpty else { return false }
            
            // Build a list of searchable fields (lowercased) for this item
            let fieldsLower: [String] = {
                var f: [String] = []
                f.append(item.name)
                f.append(item.naturalKey)
                f.append(item.sku)
                f.append(item.manufacturerShort)
                f.append(item.manufacturerFull)
                f.append(contentsOf: item.tags)
                f.append(String(item.coe))
                if let url = item.url {
                    f.append(url)
                }
                return f.map { $0.lowercased() }
            }()
            
            // AND logic: all terms must be found in at least one field
            return terms.allSatisfy { term in
                fieldsLower.contains { $0.contains(term) }
            }
        }

        var results: [CompleteInventoryItemModel] = []
        for completeItem in completeItems {
            let displayInfo = makeSearchItemInfo(from: completeItem.glassItem, tags: completeItem.tags)
            if isExcluded(displayInfo) {
                continue
            }
            if matchesQuery(normalizedQuery, item: displayInfo) {
                results.append(completeItem)
            }
        }
        return results
    }
    
    /// Legacy method for backward compatibility
    /// - Parameters:
    ///   - query: The search string input by the user.
    ///   - inventoryItems: Legacy inventory items (not used).
    ///   - catalogItems: Legacy catalog items (not used).
    /// - Returns: Empty array for deprecated method.
    @available(*, deprecated, message: "Use suggestedGlassItems instead")
    static func suggestedCatalogItems(
        query: String,
        inventoryItems: [Any],
        catalogItems: [Any]
    ) -> [Any] {
        return [] // Return empty array for deprecated method
    }
}

