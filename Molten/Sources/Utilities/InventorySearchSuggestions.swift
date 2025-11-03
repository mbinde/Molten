import Foundation

// Adapter type for search-specific needs derived from glass item information
struct SearchItemInfo {
    let name: String
    let stableId: String
    let sku: String
    let manufacturerShort: String
    let manufacturerFull: String
    let tags: [String]
    let coe: Int32
    let url: String?
}

/// Create a SearchItemInfo derived from a GlassItemModel using business models
nonisolated private func makeSearchItemInfo(from item: GlassItemModel, tags: [String] = []) -> SearchItemInfo {
    return SearchItemInfo(
        name: item.name,
        stableId: item.stable_id,
        sku: item.sku ?? "",  // Use empty string if no SKU
        manufacturerShort: item.manufacturer,
        manufacturerFull: item.manufacturer,
        tags: tags,
        coe: item.coe,
        url: item.url
    )
}

nonisolated struct InventorySearchSuggestions {
    /// Returns filtered glass items as suggestions for the given query and inventory items using business models.
    /// - Parameters:
    ///   - query: The search string input by the user.
    ///   - inventoryModels: Array of InventoryModel currently in the inventory.
    ///   - completeItems: Array of all CompleteInventoryItemModel to filter from.
    /// - Returns: Array of CompleteInventoryItemModel matching the query and not excluded by inventory.
    nonisolated static func suggestedGlassItems(
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
            // Exclude the item stable_id (case-sensitive hash)
            let stableId = inventoryModel.item_stable_id
            if !stableId.isEmpty {
                excludedKeys.insert(stableId)
            }
        }

        func isExcluded(_ item: SearchItemInfo) -> Bool {
            let stableId = item.stableId
            if excludedKeys.contains(stableId) {
                return true
            }
            return false
        }

        func matchesQuery(_ query: String, item: SearchItemInfo) -> Bool {
            let terms = SearchUtilities.parseSearchTerms(query)
            guard !terms.isEmpty else { return false }

            // Build a list of searchable fields (lowercased for case-insensitive search)
            let fieldsLower: [String] = {
                var f: [String] = []
                f.append(item.name.lowercased())
                f.append(item.sku.lowercased())
                f.append(item.manufacturerShort.lowercased())
                f.append(item.manufacturerFull.lowercased())
                f.append(contentsOf: item.tags.map { $0.lowercased() })
                f.append(String(item.coe))
                if let url = item.url {
                    f.append(url.lowercased())
                }
                return f
            }()

            // stable_id is case-sensitive and searched separately
            let stableIdMatches = terms.allSatisfy { term in
                item.stableId.contains(term)
            }

            // Case-insensitive search on other fields
            let fieldsMatch = terms.allSatisfy { term in
                fieldsLower.contains { $0.contains(term) }
            }

            // Match if either stable_id matches OR other fields match
            return stableIdMatches || fieldsMatch
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
    
    // DEAD CODE (2025-11-02): Deprecated legacy method, always returns empty array. Safe to remove.
    /*
    /// Legacy method for backward compatibility
    /// - Parameters:
    ///   - query: The search string input by the user.
    ///   - inventoryItems: Legacy inventory items (not used).
    ///   - catalogItems: Legacy catalog items (not used).
    /// - Returns: Empty array for deprecated method.
    @available(*, deprecated, message: "Use suggestedGlassItems instead")
    nonisolated static func suggestedCatalogItems(
        query: String,
        inventoryItems: [Any],
        catalogItems: [Any]
    ) -> [Any] {
        return [] // Return empty array for deprecated method
    }
    */
}

