//
//  ReceiptCatalogMatcher.swift
//  Molten
//
//  Matches parsed receipt items to catalog entries using SKU codes and fuzzy name matching.
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
    /// Note: Order matters - more specific matches (like "2mm", "3mm") should be checked
    /// before generic ones (like "rod") to ensure correct type detection
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
    /// NorthStar convention: (L)arge=#25, (S)mall=#38, (F)ine=#70, powder=#100
    /// Also supports: coarse=#25, medium=#38, fine=#70
    private static let fritSubtypeKeywords: [String: String] = [
        // NorthStar parenthetical notation
        "(l)": "#25",
        "(s)": "#38",
        "(f)": "#70",
        // Full words
        "large": "#25",
        "small": "#38",
        "fine": "#70",
        "powder": "#100",
        // Alternative names
        "coarse": "#25",
        "medium": "#38",
        // Direct mesh sizes
        "#25": "#25",
        "#38": "#38",
        "#70": "#70",
        "#82": "#82",
        "#100": "#100",
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

    init(catalogService: CatalogService) {
        self.catalogService = catalogService
    }

    /// Match all items in a receipt against the catalog
    public func matchItems(
        _ items: [ReceiptItem],
        retailerId: String
    ) async -> [Int: ItemMatchResult] {
        var results: [Int: ItemMatchResult] = [:]

        // Get likely manufacturers for this retailer
        let manufacturers = Self.retailerManufacturerMap[retailerId] ?? []

        // Fetch catalog items for matching
        let catalogItems = await fetchCatalogItems(manufacturers: manufacturers)

        for item in items {
            let result = await matchSingleItem(
                item,
                retailerId: retailerId,
                relevantCatalog: catalogItems.relevant,
                fullCatalog: catalogItems.full
            )
            results[item.id] = result
        }

        return results
    }

    // MARK: - Private Methods

    private func fetchCatalogItems(manufacturers: [String]) async -> (relevant: [GlassItemModel], full: [GlassItemModel]) {
        // Fetch all items using the lightweight method
        let allItems = (try? await catalogService.getGlassItemsLightweight()) ?? []

        if manufacturers.isEmpty {
            return (allItems, allItems)
        }

        let relevant = allItems.filter { manufacturers.contains($0.manufacturer.uppercased()) }
        return (relevant.isEmpty ? allItems : relevant, allItems)
    }

    private func matchSingleItem(
        _ item: ReceiptItem,
        retailerId: String,
        relevantCatalog: [GlassItemModel],
        fullCatalog: [GlassItemModel]
    ) async -> ItemMatchResult {
        var allCandidates: [MatchCandidate] = []

        // First, detect the product type from the receipt line (rod, frit, sheet, etc.)
        let detectedProductType = detectProductType(item.rawName)

        // Detect subtype (e.g., frit mesh size like #38 for "Small")
        let detectedSubtype = detectFritSubtype(item.rawName, productType: detectedProductType)

        // 1. Try SKU-based matching first (highest confidence)
        if let sku = item.rawSku, !sku.isEmpty {
            let skuCandidates = matchBySku(sku, retailerId: retailerId, catalog: relevantCatalog + fullCatalog, productType: detectedProductType, subtype: detectedSubtype)
            allCandidates.append(contentsOf: skuCandidates)
        }

        // 2. Try exact name match
        let exactNameCandidates = matchByExactName(item.rawName, catalog: relevantCatalog, productType: detectedProductType, subtype: detectedSubtype)
        allCandidates.append(contentsOf: exactNameCandidates)

        // 3. Try component-based matching (manufacturer + color name + type)
        let componentCandidates = matchByComponents(item.rawName, relevantCatalog: relevantCatalog, fullCatalog: fullCatalog, productType: detectedProductType, subtype: detectedSubtype)
        allCandidates.append(contentsOf: componentCandidates)

        // 4. Try fuzzy name match for additional candidates
        let fuzzyCandidates = matchByFuzzyName(item.rawName, catalog: relevantCatalog, productType: detectedProductType, subtype: detectedSubtype)
        allCandidates.append(contentsOf: fuzzyCandidates)

        // Deduplicate and sort by confidence
        let uniqueCandidates = deduplicateCandidates(allCandidates)
        let sortedCandidates = uniqueCandidates.sorted { $0.confidence > $1.confidence }

        // Limit to top 5 candidates
        let topCandidates = Array(sortedCandidates.prefix(5))

        // Return the best match as primary
        if let best = topCandidates.first, best.confidence >= 0.5 {
            return ItemMatchResult(
                catalogStableId: best.catalogStableId,
                confidence: best.confidence,
                matchMethod: best.matchMethod,
                candidates: topCandidates
            )
        }

        // No confident match found
        return ItemMatchResult(
            catalogStableId: nil,
            confidence: 0,
            matchMethod: "none",
            candidates: topCandidates
        )
    }

    /// Detect product type (rod, frit, sheet, etc.) from the raw name
    private func detectProductType(_ rawName: String) -> String {
        let name = rawName.lowercased()

        // Check for stringer indicators first (2mm, 3mm, thins)
        // These override other types since they're more specific
        let stringerIndicators = ["2mm", "3mm", "thins", "thin", "stringer", "stringers"]
        for indicator in stringerIndicators {
            let pattern = "\\b\(indicator)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil {
                return "stringer"
            }
        }

        // Check for other product type keywords
        for (keyword, type) in Self.productTypeKeywords {
            // Skip stringer keywords since we already checked them
            if type == "stringer" { continue }

            let pattern = "\\b\(keyword)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil {
                return type
            }
        }

        // Default to rod if no type detected (most common)
        return "rod"
    }

    /// Detect frit subtype (mesh size) from the raw name
    /// Returns nil if no subtype detected or if not a frit type
    private func detectFritSubtype(_ rawName: String, productType: String) -> String? {
        // Only detect subtypes for frit
        guard productType == "frit" else { return nil }

        let name = rawName.lowercased()

        // Check for frit subtype keywords (check parenthetical first, then words)
        // Sort by key length descending to match longer patterns first
        let sortedKeywords = Self.fritSubtypeKeywords.sorted { $0.key.count > $1.key.count }

        for (keyword, subtype) in sortedKeywords {
            // For parenthetical notation like (S), (L), (F), match exactly
            if keyword.hasPrefix("(") {
                if name.contains(keyword) {
                    return subtype
                }
            } else if keyword.hasPrefix("#") {
                // Direct mesh size references
                if name.contains(keyword) {
                    return subtype
                }
            } else {
                // Word-based matching with word boundaries
                let pattern = "\\b\(keyword)\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil {
                    return subtype
                }
            }
        }

        return nil
    }

    // MARK: - SKU Matching

    private func matchBySku(_ rawSku: String, retailerId: String, catalog: [GlassItemModel], productType: String, subtype: String?) -> [MatchCandidate] {
        var candidates: [MatchCandidate] = []
        let upperSku = rawSku.uppercased()

        // Direct SKU match
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
                    matchDetails: "SKU: \(rawSku) → \(itemSku)"
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
                    matchDetails: "Partial SKU: \(rawSku) in \(itemSku)"
                ))
            }
        }

        return candidates
    }

    // MARK: - Name Matching

    private func matchByExactName(_ rawName: String, catalog: [GlassItemModel], productType: String, subtype: String?) -> [MatchCandidate] {
        var candidates: [MatchCandidate] = []
        let normalizedName = normalizeProductName(rawName)

        for item in catalog {
            if normalizeProductName(item.name) == normalizedName {
                candidates.append(MatchCandidate(
                    catalogStableId: item.stable_id,
                    catalogName: item.name,
                    catalogManufacturer: item.manufacturer,
                    catalogType: productType,
                    catalogSubtype: subtype,
                    confidence: 0.90,
                    matchMethod: "name_exact",
                    matchDetails: "Exact name match: \"\(item.name)\""
                ))
            }
        }

        return candidates
    }

    private func matchByFuzzyName(_ rawName: String, catalog: [GlassItemModel], productType: String, subtype: String?) -> [MatchCandidate] {
        var candidates: [MatchCandidate] = []
        let normalizedName = normalizeProductName(rawName)
        let keywords = extractKeywords(normalizedName)

        guard !keywords.isEmpty else { return candidates }

        var scores: [(item: GlassItemModel, score: Double)] = []

        for item in catalog {
            let catalogName = normalizeProductName(item.name)
            let catalogKeywords = extractKeywords(catalogName)

            // Calculate keyword overlap
            let matchingKeywords = keywords.filter { kw in
                catalogKeywords.contains { ckw in
                    kw == ckw || levenshteinDistance(kw, ckw) <= 1
                }
            }

            let keywordScore = Double(matchingKeywords.count) / Double(max(keywords.count, catalogKeywords.count))

            // Also check Levenshtein distance on full normalized name
            let distance = levenshteinDistance(normalizedName, catalogName)
            let lengthNormalized = 1.0 - (Double(distance) / Double(max(normalizedName.count, catalogName.count)))

            // Combine scores
            let combinedScore = (keywordScore * 0.6) + (lengthNormalized * 0.4)

            if combinedScore >= 0.5 {
                scores.append((item, combinedScore))
            }
        }

        // Sort by score and take top 5
        scores.sort { $0.score > $1.score }

        for (item, score) in scores.prefix(5) {
            candidates.append(MatchCandidate(
                catalogStableId: item.stable_id,
                catalogName: item.name,
                catalogManufacturer: item.manufacturer,
                catalogType: productType,
                catalogSubtype: subtype,
                confidence: round(score * 100) / 100,
                matchMethod: "name_fuzzy",
                matchDetails: "Fuzzy match: \"\(rawName)\" ≈ \"\(item.name)\""
            ))
        }

        return candidates
    }

    // MARK: - Component Matching

    private struct ParsedProductName {
        let manufacturer: String?
        let manufacturerConfidence: Double
        let productType: String?
        let colorName: String
    }

    private func matchByComponents(
        _ rawName: String,
        relevantCatalog: [GlassItemModel],
        fullCatalog: [GlassItemModel],
        productType: String,
        subtype: String?
    ) -> [MatchCandidate] {
        let parsed = parseProductName(rawName)
        var candidates: [MatchCandidate] = []

        // Determine which catalog to search
        var searchCatalog = relevantCatalog

        // If we detected a manufacturer, filter by it
        if let manufacturer = parsed.manufacturer {
            let filtered = fullCatalog.filter { $0.manufacturer.uppercased() == manufacturer }
            if !filtered.isEmpty {
                searchCatalog = filtered
            }
        }

        // Search for items matching the color name
        let colorWords = parsed.colorName.split(separator: " ").map(String.init).filter { $0.count >= 3 }

        guard !colorWords.isEmpty else { return candidates }

        for catalogItem in searchCatalog {
            let catalogNameLower = catalogItem.name.lowercased()
            let catalogNameWords = catalogNameLower.split(separator: " ").map(String.init)

            // Calculate word overlap score
            var matchingWords = 0
            for word in colorWords {
                if catalogNameWords.contains(where: { cw in
                    cw == word || cw.contains(word) || word.contains(cw)
                }) {
                    matchingWords += 1
                }
            }

            guard matchingWords > 0 else { continue }

            // Base confidence from word overlap (how many receipt words matched)
            let receiptMatchRatio = Double(matchingWords) / Double(max(colorWords.count, 1))

            // Penalize catalog items that have extra unmatched words
            // e.g., "Blue Moon" should rank higher than "Blue Moon Fore" when searching for "Blue Moon"
            let catalogMatchRatio = Double(matchingWords) / Double(max(catalogNameWords.count, 1))

            // Combined score: favor items where both ratios are high
            // An exact match (all receipt words match AND all catalog words are accounted for) scores highest
            var confidence = (receiptMatchRatio * 0.6) + (catalogMatchRatio * 0.4)

            // Boost confidence if manufacturer matches
            if let manufacturer = parsed.manufacturer, catalogItem.manufacturer.uppercased() == manufacturer {
                confidence += 0.2 * parsed.manufacturerConfidence
            }

            // Boost confidence if product type matches
            // Note: GlassItemModel doesn't have a type field, so we skip type matching
            // All items are glass, so product type from receipt (rod, frit, etc.) is form factor
            if parsed.productType != nil {
                // Product type detected but we can't verify against catalog
                // Don't boost or penalize
            }

            // Cap confidence based on match quality
            let hasGoodManufacturerMatch = parsed.manufacturer != nil && catalogItem.manufacturer.uppercased() == parsed.manufacturer
            let hasGoodTypeMatch = parsed.productType != nil  // Can't verify, assume OK if detected
            let hasGoodNameMatch = matchingWords >= Int(Double(colorWords.count) * 0.8)
            let isExactNameMatch = catalogMatchRatio >= 0.99  // All catalog words are matched

            if hasGoodManufacturerMatch && hasGoodTypeMatch && hasGoodNameMatch && isExactNameMatch {
                // Perfect match: manufacturer + type + all name words match exactly
                confidence = min(confidence, 0.98)
            } else if hasGoodManufacturerMatch && hasGoodTypeMatch && hasGoodNameMatch {
                // Good match but catalog has extra words
                confidence = min(confidence, 0.92)
            } else {
                confidence = min(confidence, 0.85)
            }

            // Only include if above minimum threshold
            if confidence >= 0.4 {
                candidates.append(MatchCandidate(
                    catalogStableId: catalogItem.stable_id,
                    catalogName: catalogItem.name,
                    catalogManufacturer: catalogItem.manufacturer,
                    catalogType: productType,
                    catalogSubtype: subtype,
                    confidence: round(confidence * 100) / 100,
                    matchMethod: "component_match",
                    matchDetails: "Component match: \"\(parsed.colorName)\" → \"\(catalogItem.name)\""
                ))
            }
        }

        return candidates
    }

    private func parseProductName(_ rawName: String) -> ParsedProductName {
        var name = rawName.lowercased().trimmingCharacters(in: .whitespaces)
        var manufacturer: String?
        var manufacturerConfidence: Double = 0
        var productType: String?

        // Check for manufacturer names (full names first, then abbreviations)
        // Sort by length descending to match longer names first
        let sortedAliases = Self.manufacturerAliases.sorted { $0.key.count > $1.key.count }

        for (alias, code) in sortedAliases {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: alias))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil {
                manufacturer = code
                manufacturerConfidence = alias.count > 3 ? 1.0 : 0.7
                name = name.replacingOccurrences(of: alias, with: " ", options: .caseInsensitive)
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Check for product type
        for (keyword, type) in Self.productTypeKeywords {
            let pattern = "\\b\(keyword)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil {
                productType = type
                name = name.replacingOccurrences(of: keyword, with: " ", options: .caseInsensitive)
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Clean up the remaining name
        let colorName = name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)

        return ParsedProductName(
            manufacturer: manufacturer,
            manufacturerConfidence: manufacturerConfidence,
            productType: productType,
            colorName: colorName
        )
    }

    // MARK: - Helpers

    private func normalizeProductName(_ name: String) -> String {
        var result = name.lowercased()

        // Remove common suffixes
        let patterns = [
            "\\s*(rod|rods|glass|tube|frit|sheet|powder)\\s*",
            "\\s*(transparent|opaque|opalescent|pastel|special)\\s*",
            "\\s*(coe\\s*\\d+|104\\s*coe|90\\s*coe|33\\s*coe)\\s*",
            "\\s*(effetre|moretti|bullseye|northstar|creation is messy|cim)\\s*",
            "\\s*(genuine|genuine moretti|ltd run|limited run)\\s*",
            "\\s*(italy|italian)\\s*",
            "\\s*\\d+\\s*oz\\.?\\s*",
            "\\s*\\d+\\s*lb\\.?\\s*",
            "\\s*\\d+-?\\d*mm\\s*",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: " ")
            }
        }

        // Remove non-alphanumeric characters and normalize whitespace
        result = result
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)

        return result
    }

    private func extractKeywords(_ name: String) -> [String] {
        let stopwords: Set<String> = ["the", "a", "an", "and", "or", "of", "in", "on", "for", "with"]

        return name
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 && !stopwords.contains($0) }
            .prefix(5)
            .map { $0 }
    }

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

    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        let aChars = Array(a)
        let bChars = Array(b)

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: a.count + 1), count: b.count + 1)

        for i in 0...b.count {
            matrix[i][0] = i
        }
        for j in 0...a.count {
            matrix[0][j] = j
        }

        for i in 1...b.count {
            for j in 1...a.count {
                if bChars[i - 1] == aChars[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j - 1] + 1,  // substitution
                        matrix[i][j - 1] + 1,      // insertion
                        matrix[i - 1][j] + 1       // deletion
                    )
                }
            }
        }

        return matrix[b.count][a.count]
    }
}
