//
//  SearchTextParserTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/16/25.
//  Comprehensive tests for SearchTextParser with quote handling
//

import Foundation

// Standard test framework imports pattern
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

// Use Swift Testing if available
#if canImport(Testing)

@Suite("SearchTextParser Tests")
struct SearchTextParserTests {

    // MARK: - Meaningful Search Text Tests

    @Test("Empty search text should not be meaningful")
    func testEmptyTextIsNotMeaningful() {
        #expect(!SearchTextParser.isSearchTextMeaningful(""))
        #expect(!SearchTextParser.isSearchTextMeaningful("   "))
        #expect(!SearchTextParser.isSearchTextMeaningful("\t\n"))
    }

    @Test("Single quote character should not be meaningful")
    func testSingleQuoteNotMeaningful() {
        #expect(!SearchTextParser.isSearchTextMeaningful("\""))
        #expect(!SearchTextParser.isSearchTextMeaningful("  \"  "))
    }

    @Test("Curly quote characters should not be meaningful")
    func testCurlyQuotesNotMeaningful() {
        #expect(!SearchTextParser.isSearchTextMeaningful("\u{201C}"))  // "
        #expect(!SearchTextParser.isSearchTextMeaningful("\u{201D}"))  // "
        #expect(!SearchTextParser.isSearchTextMeaningful("\u{2018}"))  // '
        #expect(!SearchTextParser.isSearchTextMeaningful("\u{2019}"))  // '
        #expect(!SearchTextParser.isSearchTextMeaningful("\u{201C}\u{201D}"))  // ""
        #expect(!SearchTextParser.isSearchTextMeaningful("\u{2018}\u{2019}"))  // ''
    }

    @Test("Text with content should be meaningful")
    func testMeaningfulText() {
        #expect(SearchTextParser.isSearchTextMeaningful("olive"))
        #expect(SearchTextParser.isSearchTextMeaningful("\"olive\""))
        #expect(SearchTextParser.isSearchTextMeaningful("\"olive crayon\""))
        #expect(SearchTextParser.isSearchTextMeaningful("olive crayon"))
        #expect(SearchTextParser.isSearchTextMeaningful("  olive  "))
    }

    // MARK: - Parse Search Text Tests - Single Term

    @Test("Should parse single term without quotes")
    func testParseSingleTerm() {
        let result = SearchTextParser.parseSearchText("olive")

        if case .singleTerm(let term) = result {
            #expect(term == "olive")
        } else {
            Issue.record("Expected singleTerm, got \(result)")
        }
    }

    @Test("Should parse single term with whitespace")
    func testParseSingleTermWithWhitespace() {
        let result = SearchTextParser.parseSearchText("  olive  ")

        if case .singleTerm(let term) = result {
            #expect(term == "olive")
        } else {
            Issue.record("Expected singleTerm, got \(result)")
        }
    }

    // MARK: - Parse Search Text Tests - Multiple Terms

    @Test("Should parse multiple terms as AND search")
    func testParseMultipleTerms() {
        let result = SearchTextParser.parseSearchText("olive crayon")

        if case .multipleTerms(let terms) = result {
            #expect(terms == ["olive", "crayon"])
        } else {
            Issue.record("Expected multipleTerms, got \(result)")
        }
    }

    @Test("Should parse multiple terms with extra whitespace")
    func testParseMultipleTermsWithWhitespace() {
        let result = SearchTextParser.parseSearchText("  olive   crayon  ")

        if case .multipleTerms(let terms) = result {
            #expect(terms == ["olive", "crayon"])
        } else {
            Issue.record("Expected multipleTerms, got \(result)")
        }
    }

    @Test("Should parse three or more terms")
    func testParseThreeTerms() {
        let result = SearchTextParser.parseSearchText("olive green crayon")

        if case .multipleTerms(let terms) = result {
            #expect(terms == ["olive", "green", "crayon"])
        } else {
            Issue.record("Expected multipleTerms, got \(result)")
        }
    }

    // MARK: - Parse Search Text Tests - Exact Phrase (Straight Quotes)

    @Test("Should parse exact phrase with straight double quotes on both sides")
    func testParseExactPhraseWithStraightQuotes() {
        let result = SearchTextParser.parseSearchText("\"olive crayon\"")

        if case .exactPhrase(let phrase) = result {
            #expect(phrase == "olive crayon")
        } else {
            Issue.record("Expected exactPhrase, got \(result)")
        }
    }

    @Test("Should parse exact phrase with quote at start only")
    func testParseExactPhraseWithStartQuote() {
        let result = SearchTextParser.parseSearchText("\"olive")

        if case .exactPhrase(let phrase) = result {
            #expect(phrase == "olive")
        } else {
            Issue.record("Expected exactPhrase, got \(result)")
        }
    }

    @Test("Should parse exact phrase with quote at end only")
    func testParseExactPhraseWithEndQuote() {
        let result = SearchTextParser.parseSearchText("olive\"")

        if case .exactPhrase(let phrase) = result {
            #expect(phrase == "olive")
        } else {
            Issue.record("Expected exactPhrase, got \(result)")
        }
    }

    // MARK: - Parse Search Text Tests - Exact Phrase (Curly Quotes)

    @Test("Should parse exact phrase with left curly quote")
    func testParseExactPhraseWithLeftCurlyQuote() {
        let result = SearchTextParser.parseSearchText("\u{201C}olive crayon")  // "olive crayon

        if case .exactPhrase(let phrase) = result {
            #expect(phrase == "olive crayon")
        } else {
            Issue.record("Expected exactPhrase, got \(result)")
        }
    }

    @Test("Should parse exact phrase with right curly quote")
    func testParseExactPhraseWithRightCurlyQuote() {
        let result = SearchTextParser.parseSearchText("olive crayon\u{201D}")  // olive crayon"

        if case .exactPhrase(let phrase) = result {
            #expect(phrase == "olive crayon")
        } else {
            Issue.record("Expected exactPhrase, got \(result)")
        }
    }

    @Test("Should parse exact phrase with both curly quotes")
    func testParseExactPhraseWithBothCurlyQuotes() {
        let result = SearchTextParser.parseSearchText("\u{201C}olive crayon\u{201D}")  // "olive crayon"

        if case .exactPhrase(let phrase) = result {
            #expect(phrase == "olive crayon")
        } else {
            Issue.record("Expected exactPhrase, got \(result)")
        }
    }

    @Test("Should parse exact phrase with curly single quotes")
    func testParseExactPhraseWithCurlySingleQuotes() {
        let result = SearchTextParser.parseSearchText("\u{2018}olive crayon\u{2019}")  // 'olive crayon'

        if case .exactPhrase(let phrase) = result {
            #expect(phrase == "olive crayon")
        } else {
            Issue.record("Expected exactPhrase, got \(result)")
        }
    }

    // MARK: - Matching Tests - Single Term

    @Test("Single term should match field containing term")
    func testSingleTermMatches() {
        let mode = SearchMode.singleTerm("olive")

        #expect(SearchTextParser.matches(fieldValue: "Olive Green Crayon", mode: mode))
        #expect(SearchTextParser.matches(fieldValue: "olive", mode: mode))
        #expect(SearchTextParser.matches(fieldValue: "OLIVE", mode: mode))
        #expect(!SearchTextParser.matches(fieldValue: "red crayon", mode: mode))
        #expect(!SearchTextParser.matches(fieldValue: nil, mode: mode))
    }

    // MARK: - Matching Tests - Multiple Terms (AND)

    @Test("Multiple terms should require ALL terms to match")
    func testMultipleTermsRequireAllMatches() {
        let mode = SearchMode.multipleTerms(["olive", "crayon"])

        // Should match - contains both
        #expect(SearchTextParser.matches(fieldValue: "Olive Green Crayon", mode: mode))
        #expect(SearchTextParser.matches(fieldValue: "crayon in olive color", mode: mode))

        // Should NOT match - missing one term
        #expect(!SearchTextParser.matches(fieldValue: "Olive Green", mode: mode))
        #expect(!SearchTextParser.matches(fieldValue: "Red Crayon", mode: mode))
        #expect(!SearchTextParser.matches(fieldValue: "olive", mode: mode))
        #expect(!SearchTextParser.matches(fieldValue: nil, mode: mode))
    }

    @Test("Multiple terms should be case insensitive")
    func testMultipleTermsCaseInsensitive() {
        let mode = SearchMode.multipleTerms(["OLIVE", "CRAYON"])

        #expect(SearchTextParser.matches(fieldValue: "olive green crayon", mode: mode))
        #expect(SearchTextParser.matches(fieldValue: "Olive Crayon", mode: mode))
    }

    // MARK: - Matching Tests - Exact Phrase

    @Test("Exact phrase should match phrase in field")
    func testExactPhraseMatches() {
        let mode = SearchMode.exactPhrase("olive crayon")

        // Should match
        #expect(SearchTextParser.matches(fieldValue: "Olive Crayon", mode: mode))
        #expect(SearchTextParser.matches(fieldValue: "This is an olive crayon", mode: mode))
        #expect(SearchTextParser.matches(fieldValue: "olive crayon green", mode: mode))

        // Should NOT match - words not adjacent
        #expect(!SearchTextParser.matches(fieldValue: "olive green crayon", mode: mode))
        #expect(!SearchTextParser.matches(fieldValue: "crayon olive", mode: mode))
        #expect(!SearchTextParser.matches(fieldValue: nil, mode: mode))
    }

    @Test("Exact phrase should be case insensitive")
    func testExactPhraseCaseInsensitive() {
        let mode = SearchMode.exactPhrase("olive crayon")

        #expect(SearchTextParser.matches(fieldValue: "OLIVE CRAYON", mode: mode))
        #expect(SearchTextParser.matches(fieldValue: "Olive Crayon", mode: mode))
        #expect(SearchTextParser.matches(fieldValue: "oLiVe CrAyOn", mode: mode))
    }

    // MARK: - Match Any Field Tests

    @Test("Should match if any field matches")
    func testMatchesAnyField() {
        let mode = SearchMode.singleTerm("olive")
        let fields = ["Red Crayon", "olive green", "blue"]

        #expect(SearchTextParser.matchesAnyField(fields: fields, mode: mode))
    }

    @Test("Should not match if no fields match")
    func testDoesNotMatchAnyField() {
        let mode = SearchMode.singleTerm("olive")
        let fields = ["Red Crayon", "blue glass", "clear"]

        #expect(!SearchTextParser.matchesAnyField(fields: fields, mode: mode))
    }

    @Test("Should handle nil values in fields array")
    func testMatchesAnyFieldWithNils() {
        let mode = SearchMode.singleTerm("olive")
        let fields: [String?] = [nil, "olive green", nil]

        #expect(SearchTextParser.matchesAnyField(fields: fields, mode: mode))
    }

    @Test("Should not match if all fields are nil")
    func testMatchesAnyFieldAllNils() {
        let mode = SearchMode.singleTerm("olive")
        let fields: [String?] = [nil, nil, nil]

        #expect(!SearchTextParser.matchesAnyField(fields: fields, mode: mode))
    }

    // MARK: - Integration Tests

    @Test("End-to-end: Quote stripping and matching")
    func testQuoteStrippingIntegration() {
        // Parse with quotes
        let searchText = "\"olive crayon\""
        let mode = SearchTextParser.parseSearchText(searchText)

        // Verify it's exact phrase mode
        if case .exactPhrase(let phrase) = mode {
            #expect(phrase == "olive crayon")
        } else {
            Issue.record("Expected exactPhrase mode")
        }

        // Test matching
        #expect(SearchTextParser.matches(fieldValue: "This is an olive crayon", mode: mode))
        #expect(!SearchTextParser.matches(fieldValue: "olive green crayon", mode: mode))
    }

    @Test("End-to-end: Multi-term AND search")
    func testMultiTermIntegration() {
        let searchText = "olive crayon"
        let mode = SearchTextParser.parseSearchText(searchText)

        if case .multipleTerms(let terms) = mode {
            #expect(terms == ["olive", "crayon"])
        } else {
            Issue.record("Expected multipleTerms mode")
        }

        // Should match when both terms present
        #expect(SearchTextParser.matches(fieldValue: "olive green crayon", mode: mode))

        // Should NOT match when only one term present
        #expect(!SearchTextParser.matches(fieldValue: "olive green", mode: mode))
    }

    @Test("End-to-end: Curly quotes from iOS")
    func testCurlyQuotesIntegration() {
        // Simulate iOS typing with smart quotes
        let searchText = "\u{201C}olive crayon\u{201D}"  // "olive crayon"
        let mode = SearchTextParser.parseSearchText(searchText)

        // Should be exact phrase with quotes stripped
        if case .exactPhrase(let phrase) = mode {
            #expect(phrase == "olive crayon")
        } else {
            Issue.record("Expected exactPhrase mode")
        }

        #expect(SearchTextParser.matches(fieldValue: "olive crayon green", mode: mode))
    }

    // MARK: - Field Strategy Tests (matchesWithFieldStrategy)

    @Test("Non-quoted single term should only match name field")
    func testSingleTermOnlyMatchesName() {
        let mode = SearchMode.singleTerm("bullseye")
        let name = "Clear Glass Rod"
        let allFields = [name, "be-001-clear", "be", "001", "Bullseye Glass Co manufacturer notes"]

        // Should NOT match - "bullseye" only in manufacturer and notes, not in name
        #expect(!SearchTextParser.matchesWithFieldStrategy(name: name, allFields: allFields, mode: mode))

        // Should match if in name
        let nameWithTerm = "Bullseye Clear Glass"
        #expect(SearchTextParser.matchesWithFieldStrategy(name: nameWithTerm, allFields: allFields, mode: mode))
    }

    @Test("Non-quoted multiple terms should only match name field")
    func testMultipleTermsOnlyMatchName() {
        let mode = SearchMode.multipleTerms(["olive", "green"])
        let name = "Red Crayon"
        let allFields = [name, "og-123", "olive-green", "Olive Green Inc", "olive green manufacturer"]

        // Should NOT match - "olive" and "green" only in other fields, not in name
        #expect(!SearchTextParser.matchesWithFieldStrategy(name: name, allFields: allFields, mode: mode))

        // Should match if both terms in name
        let nameWithTerms = "Olive Green Crayon"
        #expect(SearchTextParser.matchesWithFieldStrategy(name: nameWithTerms, allFields: allFields, mode: mode))
    }

    @Test("Quoted exact phrase should search all fields")
    func testExactPhraseSearchesAllFields() {
        let mode = SearchMode.exactPhrase("bullseye clear")
        let name = "Rod 123"

        // Should match if phrase in manufacturer notes (not in name)
        let allFields1 = [name, "be-001", "be", "001", "Bullseye clear glass manufacturer"]
        #expect(SearchTextParser.matchesWithFieldStrategy(name: name, allFields: allFields1, mode: mode))

        // Should match if phrase in SKU
        let allFields2 = [name, "bullseye clear-001", "be", "bullseye clear", "Some notes"]
        #expect(SearchTextParser.matchesWithFieldStrategy(name: name, allFields: allFields2, mode: mode))

        // Should match if phrase in manufacturer
        let allFields3 = [name, "bc-001", "bullseye clear", "001", "Notes"]
        #expect(SearchTextParser.matchesWithFieldStrategy(name: name, allFields: allFields3, mode: mode))

        // Should NOT match if phrase not in any field
        let allFields4 = [name, "ef-001", "ef", "001", "Effetre notes"]
        #expect(!SearchTextParser.matchesWithFieldStrategy(name: name, allFields: allFields4, mode: mode))
    }

    @Test("Quoted phrase should also match name field")
    func testExactPhraseAlsoMatchesName() {
        let mode = SearchMode.exactPhrase("olive green")
        let name = "Olive Green Crayon"
        let allFields = [name, "og-123", "og", "123", "Other notes"]

        // Should match because phrase is in name (even though it searches all fields)
        #expect(SearchTextParser.matchesWithFieldStrategy(name: name, allFields: allFields, mode: mode))
    }

    @Test("matchesName helper should work correctly")
    func testMatchesNameHelper() {
        let singleMode = SearchMode.singleTerm("olive")

        #expect(SearchTextParser.matchesName(name: "Olive Green", mode: singleMode))
        #expect(!SearchTextParser.matchesName(name: "Red Crayon", mode: singleMode))
        #expect(!SearchTextParser.matchesName(name: nil, mode: singleMode))

        let multiMode = SearchMode.multipleTerms(["olive", "green"])
        #expect(SearchTextParser.matchesName(name: "Olive Green Crayon", mode: multiMode))
        #expect(!SearchTextParser.matchesName(name: "Olive Red", mode: multiMode))

        let phraseMode = SearchMode.exactPhrase("olive green")
        #expect(SearchTextParser.matchesName(name: "Olive Green Crayon", mode: phraseMode))
        #expect(!SearchTextParser.matchesName(name: "Olive Red Green", mode: phraseMode))
    }

    @Test("Field strategy integration: manufacturer in notes but not name")
    func testManufacturerInNotesNotName() {
        // Real-world scenario: User searches for "bullseye" (no quotes)
        // Item has "Bullseye" in manufacturer notes but not in item name
        let searchText = "bullseye"
        let mode = SearchTextParser.parseSearchText(searchText)

        let itemName = "Clear Glass Rod"
        let allFields = [itemName, "be-001-clear", "be", "001", "Bullseye Glass Co premium"]

        // Should NOT match because search is unquoted (name-only)
        #expect(!SearchTextParser.matchesWithFieldStrategy(name: itemName, allFields: allFields, mode: mode))
    }

    @Test("Field strategy integration: quoted manufacturer search")
    func testQuotedManufacturerSearch() {
        // Real-world scenario: User searches for "bullseye" WITH quotes
        // Item has "Bullseye" in manufacturer notes but not in item name
        let searchText = "\"bullseye\""
        let mode = SearchTextParser.parseSearchText(searchText)

        let itemName = "Clear Glass Rod"
        let allFields = [itemName, "be-001-clear", "be", "001", "Bullseye Glass Co premium"]

        // SHOULD match because search is quoted (all fields)
        #expect(SearchTextParser.matchesWithFieldStrategy(name: itemName, allFields: allFields, mode: mode))
    }

    @Test("Field strategy integration: SKU search requires quotes")
    func testSKUSearchRequiresQuotes() {
        let itemName = "Clear Glass Rod"
        let allFields = [itemName, "BE-001-CLEAR", "be", "001", "Premium glass"]

        // Unquoted search for "001" - should NOT match (not in name)
        let unquotedMode = SearchTextParser.parseSearchText("001")
        #expect(!SearchTextParser.matchesWithFieldStrategy(name: itemName, allFields: allFields, mode: unquotedMode))

        // Quoted search for "001" - SHOULD match (in SKU field)
        let quotedMode = SearchTextParser.parseSearchText("\"001\"")
        #expect(SearchTextParser.matchesWithFieldStrategy(name: itemName, allFields: allFields, mode: quotedMode))
    }

    @Test("Field strategy with nil name field")
    func testFieldStrategyWithNilName() {
        let mode = SearchMode.singleTerm("olive")
        let allFields: [String?] = [nil, "olive-001", "olive", "001", "Olive manufacturer"]

        // Should not match because name is nil (even though other fields have the term)
        #expect(!SearchTextParser.matchesWithFieldStrategy(name: nil, allFields: allFields, mode: mode))
    }

    @Test("Field strategy with empty name field")
    func testFieldStrategyWithEmptyName() {
        let mode = SearchMode.singleTerm("olive")
        let allFields = ["", "olive-001", "olive", "001", "Olive manufacturer"]

        // Should not match because name is empty
        #expect(!SearchTextParser.matchesWithFieldStrategy(name: "", allFields: allFields, mode: mode))
    }

    // MARK: - Synonym Tests (grey/gray)

    @Test("Searching 'grey' should match items containing 'gray'")
    func testGreyMatchesGray() {
        let mode = SearchMode.singleTerm("grey")

        #expect(SearchTextParser.matches(fieldValue: "Steel Gray", mode: mode))
        #expect(SearchTextParser.matches(fieldValue: "gray rod", mode: mode))
        #expect(SearchTextParser.matches(fieldValue: "GRAY", mode: mode))
    }

    @Test("Searching 'gray' should match items containing 'grey'")
    func testGrayMatchesGrey() {
        let mode = SearchMode.singleTerm("gray")

        #expect(SearchTextParser.matches(fieldValue: "Steel Grey", mode: mode))
        #expect(SearchTextParser.matches(fieldValue: "grey rod", mode: mode))
        #expect(SearchTextParser.matches(fieldValue: "GREY", mode: mode))
    }

    @Test("Grey/gray synonyms should work with case variations")
    func testGreyGraySynonymsCaseInsensitive() {
        // Search "Grey" (capitalized) should match "gray" (lowercase)
        let mode1 = SearchMode.singleTerm("Grey")
        #expect(SearchTextParser.matches(fieldValue: "gray glass", mode: mode1))

        // Search "GREY" (uppercase) should match "Gray" (capitalized)
        let mode2 = SearchMode.singleTerm("GREY")
        #expect(SearchTextParser.matches(fieldValue: "Gray transparent", mode: mode2))
    }

    @Test("Grey/gray synonyms should work in multiple term searches")
    func testGreyGraySynonymsMultipleTerms() {
        // Search "steel grey" should match "steel gray"
        let mode1 = SearchMode.multipleTerms(["steel", "grey"])
        #expect(SearchTextParser.matches(fieldValue: "Steel Gray Rod", mode: mode1))

        // Search "steel gray" should match "steel grey"
        let mode2 = SearchMode.multipleTerms(["steel", "gray"])
        #expect(SearchTextParser.matches(fieldValue: "Steel Grey Rod", mode: mode2))
    }

    @Test("Grey/gray synonyms should work in exact phrase searches")
    func testGreyGraySynonymsExactPhrase() {
        // Search "steel grey" should match "steel gray"
        let mode1 = SearchMode.exactPhrase("steel grey")
        #expect(SearchTextParser.matches(fieldValue: "Steel Gray Rod", mode: mode1))

        // Search "steel gray" should match "steel grey"
        let mode2 = SearchMode.exactPhrase("steel gray")
        #expect(SearchTextParser.matches(fieldValue: "Steel Grey Rod", mode: mode2))
    }

    @Test("Grey/gray synonyms integration with field strategy")
    func testGreyGraySynonymsWithFieldStrategy() {
        // Item name has "grey", search for "gray"
        let itemName = "Light Grey Rod"
        let allFields = [itemName, "lg-001", "ef", "001", "Effetre grey glass"]

        // Unquoted search for "gray" should match name field with "grey"
        let mode1 = SearchTextParser.parseSearchText("gray")
        #expect(SearchTextParser.matchesWithFieldStrategy(name: itemName, allFields: allFields, mode: mode1))

        // Quoted search for "gray" should also match
        let mode2 = SearchTextParser.parseSearchText("\"gray\"")
        #expect(SearchTextParser.matchesWithFieldStrategy(name: itemName, allFields: allFields, mode: mode2))
    }

    // MARK: - Edge Cases

    @Test("Should handle empty string search")
    func testEmptyStringSearch() {
        let result = SearchTextParser.parseSearchText("")

        if case .singleTerm(let term) = result {
            #expect(term == "")
        } else {
            Issue.record("Expected singleTerm for empty string")
        }
    }

    @Test("Should handle very long search strings")
    func testVeryLongSearchString() {
        let longString = String(repeating: "word ", count: 100)
        let result = SearchTextParser.parseSearchText(longString)

        if case .multipleTerms(let terms) = result {
            #expect(terms.count == 100)
            #expect(terms.allSatisfy { $0 == "word" })
        } else {
            Issue.record("Expected multipleTerms for long string")
        }
    }

    @Test("Should handle special characters in search")
    func testSpecialCharactersInSearch() {
        let specialChars = "café 文字 🎨"
        let result = SearchTextParser.parseSearchText(specialChars)

        if case .multipleTerms(let terms) = result {
            #expect(terms.count == 3)
        } else {
            Issue.record("Expected multipleTerms")
        }

        // Test matching with special characters
        let mode = SearchMode.singleTerm("café")
        #expect(SearchTextParser.matches(fieldValue: "café latte", mode: mode))
    }
}

#else

#if canImport(XCTest)
import XCTest

// Fallback to XCTest if Swift Testing is not available
class SearchTextParserTests: XCTestCase {

    func testEmptyTextIsNotMeaningful() {
        XCTAssertFalse(SearchTextParser.isSearchTextMeaningful(""))
        XCTAssertFalse(SearchTextParser.isSearchTextMeaningful("   "))
    }

    func testSingleQuoteNotMeaningful() {
        XCTAssertFalse(SearchTextParser.isSearchTextMeaningful("\""))
    }

    func testMeaningfulText() {
        XCTAssertTrue(SearchTextParser.isSearchTextMeaningful("olive"))
        XCTAssertTrue(SearchTextParser.isSearchTextMeaningful("\"olive\""))
    }

    func testParseSingleTerm() {
        let result = SearchTextParser.parseSearchText("olive")

        if case .singleTerm(let term) = result {
            XCTAssertEqual(term, "olive")
        } else {
            XCTFail("Expected singleTerm")
        }
    }

    func testParseMultipleTerms() {
        let result = SearchTextParser.parseSearchText("olive crayon")

        if case .multipleTerms(let terms) = result {
            XCTAssertEqual(terms, ["olive", "crayon"])
        } else {
            XCTFail("Expected multipleTerms")
        }
    }

    func testParseExactPhrase() {
        let result = SearchTextParser.parseSearchText("\"olive crayon\"")

        if case .exactPhrase(let phrase) = result {
            XCTAssertEqual(phrase, "olive crayon")
        } else {
            XCTFail("Expected exactPhrase")
        }
    }

    func testSingleTermMatches() {
        let mode = SearchMode.singleTerm("olive")

        XCTAssertTrue(SearchTextParser.matches(fieldValue: "Olive Green Crayon", mode: mode))
        XCTAssertFalse(SearchTextParser.matches(fieldValue: "red crayon", mode: mode))
    }

    func testMultipleTermsRequireAllMatches() {
        let mode = SearchMode.multipleTerms(["olive", "crayon"])

        XCTAssertTrue(SearchTextParser.matches(fieldValue: "Olive Green Crayon", mode: mode))
        XCTAssertFalse(SearchTextParser.matches(fieldValue: "Olive Green", mode: mode))
    }

    func testExactPhraseMatches() {
        let mode = SearchMode.exactPhrase("olive crayon")

        XCTAssertTrue(SearchTextParser.matches(fieldValue: "Olive Crayon", mode: mode))
        XCTAssertFalse(SearchTextParser.matches(fieldValue: "olive green crayon", mode: mode))
    }

    func testSingleTermOnlyMatchesName() {
        let mode = SearchMode.singleTerm("bullseye")
        let name = "Clear Glass Rod"
        let allFields = [name, "be-001-clear", "be", "001", "Bullseye Glass Co manufacturer notes"]

        XCTAssertFalse(SearchTextParser.matchesWithFieldStrategy(name: name, allFields: allFields, mode: mode))

        let nameWithTerm = "Bullseye Clear Glass"
        XCTAssertTrue(SearchTextParser.matchesWithFieldStrategy(name: nameWithTerm, allFields: allFields, mode: mode))
    }

    func testMultipleTermsOnlyMatchName() {
        let mode = SearchMode.multipleTerms(["olive", "green"])
        let name = "Red Crayon"
        let allFields = [name, "og-123", "olive-green", "Olive Green Inc", "olive green manufacturer"]

        XCTAssertFalse(SearchTextParser.matchesWithFieldStrategy(name: name, allFields: allFields, mode: mode))

        let nameWithTerms = "Olive Green Crayon"
        XCTAssertTrue(SearchTextParser.matchesWithFieldStrategy(name: nameWithTerms, allFields: allFields, mode: mode))
    }

    func testExactPhraseSearchesAllFields() {
        let mode = SearchMode.exactPhrase("bullseye clear")
        let name = "Rod 123"

        let allFields1 = [name, "be-001", "be", "001", "Bullseye clear glass manufacturer"]
        XCTAssertTrue(SearchTextParser.matchesWithFieldStrategy(name: name, allFields: allFields1, mode: mode))

        let allFields4 = [name, "ef-001", "ef", "001", "Effetre notes"]
        XCTAssertFalse(SearchTextParser.matchesWithFieldStrategy(name: name, allFields: allFields4, mode: mode))
    }

    func testQuotedManufacturerSearch() {
        let searchText = "\"bullseye\""
        let mode = SearchTextParser.parseSearchText(searchText)

        let itemName = "Clear Glass Rod"
        let allFields = [itemName, "be-001-clear", "be", "001", "Bullseye Glass Co premium"]

        XCTAssertTrue(SearchTextParser.matchesWithFieldStrategy(name: itemName, allFields: allFields, mode: mode))
    }
}
#endif

#endif
