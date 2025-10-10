//
//  SearchUtilitiesTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/9/25.
//

import Foundation

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

// Use Swift Testing if available, otherwise fall back to XCTest
#if canImport(Testing)

@Suite("SearchUtilities Tests")
struct SearchUtilitiesTests {
    
    @Test("Should parse simple search terms correctly")
    func testParseSearchTermsWithSimpleInput() throws {
        // Arrange
        let simpleQuery = "red blue glass"
        
        // Act
        let result = SearchUtilities.parseSearchTerms(simpleQuery)
        
        // Assert
        #expect(result == ["red", "blue", "glass"])
    }
    
    @Test("Should parse quoted phrases as single terms")
    func testParseSearchTermsWithQuotedPhrases() throws {
        // Arrange
        let quotedQuery = "\"chocolate crayon\" red \"borosilicate glass\""
        
        // Act
        let result = SearchUtilities.parseSearchTerms(quotedQuery)
        
        // Assert  
        #expect(result == ["chocolate crayon", "red", "borosilicate glass"])
    }
    
    @Test("Should filter searchable items with basic search")
    func testFilterWithBasicSearch() throws {
        // Arrange - Create mock searchable items
        struct MockSearchableItem: Searchable {
            let searchableText: [String]
            
            init(_ texts: [String]) {
                self.searchableText = texts
            }
        }
        
        let items = [
            MockSearchableItem(["red glass rod", "borosilicate"]),
            MockSearchableItem(["blue frit", "fine powder"]),
            MockSearchableItem(["red crayon", "chocolate colored"]),
            MockSearchableItem(["clear glass", "transparent"])
        ]
        
        // Act
        let result = SearchUtilities.filter(items, with: "red")
        
        // Assert
        #expect(result.count == 2) // Should find "red glass rod" and "red crayon" items
    }
    
    @Test("Should handle edge cases for search filtering")
    func testFilterWithEdgeCases() throws {
        // Arrange - Create mock searchable items
        struct MockSearchableItem: Searchable {
            let searchableText: [String]
            
            init(_ texts: [String]) {
                self.searchableText = texts
            }
        }
        
        let items = [
            MockSearchableItem(["red glass rod"]),
            MockSearchableItem(["blue frit"])
        ]
        
        // Test with empty search string - should return all items
        let emptySearchResult = SearchUtilities.filter(items, with: "")
        #expect(emptySearchResult.count == 2)
        
        // Test with whitespace-only search string - should return all items
        let whitespaceSearchResult = SearchUtilities.filter(items, with: "   ")
        #expect(whitespaceSearchResult.count == 2)
        
        // Test with no matching search term - should return empty array
        let noMatchResult = SearchUtilities.filter(items, with: "xyz")
        #expect(noMatchResult.count == 0)
        
        // Test with empty items array - should return empty array
        let emptyItems: [MockSearchableItem] = []
        let emptyItemsResult = SearchUtilities.filter(emptyItems, with: "red")
        #expect(emptyItemsResult.count == 0)
    }
}

#else

// Fallback to XCTest if Swift Testing is not available
class SearchUtilitiesTests: XCTestCase {
    
    func testParseSearchTermsWithSimpleInput() throws {
        // Arrange
        let simpleQuery = "red blue glass"
        
        // Act
        let result = SearchUtilities.parseSearchTerms(simpleQuery)
        
        // Assert
        XCTAssertEqual(result, ["red", "blue", "glass"])
    }
    
    func testParseSearchTermsWithQuotedPhrases() throws {
        // Arrange
        let quotedQuery = "\"chocolate crayon\" red \"borosilicate glass\""
        
        // Act
        let result = SearchUtilities.parseSearchTerms(quotedQuery)
        
        // Assert  
        XCTAssertEqual(result, ["chocolate crayon", "red", "borosilicate glass"])
    }
    
    func testFilterWithBasicSearch() throws {
        // Arrange - Create mock searchable items
        struct MockSearchableItem: Searchable {
            let searchableText: [String]
            
            init(_ texts: [String]) {
                self.searchableText = texts
            }
        }
        
        let items = [
            MockSearchableItem(["red glass rod", "borosilicate"]),
            MockSearchableItem(["blue frit", "fine powder"]),
            MockSearchableItem(["red crayon", "chocolate colored"]),
            MockSearchableItem(["clear glass", "transparent"])
        ]
        
        // Act
        let result = SearchUtilities.filter(items, with: "red")
        
        // Assert
        XCTAssertEqual(result.count, 2) // Should find "red glass rod" and "red crayon" items
    }
    
    func testFilterWithEdgeCases() throws {
        // Arrange - Create mock searchable items
        struct MockSearchableItem: Searchable {
            let searchableText: [String]
            
            init(_ texts: [String]) {
                self.searchableText = texts
            }
        }
        
        let items = [
            MockSearchableItem(["red glass rod"]),
            MockSearchableItem(["blue frit"])
        ]
        
        // Test with empty search string - should return all items
        let emptySearchResult = SearchUtilities.filter(items, with: "")
        XCTAssertEqual(emptySearchResult.count, 2)
        
        // Test with whitespace-only search string - should return all items
        let whitespaceSearchResult = SearchUtilities.filter(items, with: "   ")
        XCTAssertEqual(whitespaceSearchResult.count, 2)
        
        // Test with no matching search term - should return empty array
        let noMatchResult = SearchUtilities.filter(items, with: "xyz")
        XCTAssertEqual(noMatchResult.count, 0)
        
        // Test with empty items array - should return empty array
        let emptyItems: [MockSearchableItem] = []
        let emptyItemsResult = SearchUtilities.filter(emptyItems, with: "red")
        XCTAssertEqual(emptyItemsResult.count, 0)
    }
}

#endif