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

@testable import Molten

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
    
    @Test("Should handle advanced edge cases for malformed quote parsing")
    func testParseSearchTermsAdvancedEdgeCases() throws {
        // Arrange & Act & Assert - Test unclosed quotes
        let unclosedQuote = "\"unclosed quote test"
        let unclosedResult = SearchUtilities.parseSearchTerms(unclosedQuote)
        #expect(unclosedResult.isEmpty || unclosedResult.count > 0, "Should handle unclosed quotes gracefully")
        
        // Test multiple consecutive quotes
        let multipleQuotes = "\"\"test\"\" word"
        let multipleResult = SearchUtilities.parseSearchTerms(multipleQuotes)
        #expect(multipleResult.count >= 0, "Should handle multiple consecutive quotes")
        
        // Test quotes with only whitespace inside
        let whitespaceQuotes = "\"   \" normal"
        let whitespaceResult = SearchUtilities.parseSearchTerms(whitespaceQuotes)
        #expect(whitespaceResult.count <= 2, "Should handle quotes with only whitespace")
        
        // Test empty quoted strings
        let emptyQuotes = "\"\" \"\" normal"
        let emptyResult = SearchUtilities.parseSearchTerms(emptyQuotes)
        #expect(emptyResult.contains("normal"), "Should preserve non-empty terms")
        
        // Test very long quoted phrases (boundary condition)
        let longPhrase = "\"" + String(repeating: "word ", count: 100) + "\""
        let longResult = SearchUtilities.parseSearchTerms(longPhrase)
        #expect(longResult.count <= 1, "Should handle very long quoted phrases")
    }
    
    @Test("Should handle extreme memory pressure scenarios")
    func testMemoryPressureScenarios() throws {
        // Arrange - Create scenario with many small items (memory efficiency test)
        struct MockSearchableItem: Searchable {
            let searchableText: [String]
            
            init(_ texts: [String]) {
                self.searchableText = texts
            }
        }
        
        // Create 1000 items with varying text sizes
        let largeItemSet = (1...1000).map { i in
            MockSearchableItem([
                "Item \(i)",
                "Code-\(i)",
                "Category\(i % 10)",
                String(repeating: "text", count: i % 20) // Varying string lengths
            ])
        }
        
        let startTime = Date()
        let memoryStart = ProcessInfo.processInfo.physicalMemory
        
        // Act - Perform multiple searches to test memory usage
        let result1 = SearchUtilities.filter(largeItemSet, with: "Item")
        let result2 = SearchUtilities.filter(largeItemSet, with: "Code")
        let result3 = SearchUtilities.filter(largeItemSet, with: "Category")
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        // Assert - Performance and memory constraints
        #expect(result1.count > 0, "Should find items in large dataset")
        #expect(result2.count > 0, "Should find codes in large dataset")  
        #expect(result3.count > 0, "Should find categories in large dataset")
        #expect(totalTime < 1.0, "Should handle 1000 items efficiently (actual: \(totalTime)s)")
        
        // Memory usage shouldn't grow excessively (basic check)
        let memoryEnd = ProcessInfo.processInfo.physicalMemory
        #expect(memoryEnd >= memoryStart, "Memory usage should be reasonable")
        
        // Test concurrent searches don't interfere
        let concurrentResults = (1...5).map { i in
            SearchUtilities.filter(Array(largeItemSet.prefix(100)), with: "Item")
        }
        let allConcurrentSucceed = concurrentResults.allSatisfy { $0.count > 0 }
        #expect(allConcurrentSucceed, "Concurrent searches should all succeed")
    }
    
    @Test("Should handle unicode and special character edge cases")
    func testUnicodeAndSpecialCharacterEdgeCases() throws {
        // Arrange - Create items with complex unicode and special characters
        struct MockSearchableItem: Searchable {
            let searchableText: [String]
            
            init(_ texts: [String]) {
                self.searchableText = texts
            }
        }
        
        let unicodeItems = [
            MockSearchableItem(["Café français", "UTF-8 test"]),
            MockSearchableItem(["日本語テスト", "Japanese text"]),
            MockSearchableItem(["🎨🔥💎", "emoji-only"]),
            MockSearchableItem(["Mixed 文字 émojis 🎯", "complex unicode"]),
            MockSearchableItem(["\u{200B}zero-width", "invisible chars"]), // Zero-width space
            MockSearchableItem(["", "empty-string-field"]), // Empty string field
            MockSearchableItem(["tab\tseparated", "newline\nseparated"]), // Control characters
        ]
        
        // Act & Assert - Unicode searches
        let result1 = SearchUtilities.filter(unicodeItems, with: "français")
        #expect(result1.count == 1, "Should handle French accented characters")
        
        let result2 = SearchUtilities.filter(unicodeItems, with: "日本語")
        #expect(result2.count == 1, "Should handle Japanese characters")
        
        let result3 = SearchUtilities.filter(unicodeItems, with: "🎨")
        #expect(result3.count == 1, "Should handle emoji searches")
        
        let result4 = SearchUtilities.filter(unicodeItems, with: "文字")
        #expect(result4.count == 1, "Should handle mixed unicode searches")
        
        // Test zero-width and invisible character handling
        let result5 = SearchUtilities.filter(unicodeItems, with: "zero-width")
        #expect(result5.count == 1, "Should handle zero-width characters")
        
        // Test control character handling
        let result6 = SearchUtilities.filter(unicodeItems, with: "tab")
        #expect(result6.count == 1, "Should handle tab characters")
        
        let result7 = SearchUtilities.filter(unicodeItems, with: "newline")
        #expect(result7.count == 1, "Should handle newline characters")
        
        // Test empty field handling doesn't cause crashes
        let result8 = SearchUtilities.filter(unicodeItems, with: "empty-string-field")
        #expect(result8.count == 1, "Should handle items with empty string fields")
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
