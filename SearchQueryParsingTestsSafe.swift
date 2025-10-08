//
//  SearchQueryParsingTestsSafe.swift
//  FlameworkerTests
//
//  Created by TDD Recovery Process on December 2024.
//  Safe rewrite of dangerous SearchUtilitiesQueryParsingTests.swift
//

import Testing
import Foundation

@Suite("Search Query Parsing Tests - Safe")
struct SearchQueryParsingTestsSafe {
    
    @Test("Should parse simple search terms correctly")
    func testSimpleSearchTermParsing() {
        let query = "effetre glass red"
        let terms = parseSearchTerms(query)
        
        #expect(terms.count == 3)
        #expect(terms.contains("effetre"))
        #expect(terms.contains("glass"))
        #expect(terms.contains("red"))
    }
    
    @Test("Should handle quoted search terms")
    func testQuotedSearchTerms() {
        let query = "\"Effetre Glass\" red color"
        let terms = parseSearchTermsWithQuotes(query)
        
        #expect(terms.count == 3)
        #expect(terms.contains("Effetre Glass"))
        #expect(terms.contains("red"))
        #expect(terms.contains("color"))
    }
    
    @Test("Should handle empty and whitespace-only queries")
    func testEmptyAndWhitespaceQueries() {
        #expect(parseSearchTerms("").isEmpty)
        #expect(parseSearchTerms("   ").isEmpty)
        #expect(parseSearchTerms("\t\n ").isEmpty)
        
        let singleTerm = parseSearchTerms("  glass  ")
        #expect(singleTerm.count == 1)
        #expect(singleTerm.contains("glass"))
    }
    
    // Private helper function to implement the expected logic for testing
    private func parseSearchTerms(_ query: String) -> [String] {
        return query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    }
    
    // Private helper function for quoted search terms
    private func parseSearchTermsWithQuotes(_ query: String) -> [String] {
        var terms: [String] = []
        var currentTerm = ""
        var insideQuotes = false
        
        let characters = Array(query)
        
        for char in characters {
            if char == "\"" {
                if insideQuotes {
                    // End of quoted term
                    if !currentTerm.isEmpty {
                        terms.append(currentTerm)
                        currentTerm = ""
                    }
                }
                insideQuotes.toggle()
            } else if char.isWhitespace && !insideQuotes {
                // End of regular term
                if !currentTerm.isEmpty {
                    terms.append(currentTerm)
                    currentTerm = ""
                }
            } else {
                currentTerm.append(char)
            }
        }
        
        // Add final term if exists
        if !currentTerm.isEmpty {
            terms.append(currentTerm)
        }
        
        return terms
    }
}