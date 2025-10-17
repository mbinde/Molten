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
}
#endif

#endif
