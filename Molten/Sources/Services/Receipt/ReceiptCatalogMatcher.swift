//
//  ReceiptCatalogMatcher.swift
//  Molten
//
//  Matches parsed receipt items to catalog entries using SKU codes and smart name matching.
//  Returns multiple ranked candidates for each item.
//

import Foundation

// Note: Uses MatchCandidate from ReceiptAPIClient.swift

/// Result of matching a single receipt item
public struct ItemMatchResult: Sendable {
    public let catalogStableId: String?
    public let confidence: Double
    public let matchMethod: String
    public let candidates: [MatchCandidate]
}

// MARK: - Matcher

/// Matches receipt items against the local catalog
public actor ReceiptCatalogMatcher {
    private let catalogService: CatalogService

    // MARK: - Static Configuration

    /// Manufacturer abbreviations and aliases
    private static let manufacturerAliases: [String: String] = [
        // Full names to codes
        "northstar": "NS",
        "north star": "NS",
        "northstar glassworks": "NS",
        "boro batch": "BB",
        "borobatch": "BB",
        "asian boro": "AB",
        "asianboro": "AB",
        "bullseye": "BE",
        "bullseye glass": "BE",
        "effetre": "EF",
        "moretti": "EF",
        "vetrofond": "VF",
        "glass alchemy": "GA",
        "glassalchemy": "GA",
        "creation is messy": "CIM",
        "creationismessy": "CIM",
        "double helix": "DH",
        "doublehelix": "DH",
        "trautman": "TAG",
        "trautman art glass": "TAG",
        "momka": "MOM",
        "momkas": "MOM",
        "momka's": "MOM",
        "kugler": "KUG",
        "gaffer": "GAF",
        "oceanside": "OC",
        "oceanside glass": "OC",
        "pdx tubing": "PDX",
        "pdx": "PDX",
        // Abbreviations
        "ns": "NS",
        "bb": "BB",
        "ab": "AB",
        "be": "BE",
        "ef": "EF",
        "ga": "GA",
        "dh": "DH",
        "tag": "TAG",
        "vf": "VF",
    ]

    /// Product type keywords
    private static let productTypeKeywords: [String: String] = [
        // Stringer indicators - check these first as they override rod
        "thins": "stringer",
        "thin": "stringer",
        "2mm": "stringer",
        "3mm": "stringer",
        "stringer": "stringer",
        "stringers": "stringer",
        // Other types
        "rod": "rod",
        "rods": "rod",
        "frit": "frit",
        "frits": "frit",
        "powder": "frit",
        "sheet": "sheet",
        "sheets": "sheet",
        "tube": "tube",
        "tubing": "tubing",
        "tubes": "tube",
        "bar": "bar",
        "bars": "bar",
        "billet": "billet",
        "billets": "billet",
    ]

    /// Frit subtype mappings (size indicators to mesh sizes)
    private static let fritSubtypeKeywords: [String: String] = [
        "(l)": "#25", "(s)": "#38", "(f)": "#70",
        "large": "#25", "small": "#38", "fine": "#70", "powder": "#100",
        "coarse": "#25", "medium": "#38",
        "#25": "#25", "#38": "#38", "#70": "#70", "#82": "#82", "#100": "#100",
    ]

    /// Maps retailer IDs to their primary manufacturers
    private static let retailerManufacturerMap: [String: [String]] = [
        "abr_imagery": ["BB", "NS", "AB"],
        "bullseye_glass": ["BE"],
        "momkas_glass": ["MOM"],
        "glass_alchemy": ["GA"],
        "rocky_mountain_glass": ["EF"],
        "mountain_glass": ["NS", "GA", "EF", "PDX", "TAG"],
        "frantz_art_glass": ["CIM", "EF", "VF"],
        "lampwork_supply": ["CIM", "EF", "NS", "TAG", "GA", "DH"],
        "artglass_supplies": ["BE"],
        "aaeglass": ["BE"],
    ]

    /// Generic glass-related words - these appear in most descriptions and shouldn't drive matching
    private static let genericWords: Set<String> = [
        // Product forms
        "glass", "rod", "rods", "frit", "sheet", "sheets", "tube", "tubing",
        "strips", "strip", "stringer", "stringers",
        // Generic modifiers
        "on", "transparent", "opaque", "opalescent", "the", "and", "with", "for",
        // Size/quantity words
        "large", "small", "medium", "fine", "coarse", "thin", "thick",
        // Edition/run markers - these describe availability, not the glass
        "ltd", "run", "limited", "edition", "special", "new", "exclusive",
        // Common glass descriptors that don't distinguish products
        "intense", "dark", "light", "bright", "soft", "deep", "rich", "pale"
    ]

    /// Category modifiers that indicate fundamentally different product types
    /// If receipt has "dichroic" but catalog doesn't, they're different products
    private static let categoryModifiers: Set<String> = [
        "dichroic", "reactive", "striking", "encased", "coated"
    ]

    /// Common color words - matching only these gives low confidence
    private static let colorWords: Set<String> = [
        "black", "white", "clear", "silver", "gold", "copper", "red", "blue",
        "green", "yellow", "orange", "purple", "pink", "brown", "grey", "gray",
        "teal", "amber", "ruby", "cobalt", "ivory", "cream", "turquoise"
    ]

    // MARK: - Initialization

    init(catalogService: CatalogService) {
        self.catalogService = catalogService
    }

    // MARK: - Public API

    /// Match all items in a receipt against the catalog
    public func matchItems(
        _ items: [ReceiptItem],
        retailerId: String
    ) async -> [Int: ItemMatchResult] {
        var results: [Int: ItemMatchResult] = [:]

        let manufacturers = Self.retailerManufacturerMap[retailerId] ?? []
        let catalogItems = await fetchCatalogItems(manufacturers: manufacturers)

        for item in items {
            let result = await matchSingleItem(
                item,
                relevantCatalog: catalogItems.relevant,
                fullCatalog: catalogItems.full
            )
            results[item.id] = result
        }

        return results
    }

    // MARK: - Private Methods

    private func fetchCatalogItems(manufacturers: [String]) async -> (relevant: [GlassItemModel], full: [GlassItemModel]) {
        let allItems = (try? await catalogService.getGlassItemsLightweight()) ?? []

        if manufacturers.isEmpty {
            return (allItems, allItems)
        }

        let relevant = allItems.filter { manufacturers.contains($0.manufacturer.uppercased()) }
        return (relevant.isEmpty ? allItems : relevant, allItems)
    }

    private func matchSingleItem(
        _ item: ReceiptItem,
        relevantCatalog: [GlassItemModel],
        fullCatalog: [GlassItemModel]
    ) async -> ItemMatchResult {
        var allCandidates: [MatchCandidate] = []

        let detectedProductType = detectProductType(item.rawName)
        let detectedSubtype = detectFritSubtype(item.rawName, productType: detectedProductType)

        // 1. SKU matching (highest confidence)
        if let sku = item.rawSku, !sku.isEmpty {
            let skuCandidates = matchBySku(sku, catalog: relevantCatalog + fullCatalog, productType: detectedProductType, subtype: detectedSubtype)
            allCandidates.append(contentsOf: skuCandidates)
        }

        // 2. Smart name matching (single unified algorithm)
        let nameCandidates = matchByName(item.rawName, relevantCatalog: relevantCatalog, fullCatalog: fullCatalog, productType: detectedProductType, subtype: detectedSubtype)
        allCandidates.append(contentsOf: nameCandidates)

        // Deduplicate and sort
        let uniqueCandidates = deduplicateCandidates(allCandidates)
        let sortedCandidates = uniqueCandidates.sorted { $0.confidence > $1.confidence }
        let topCandidates = Array(sortedCandidates.prefix(5))

        if let best = topCandidates.first, best.confidence >= 0.5 {
            return ItemMatchResult(
                catalogStableId: best.catalogStableId,
                confidence: best.confidence,
                matchMethod: best.matchMethod,
                candidates: topCandidates
            )
        }

        return ItemMatchResult(
            catalogStableId: nil,
            confidence: 0,
            matchMethod: "none",
            candidates: topCandidates
        )
    }

    // MARK: - Product Type Detection

    private func detectProductType(_ rawName: String) -> String {
        let name = rawName.lowercased()

        // Check stringers first (more specific)
        for indicator in ["2mm", "3mm", "thins", "thin", "stringer", "stringers"] {
            if Self.stringContainsWord(name, word: indicator) {
                return "stringer"
            }
        }

        // Check other types
        for (keyword, type) in Self.productTypeKeywords where type != "stringer" {
            if Self.stringContainsWord(name, word: keyword) {
                return type
            }
        }

        return "rod" // Default
    }

    private func detectFritSubtype(_ rawName: String, productType: String) -> String? {
        guard productType == "frit" else { return nil }

        let name = rawName.lowercased()
        let sortedKeywords = Self.fritSubtypeKeywords.sorted { $0.key.count > $1.key.count }

        for (keyword, subtype) in sortedKeywords {
            if keyword.hasPrefix("(") || keyword.hasPrefix("#") {
                if name.contains(keyword) { return subtype }
            } else if Self.stringContainsWord(name, word: keyword) {
                return subtype
            }
        }

        return nil
    }

    // MARK: - SKU Matching

    private func matchBySku(_ rawSku: String, catalog: [GlassItemModel], productType: String, subtype: String?) -> [MatchCandidate] {
        var candidates: [MatchCandidate] = []
        let upperSku = rawSku.uppercased()

        for item in catalog {
            guard let itemSku = item.sku else { continue }
            let upperItemSku = itemSku.uppercased()

            if upperItemSku == upperSku {
                candidates.append(MatchCandidate(
                    catalogStableId: item.stable_id,
                    catalogName: item.name,
                    catalogManufacturer: item.manufacturer,
                    catalogType: productType,
                    catalogSubtype: subtype,
                    confidence: 0.95,
                    matchMethod: "sku_exact",
                    matchDetails: "SKU: \(rawSku)"
                ))
            } else if upperItemSku.contains(upperSku) || upperSku.contains(upperItemSku) {
                candidates.append(MatchCandidate(
                    catalogStableId: item.stable_id,
                    catalogName: item.name,
                    catalogManufacturer: item.manufacturer,
                    catalogType: productType,
                    catalogSubtype: subtype,
                    confidence: 0.85,
                    matchMethod: "sku_partial",
                    matchDetails: "Partial SKU: \(rawSku)"
                ))
            }
        }

        return candidates
    }

    // MARK: - Name Matching (Unified Algorithm)

    /// Parsed receipt name with extracted components
    private struct ParsedName {
        let manufacturer: String?          // Detected manufacturer code (e.g., "EF")
        let categoryModifiers: Set<String> // e.g., {"dichroic"}
        let distinctiveWords: [String]     // Unique identifying words (e.g., "cherry", "crinkle")
        let colorWords: [String]           // Basic colors (e.g., "black", "silver")
        let allSignificantWords: [String]  // distinctiveWords + colorWords
    }

    private func parseName(_ rawName: String) -> ParsedName {
        var name = rawName.lowercased()
        var manufacturer: String?

        // Extract manufacturer
        let sortedAliases = Self.manufacturerAliases.sorted { $0.key.count > $1.key.count }
        for (alias, code) in sortedAliases {
            if Self.stringContainsWord(name, word: alias) {
                manufacturer = code
                name = Self.stringReplacingWord(name, word: alias, with: "")
                break
            }
        }

        // Remove product type words
        for keyword in Self.productTypeKeywords.keys {
            name = Self.stringReplacingWord(name, word: keyword, with: "")
        }

        // Extract words (min 3 chars)
        let words = name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.lowercased() }
            .filter { $0.count >= 3 }

        // Categorize words
        let categoryMods = Set(words.filter { Self.categoryModifiers.contains($0) })
        let colors = words.filter { Self.colorWords.contains($0) && !Self.categoryModifiers.contains($0) }
        let distinctive = words.filter {
            !Self.genericWords.contains($0) &&
            !Self.categoryModifiers.contains($0) &&
            !Self.colorWords.contains($0)
        }

        return ParsedName(
            manufacturer: manufacturer,
            categoryModifiers: categoryMods,
            distinctiveWords: distinctive,
            colorWords: colors,
            allSignificantWords: distinctive + colors
        )
    }

    private func matchByName(
        _ rawName: String,
        relevantCatalog: [GlassItemModel],
        fullCatalog: [GlassItemModel],
        productType: String,
        subtype: String?
    ) -> [MatchCandidate] {
        let receipt = parseName(rawName)
        var candidates: [MatchCandidate] = []

        // Determine search catalog
        var searchCatalog = relevantCatalog
        if let mfr = receipt.manufacturer {
            let filtered = fullCatalog.filter { $0.manufacturer.uppercased() == mfr }
            if !filtered.isEmpty {
                searchCatalog = filtered
            }
        }

        // Need at least some words to match
        guard !receipt.allSignificantWords.isEmpty else { return candidates }

        for catalogItem in searchCatalog {
            let catalog = parseName(catalogItem.name)

            // Rule 1: Category modifier mismatch = no match
            // "Dichroic X" cannot match "X" (non-dichroic)
            if !receipt.categoryModifiers.isEmpty && catalog.categoryModifiers.isEmpty {
                continue
            }
            if receipt.categoryModifiers.isEmpty && !catalog.categoryModifiers.isEmpty {
                continue
            }
            if !receipt.categoryModifiers.isEmpty && receipt.categoryModifiers != catalog.categoryModifiers {
                continue
            }

            // Rule 2: If receipt has distinctive words, at least one must match
            // "Black Cherry" matching "Black X" is wrong - "Cherry" must match something
            let distinctiveMatches = receipt.distinctiveWords.filter { catalog.allSignificantWords.contains($0) }
            if !receipt.distinctiveWords.isEmpty && distinctiveMatches.isEmpty {
                continue
            }

            // Rule 3: Count color matches
            let colorMatches = receipt.colorWords.filter { catalog.allSignificantWords.contains($0) }

            // Must have some match
            let totalMatches = distinctiveMatches.count + colorMatches.count
            guard totalMatches > 0 else { continue }

            // Rule 4: Calculate bilateral match ratios
            // How much of the receipt did we match?
            let receiptMatchRatio = Double(totalMatches) / Double(receipt.allSignificantWords.count)

            // How much of the catalog did we cover?
            let catalogDistinctiveMatches = catalog.distinctiveWords.filter { receipt.distinctiveWords.contains($0) }
            let catalogColorMatches = catalog.colorWords.filter { receipt.colorWords.contains($0) }
            let catalogTotalMatches = catalogDistinctiveMatches.count + catalogColorMatches.count
            let catalogMatchRatio = catalog.allSignificantWords.isEmpty ? 0.0 :
                Double(catalogTotalMatches) / Double(catalog.allSignificantWords.count)

            // Rule 5: Require reasonable coverage on BOTH sides
            // This prevents "Silver" matching "Silver #1" at high confidence
            // because the catalog has more content we didn't match
            guard receiptMatchRatio >= 0.5 else { continue }
            guard catalogMatchRatio >= 0.5 else { continue }

            // Calculate confidence score
            var confidence: Double

            if !receipt.distinctiveWords.isEmpty {
                // Have distinctive words - weight them heavily
                let distinctiveRatio = Double(distinctiveMatches.count) / Double(receipt.distinctiveWords.count)
                let colorRatio = receipt.colorWords.isEmpty ? 1.0 :
                    Double(colorMatches.count) / Double(receipt.colorWords.count)
                confidence = (distinctiveRatio * 0.6) + (colorRatio * 0.2) + (catalogMatchRatio * 0.2)
            } else {
                // Only colors - bilateral average
                confidence = (receiptMatchRatio + catalogMatchRatio) / 2.0
            }

            // Manufacturer match bonus
            if let mfr = receipt.manufacturer, catalogItem.manufacturer.uppercased() == mfr {
                confidence += 0.1
            }

            // Apply confidence caps based on match quality
            let onlyColorMatch = receipt.distinctiveWords.isEmpty && catalog.distinctiveWords.isEmpty

            if onlyColorMatch {
                // Color-only matches (e.g., "Silver" → "Silver #1") cap at 60%
                confidence = min(confidence, 0.60)
            } else if !distinctiveMatches.isEmpty &&
                      catalogDistinctiveMatches.count == catalog.distinctiveWords.count {
                // All distinctive words matched on both sides - high quality
                confidence = min(confidence, 0.90)
            } else {
                // Partial match
                confidence = min(confidence, 0.75)
            }

            // Final bounds
            confidence = min(max(confidence, 0), 1.0)

            if confidence >= 0.5 {
                let details = "Matched: \(distinctiveMatches.joined(separator: ", "))" +
                    (colorMatches.isEmpty ? "" : " + colors: \(colorMatches.joined(separator: ", "))")

                candidates.append(MatchCandidate(
                    catalogStableId: catalogItem.stable_id,
                    catalogName: catalogItem.name,
                    catalogManufacturer: catalogItem.manufacturer,
                    catalogType: productType,
                    catalogSubtype: subtype,
                    confidence: round(confidence * 100) / 100,
                    matchMethod: "name_match",
                    matchDetails: details
                ))
            }
        }

        return candidates
    }

    // MARK: - Helpers

    private func deduplicateCandidates(_ candidates: [MatchCandidate]) -> [MatchCandidate] {
        var seen: [String: MatchCandidate] = [:]

        for candidate in candidates {
            if let existing = seen[candidate.catalogStableId] {
                if candidate.confidence > existing.confidence {
                    seen[candidate.catalogStableId] = candidate
                }
            } else {
                seen[candidate.catalogStableId] = candidate
            }
        }

        return Array(seen.values)
    }
}

// MARK: - String Helpers

extension ReceiptCatalogMatcher {
    /// Check if string contains a word (with word boundaries)
    private nonisolated static func stringContainsWord(_ string: String, word: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        return regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil
    }

    /// Replace a word (with word boundaries)
    private nonisolated static func stringReplacingWord(_ string: String, word: String, with replacement: String) -> String {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return string
        }
        return regex.stringByReplacingMatches(in: string, range: NSRange(string.startIndex..., in: string), withTemplate: replacement)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
