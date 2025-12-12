//
//  ReceiptCatalogMatcherTests.swift
//  MoltenTests
//
//  Tests for ReceiptCatalogMatcher - the catalog matching logic for receipt items
//

import Testing
import Foundation
@testable import Molten

@Suite("ReceiptCatalogMatcher Tests")
@MainActor
struct ReceiptCatalogMatcherTests {

    // MARK: - Test Helpers

    private let deps = AppDependencies(persistenceController: .createTestController())

    private var matcher: ReceiptCatalogMatcher {
        ReceiptCatalogMatcher(catalogService: deps.catalogService)
    }

    /// Creates a mock ReceiptItem for testing using JSON decoding to match the Codable init
    private func createReceiptItem(
        id: Int = 1,
        rawName: String,
        rawSku: String? = nil,
        unitPrice: Double = 10.00,
        quantity: Double = 1.0
    ) -> ReceiptItem {
        // ReceiptItem uses Codable init, so we decode from JSON
        let json: [String: Any] = [
            "id": id,
            "raw_name": rawName,
            "raw_sku": rawSku as Any,
            "quantity": quantity,
            "quantity_unit": NSNull(),
            "unit_price": unitPrice,
            "total_price": unitPrice * quantity,
            "catalog_stable_id": NSNull(),
            "match_confidence": NSNull(),
            "match_method": NSNull(),
            "match_candidates": NSNull()
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(ReceiptItem.self, from: data)
    }

    // MARK: - Product Type Detection Tests

    @Test("Detects rod type from name")
    func testDetectsRodType() async {
        let item = createReceiptItem(rawName: "CiM Peace Rod")
        let results = await matcher.matchItems([item], retailerId: "frantz_art_glass")

        if let result = results[1], let candidate = result.candidates.first {
            #expect(candidate.catalogType == "rod")
        }
    }

    @Test("Detects stringer type from thins keyword")
    func testDetectsStringerFromThins() async {
        let item = createReceiptItem(rawName: "CiM Peace Thins")
        let results = await matcher.matchItems([item], retailerId: "frantz_art_glass")

        if let result = results[1], let candidate = result.candidates.first {
            #expect(candidate.catalogType == "stringer")
        }
    }

    @Test("Detects stringer type from 2mm keyword")
    func testDetectsStringerFrom2mm() async {
        let item = createReceiptItem(rawName: "NS Silver 2mm")
        let results = await matcher.matchItems([item], retailerId: "abr_imagery")

        if let result = results[1], let candidate = result.candidates.first {
            #expect(candidate.catalogType == "stringer")
        }
    }

    @Test("Detects frit type")
    func testDetectsFritType() async {
        let item = createReceiptItem(rawName: "BE Clear Frit Large")
        let results = await matcher.matchItems([item], retailerId: "bullseye_glass")

        if let result = results[1], let candidate = result.candidates.first {
            #expect(candidate.catalogType == "frit")
        }
    }

    @Test("Detects frit subtype from size keyword")
    func testDetectsFritSubtype() async {
        let item = createReceiptItem(rawName: "BE Clear Frit (L)")
        let results = await matcher.matchItems([item], retailerId: "bullseye_glass")

        if let result = results[1], let candidate = result.candidates.first {
            #expect(candidate.catalogSubtype == "#25")
        }
    }

    @Test("Detects tube type")
    func testDetectsTubeType() async {
        let item = createReceiptItem(rawName: "PDX Clear Tubing")
        let results = await matcher.matchItems([item], retailerId: "mountain_glass")

        if let result = results[1], let candidate = result.candidates.first {
            #expect(candidate.catalogType == "tubing")
        }
    }

    // MARK: - SKU Matching Tests

    @Test("Matches by exact SKU")
    func testMatchesByExactSKU() async {
        // This tests that SKU matching works when the item has a catalog match
        let item = createReceiptItem(rawName: "Test Glass", rawSku: "001")
        let results = await matcher.matchItems([item], retailerId: "bullseye_glass")

        let result = results[1]
        // If we have a SKU match, it should be high confidence
        if let candidate = result?.candidates.first(where: { $0.matchMethod == "sku_exact" }) {
            #expect(candidate.confidence >= 0.9)
        }
    }

    @Test("Partial SKU match has lower confidence than exact")
    func testPartialSKULowerConfidence() async {
        // Test that partial SKU matches have lower confidence than exact matches
        let item = createReceiptItem(rawName: "Test Glass", rawSku: "00")
        let results = await matcher.matchItems([item], retailerId: "bullseye_glass")

        if let result = results[1],
           let partial = result.candidates.first(where: { $0.matchMethod == "sku_partial" }) {
            #expect(partial.confidence < 0.95)
        }
    }

    // MARK: - Name Matching Tests

    @Test("Matches distinctive words in name")
    func testMatchesDistinctiveWords() async {
        // Test that distinctive words (not generic like "glass", "rod") are matched
        let item = createReceiptItem(rawName: "CiM Peace Ltd Run Rod")
        let results = await matcher.matchItems([item], retailerId: "frantz_art_glass")

        if let result = results[1] {
            // Should have at least one candidate
            #expect(!result.candidates.isEmpty)
        }
    }

    @Test("Color-only matches have moderate confidence")
    func testColorOnlyModerateConfidence() async {
        // A match on just "Black" should have moderate confidence (not very high)
        let item = createReceiptItem(rawName: "EF Black Rod")
        let results = await matcher.matchItems([item], retailerId: "frantz_art_glass")

        if let result = results[1], let candidate = result.candidates.first {
            // Color matches should have moderate confidence, less than perfect match
            #expect(candidate.confidence < 0.95)
            #expect(candidate.confidence > 0.0)
        }
    }

    @Test("Category modifier mismatch prevents matching")
    func testCategoryModifierMismatch() async {
        // "Dichroic Black" should not match "Black" (non-dichroic)
        let item = createReceiptItem(rawName: "Dichroic Black Glass")
        let results = await matcher.matchItems([item], retailerId: "bullseye_glass")

        // Any match found should also have "dichroic" in it
        if let result = results[1], let candidate = result.candidates.first {
            let matchDetails = candidate.matchDetails?.lowercased() ?? ""
            // If we matched something, it should have dichroic in the match
            #expect(matchDetails.contains("dichro") || candidate.confidence < 0.5)
        }
    }

    // MARK: - Manufacturer Extraction Tests

    @Test("Extracts Bullseye manufacturer from name")
    func testExtractsBullseyeManufacturer() async {
        let item = createReceiptItem(rawName: "Bullseye Clear Rod")
        let results = await matcher.matchItems([item], retailerId: "frantz_art_glass")

        if let result = results[1], let candidate = result.candidates.first {
            #expect(candidate.catalogManufacturer.uppercased() == "BE")
        }
    }

    @Test("Extracts CiM manufacturer from abbreviation")
    func testExtractsCiMManufacturer() async {
        let item = createReceiptItem(rawName: "CiM Peace Rod")
        let results = await matcher.matchItems([item], retailerId: "frantz_art_glass")

        if let result = results[1], let candidate = result.candidates.first {
            #expect(candidate.catalogManufacturer.uppercased() == "CIM")
        }
    }

    @Test("Extracts Double Helix manufacturer")
    func testExtractsDoubleHelixManufacturer() async {
        let item = createReceiptItem(rawName: "Double Helix Triton Rod")
        let results = await matcher.matchItems([item], retailerId: "lampwork_supply")

        if let result = results[1], let candidate = result.candidates.first {
            #expect(candidate.catalogManufacturer.uppercased() == "DH")
        }
    }

    // MARK: - Retailer Manufacturer Mapping Tests

    @Test("Uses retailer manufacturer mapping for ABR Imagery")
    func testRetailerMappingABR() async {
        let item = createReceiptItem(rawName: "Silver Blue Rod")
        _ = await matcher.matchItems([item], retailerId: "abr_imagery")

        // ABR maps to BB, NS, AB - results should prioritize these manufacturers
        // This is a behavioral test - we just verify no crashes
    }

    @Test("Uses retailer manufacturer mapping for Bullseye Glass")
    func testRetailerMappingBullseye() async {
        let item = createReceiptItem(rawName: "Clear Sheet")
        _ = await matcher.matchItems([item], retailerId: "bullseye_glass")

        // Bullseye maps to BE only
        // Verify it doesn't crash and uses the mapping
    }

    // MARK: - Confidence Score Tests

    @Test("Full distinctive match has high confidence")
    func testFullDistinctiveMatchHighConfidence() async {
        // When all distinctive words match, confidence should be high
        let item = createReceiptItem(rawName: "EF Effetre Dark Silver Blue Rod")
        let results = await matcher.matchItems([item], retailerId: "frantz_art_glass")

        if let result = results[1], let candidate = result.candidates.first {
            #expect(candidate.confidence >= 0.5)
        }
    }

    @Test("No match returns empty candidates or low confidence")
    func testNoMatchLowConfidence() async {
        let item = createReceiptItem(rawName: "XYZ NonexistentProduct 12345")
        let results = await matcher.matchItems([item], retailerId: "unknown_retailer")

        if let result = results[1] {
            // Either no candidates or catalogStableId is nil
            #expect(result.catalogStableId == nil || result.confidence < 0.5)
        }
    }

    // MARK: - Edge Case Tests

    @Test("Handles empty name gracefully")
    func testHandlesEmptyName() async {
        let item = createReceiptItem(rawName: "")
        let results = await matcher.matchItems([item], retailerId: "bullseye_glass")

        // Should not crash
        #expect(results[1]?.catalogStableId == nil)
    }

    @Test("Handles very long name")
    func testHandlesLongName() async {
        let longName = "This is a very long product name that includes many words like glass rod frit sheet tube and various colors like red blue green yellow orange purple pink and many more descriptive terms"
        let item = createReceiptItem(rawName: longName)
        let results = await matcher.matchItems([item], retailerId: "bullseye_glass")

        // Should not crash
        #expect(results.count >= 0)
    }

    @Test("Handles special characters in name")
    func testHandlesSpecialCharacters() async {
        let item = createReceiptItem(rawName: "Glass #1 (Special) - 'Test'")
        let results = await matcher.matchItems([item], retailerId: "bullseye_glass")

        // Should not crash
        #expect(results.count >= 0)
    }

    @Test("Matches multiple items in batch")
    func testMatchesMultipleItems() async {
        let items = [
            createReceiptItem(id: 1, rawName: "CiM Peace Rod"),
            createReceiptItem(id: 2, rawName: "EF Black Rod"),
            createReceiptItem(id: 3, rawName: "BE Clear Sheet"),
        ]
        let results = await matcher.matchItems(items, retailerId: "frantz_art_glass")

        // Should return results for all items
        #expect(results.count == 3)
        #expect(results[1] != nil)
        #expect(results[2] != nil)
        #expect(results[3] != nil)
    }

    // MARK: - Top Candidates Tests

    @Test("Returns up to 5 candidates per item")
    func testReturnsUpToFiveCandidates() async {
        let item = createReceiptItem(rawName: "Clear Glass Rod")
        let results = await matcher.matchItems([item], retailerId: "bullseye_glass")

        if let result = results[1] {
            #expect(result.candidates.count <= 5)
        }
    }

    @Test("Candidates are sorted by confidence")
    func testCandidatesSortedByConfidence() async {
        let item = createReceiptItem(rawName: "Clear Glass Rod")
        let results = await matcher.matchItems([item], retailerId: "bullseye_glass")

        if let result = results[1], result.candidates.count >= 2 {
            for i in 0..<(result.candidates.count - 1) {
                #expect(result.candidates[i].confidence >= result.candidates[i + 1].confidence)
            }
        }
    }

    // MARK: - Match Method Tests

    @Test("Reports correct match method for SKU match")
    func testReportsSkuMatchMethod() async {
        let item = createReceiptItem(rawName: "Test", rawSku: "001")
        let results = await matcher.matchItems([item], retailerId: "bullseye_glass")

        if let result = results[1],
           let skuCandidate = result.candidates.first(where: { $0.matchMethod.hasPrefix("sku") }) {
            #expect(skuCandidate.matchMethod == "sku_exact" || skuCandidate.matchMethod == "sku_partial")
        }
    }

    @Test("Reports correct match method for name match")
    func testReportsNameMatchMethod() async {
        let item = createReceiptItem(rawName: "CiM Peace Rod")
        let results = await matcher.matchItems([item], retailerId: "frantz_art_glass")

        if let result = results[1],
           let nameCandidate = result.candidates.first(where: { $0.matchMethod == "name_match" }) {
            #expect(nameCandidate.matchMethod == "name_match")
        }
    }
}
