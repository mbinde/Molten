//
//  SearchRankingTestsSafe_Fixed.swift
//  FlameworkerTests
//
//  Created by TDD Recovery Process on December 2024.
//  Safe search result ranking and relevance scoring functionality - REFACTORED VERSION
//

/* ========================================================================
   FILE STATUS: TEMPORARILY DISABLED FOR DEBUGGING - BUILD HANGING ISSUE
   REASON: Build hanging during compilation - investigating root cause
   ISSUE: Build process hangs when this file is included
   SOLUTION NEEDED: Isolate problematic code patterns causing hanging
   ======================================================================== */

/*
import Testing
import Foundation

// Search result with relevance scoring - unique to this file
struct RankingSearchResult {
    let item: RankableItem
    let relevanceScore: Double
    let matchedFields: [String]
    
    init(item: RankableItem, relevanceScore: Double, matchedFields: [String]) {
        self.item = item
        self.relevanceScore = relevanceScore
        self.matchedFields = matchedFields
    }
}

struct RankableItem {
    let id: String
    let name: String
    let manufacturer: String?
    let code: String?
    let tags: [String]
    let notes: String?
    
    init(id: String, name: String, manufacturer: String? = nil, code: String? = nil, tags: [String] = [], notes: String? = nil) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.code = code
        self.tags = tags
        self.notes = notes
    }
}

@Suite("Search Ranking Tests - Safe Fixed", .serialized)
struct SearchRankingTestsSafeFixed {
    
    // MARK: - Scoring Configuration
    private struct ScoringWeights {
        static let exactNameMatch: Double = 1.0
        static let wordBoundaryMatch: Double = 0.9
        static let partialNameMatch: Double = 0.8
        static let manufacturerWeight: Double = 0.6
        static let codeWeight: Double = 0.4
        static let tagWeight: Double = 0.3
        static let notesWeight: Double = 0.2
        
        // Fuzzy matching scores
        static let exactMatch: Double = 1.0
        static let substringMatch: Double = 0.8
        static let prefixMatch: Double = 0.7
        static let wordPrefixMatch: Double = 0.6
        static let typoMatch: Double = 0.5
        
        static let minFuzzyQueryLength = 3
        static let minTypoQueryLength = 4
        static let maxTypoDifference = 2
    }
    
    // MARK: - Test Cases
    
    @Test("Debug test - should find basic name matches")
    func testBasicSearchFunctionality() {
        let items = [
            RankableItem(id: "1", name: "Red Glass", manufacturer: "Effetre")
        ]
        
        let results = rankSearchResults(items: items, query: "Red")
        
        // Basic verification that search is working
        #expect(results.count > 0, "Should find at least one result")
        if results.count > 0 {
            #expect(results.first?.item.id == "1", "Should find the Red Glass item")
        }
    }
    
    @Test("Should rank exact name matches higher than partial matches")
    func testExactNameMatchRanking() {
        let items = [
            RankableItem(id: "1", name: "Red Glass", manufacturer: "Effetre"),
            RankableItem(id: "2", name: "Dark Red Glass", manufacturer: "Bullseye"),
            RankableItem(id: "3", name: "Glass Rod Red", manufacturer: "Spectrum")
        ]
        
        let results = rankSearchResults(items: items, query: "Red Glass")
        
        // Exact match should be ranked highest
        #expect(results.count == 3)
        #expect(results.first?.item.id == "1", "Exact name match should rank first")
        
        // Safe comparison using guard to ensure we have at least 2 results
        guard results.count >= 2 else {
            Issue.record("Should have at least 2 results for comparison")
            return
        }
        #expect(results[0].relevanceScore > results[1].relevanceScore, "First result should have higher score")
    }
    
    @Test("Should give higher scores to matches in more important fields")
    func testFieldImportanceRanking() {
        let items = [
            RankableItem(id: "1", name: "Blue Glass", code: "BG-001", tags: ["effetre"]),
            RankableItem(id: "2", name: "Glass Rod", code: "Effetre-100", tags: ["blue"]),
            RankableItem(id: "3", name: "Effetre Special", code: "ES-200", tags: ["glass"])
        ]
        
        let results = rankSearchResults(items: items, query: "Effetre")
        
        // Name matches should rank higher than code or tag matches
        #expect(results.count == 3)
        #expect(results.first?.item.id == "3", "Name match should rank highest")
        
        // Safe comparison with guard for relevance score
        guard let firstScore = results.first?.relevanceScore else {
            Issue.record("Should have first result with relevance score")
            return
        }
        #expect(firstScore > 0.8, "Name match should have high relevance score")
    }
    
    @Test("Should track which fields matched for debugging")
    func testMatchedFieldTracking() {
        let items = [
            RankableItem(id: "1", name: "Red Glass", manufacturer: "Effetre", tags: ["red", "transparent"])
        ]
        
        let results = rankSearchResults(items: items, query: "Red")
        
        #expect(results.count == 1)
        #expect(results.first?.matchedFields.contains("name") == true, "Should track name field match")
        #expect(results.first?.matchedFields.contains("tags") == true, "Should track tag field match")
    }
    
    @Test("Should return empty results for non-matching queries")
    func testNoMatchesQuery() {
        let items = [
            RankableItem(id: "1", name: "Red Glass", manufacturer: "Effetre")
        ]
        
        let results = rankSearchResults(items: items, query: "Purple Crystal")
        
        #expect(results.isEmpty, "Should return no results for non-matching query")
    }
    
    @Test("Should handle fuzzy matching for typos and partial words")
    func testFuzzyMatching() {
        let items = [
            RankableItem(id: "1", name: "Effetre Glass Rod", manufacturer: "Effetre"),
            RankableItem(id: "2", name: "Bullseye Sheet", manufacturer: "Bullseye"),
            RankableItem(id: "3", name: "Glass Frit", manufacturer: "Spectrum")
        ]
        
        // Test partial word matching - "Effett" should match "Effetre"
        let typoResults = rankSearchResultsWithFuzzy(items: items, query: "Effett")
        #expect(typoResults.count >= 1, "Should find fuzzy matches for typos")
        #expect(typoResults.first?.item.name.contains("Effetre") == true, "Should match Effetre despite typo")
        
        // Test partial name matching - "Glas" should match "Glass"
        let partialResults = rankSearchResultsWithFuzzy(items: items, query: "Glas")
        #expect(partialResults.count >= 2, "Should find multiple glass-related items")
        #expect(partialResults.contains { $0.item.name.contains("Glass") }, "Should match Glass items")
    }
    
    @Test("Should rank fuzzy matches lower than exact matches")
    func testFuzzyMatchRanking() {
        let items = [
            RankableItem(id: "1", name: "Red Glass", manufacturer: "Effetre"),
            RankableItem(id: "2", name: "Red Glaze", manufacturer: "Bullseye") // Similar but not exact
        ]
        
        let results = rankSearchResultsWithFuzzy(items: items, query: "Glass")
        
        #expect(results.count >= 1, "Should find at least exact match")
        #expect(results.first?.item.id == "1", "Exact match should rank higher than fuzzy match")
        
        // Exact match should score higher than fuzzy match
        if results.count >= 2 {
            #expect(results[0].relevanceScore > results[1].relevanceScore, "Exact match should have higher score")
        }
    }
    
    // MARK: - Search Implementation (Refactored with Constants)
    
    // Helper function - exact matching with multi-term support and constants
    private func rankSearchResults(items: [RankableItem], query: String) -> [RankingSearchResult] {
        let lowercaseQuery = query.lowercased()
        let queryTerms = lowercaseQuery.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var results: [RankingSearchResult] = []
        
        for item in items {
            var score: Double = 0.0
            var matchedFields: [String] = []
            
            // Check name field (highest weight)
            let nameLower = item.name.lowercased()
            if textMatchesQuery(nameLower, query: lowercaseQuery, terms: queryTerms) {
                if nameLower == lowercaseQuery {
                    score += ScoringWeights.exactNameMatch
                } else if nameLower.hasPrefix(lowercaseQuery + " ") {
                    score += ScoringWeights.wordBoundaryMatch
                } else {
                    score += ScoringWeights.partialNameMatch
                }
                matchedFields.append("name")
            }
            
            // Check manufacturer field
            if let manufacturer = item.manufacturer {
                let manufacturerLower = manufacturer.lowercased()
                if textMatchesQuery(manufacturerLower, query: lowercaseQuery, terms: queryTerms) {
                    score += ScoringWeights.manufacturerWeight
                    matchedFields.append("manufacturer")
                }
            }
            
            // Check code field
            if let code = item.code {
                let codeLower = code.lowercased()
                if textMatchesQuery(codeLower, query: lowercaseQuery, terms: queryTerms) {
                    score += ScoringWeights.codeWeight
                    matchedFields.append("code")
                }
            }
            
            // Check tags field
            for tag in item.tags {
                let tagLower = tag.lowercased()
                if textMatchesQuery(tagLower, query: lowercaseQuery, terms: queryTerms) {
                    score += ScoringWeights.tagWeight
                    matchedFields.append("tags")
                    break // Only add tags once
                }
            }
            
            // Check notes field
            if let notes = item.notes {
                let notesLower = notes.lowercased()
                if textMatchesQuery(notesLower, query: lowercaseQuery, terms: queryTerms) {
                    score += ScoringWeights.notesWeight
                    matchedFields.append("notes")
                }
            }
            
            // Only include items that match
            if score > 0 {
                results.append(RankingSearchResult(item: item, relevanceScore: score, matchedFields: matchedFields))
            }
        }
        
        // Sort by relevance score (highest first)
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    // Helper function - fuzzy matching implementation with constants
    private func rankSearchResultsWithFuzzy(items: [RankableItem], query: String) -> [RankingSearchResult] {
        let lowercaseQuery = query.lowercased()
        var results: [RankingSearchResult] = []
        
        for item in items {
            var score: Double = 0.0
            var matchedFields: [String] = []
            
            // Check name field with fuzzy matching (highest weight)
            let nameLower = item.name.lowercased()
            if let nameScore = fuzzyMatch(text: nameLower, query: lowercaseQuery) {
                score += nameScore
                matchedFields.append("name")
            }
            
            // Check manufacturer field with fuzzy matching
            if let manufacturer = item.manufacturer {
                let manufacturerLower = manufacturer.lowercased()
                if let manufacturerScore = fuzzyMatch(text: manufacturerLower, query: lowercaseQuery) {
                    score += manufacturerScore * ScoringWeights.manufacturerWeight
                    matchedFields.append("manufacturer")
                }
            }
            
            // Check code field with fuzzy matching
            if let code = item.code {
                let codeLower = code.lowercased()
                if let codeScore = fuzzyMatch(text: codeLower, query: lowercaseQuery) {
                    score += codeScore * ScoringWeights.codeWeight
                    matchedFields.append("code")
                }
            }
            
            // Check tags field with fuzzy matching
            for tag in item.tags {
                let tagLower = tag.lowercased()
                if let tagScore = fuzzyMatch(text: tagLower, query: lowercaseQuery) {
                    score += tagScore * ScoringWeights.tagWeight
                    matchedFields.append("tags")
                    break // Only add tags once
                }
            }
            
            // Check notes field with fuzzy matching
            if let notes = item.notes {
                let notesLower = notes.lowercased()
                if let notesScore = fuzzyMatch(text: notesLower, query: lowercaseQuery) {
                    score += notesScore * ScoringWeights.notesWeight
                    matchedFields.append("notes")
                }
            }
            
            // Only include items that match
            if score > 0 {
                results.append(RankingSearchResult(item: item, relevanceScore: score, matchedFields: matchedFields))
            }
        }
        
        // Sort by relevance score (highest first)
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    // MARK: - Fuzzy Matching Logic
    
    // Simple fuzzy matching function - returns score if match found, nil otherwise  
    private func fuzzyMatch(text: String, query: String) -> Double? {
        // Exact match gets highest score
        if text == query {
            return ScoringWeights.exactMatch
        }
        
        // Exact substring match gets high score
        if text.contains(query) {
            return ScoringWeights.substringMatch
        }
        
        // Prefix match gets medium-high score
        if text.hasPrefix(query) {
            return ScoringWeights.prefixMatch
        }
        
        // Simple fuzzy matching: check if query is a prefix of any word in text
        if query.count >= ScoringWeights.minFuzzyQueryLength {
            let words = text.components(separatedBy: .whitespacesAndNewlines)
            for word in words {
                if word.hasPrefix(query) {
                    return ScoringWeights.wordPrefixMatch
                }
            }
        }
        
        // Very basic edit distance check for longer queries
        if query.count >= ScoringWeights.minTypoQueryLength {
            let words = text.components(separatedBy: .whitespacesAndNewlines)
            for word in words {
                if isSimpleTypo(query: query, word: word) {
                    return ScoringWeights.typoMatch
                }
            }
        }
        
        return nil // No match
    }
    
    // Simple typo detection - checks if query is close to word
    private func isSimpleTypo(query: String, word: String) -> Bool {
        // Only check words of similar length
        guard abs(query.count - word.count) <= ScoringWeights.maxTypoDifference else { return false }
        
        // Convert to character arrays for comparison
        let queryChars = Array(query)
        let wordChars = Array(word)
        
        var differences = 0
        let minLength = min(queryChars.count, wordChars.count)
        
        // Count character differences
        for i in 0..<minLength {
            if queryChars[i] != wordChars[i] {
                differences += 1
            }
        }
        
        // Add length difference to differences
        differences += abs(queryChars.count - wordChars.count)
        
        // Allow up to configured differences for typo matching
        return differences <= ScoringWeights.maxTypoDifference
    }
    
    // MARK: - Multi-term Query Matching
    
    // Helper function to check if text matches query (handles multi-term queries)
    private func textMatchesQuery(_ text: String, query: String, terms: [String]) -> Bool {
        // First check if the text contains the full query as a phrase
        if text.contains(query) {
            return true
        }
        
        // Then check if all query terms are present (for multi-word queries)
        for term in terms {
            if !text.contains(term) {
                return false
            }
        }
        return !terms.isEmpty
    }
}
*/