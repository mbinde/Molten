//
//  SearchTextParser.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//  Utility for parsing search text and determining search mode
//

import Foundation

/// Result of parsing a search query
enum SearchMode {
    /// Single word or term search (e.g., "acid")
    case singleTerm(String)

    /// Multiple words that must ALL be present (AND search) (e.g., "Olive crayon")
    case multipleTerms([String])

    /// Exact phrase search (e.g., "Olive cray")
    case exactPhrase(String)
}

/// Utility for parsing and interpreting search text
struct SearchTextParser {

    /// Parse search text and determine the appropriate search mode
    /// - Parameter text: Raw search text from user input
    /// - Returns: SearchMode indicating how to perform the search
    static func parseSearchText(_ text: String) -> SearchMode {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        print("🔍 SearchTextParser.parseSearchText: input='\(text)' trimmed='\(trimmed)'")

        // Check if search starts and/or ends with quotation marks (exact phrase search)
        // Support both straight quotes (") and curly quotes (" " ' ')
        let straightQuote = "\""
        let leftCurlyQuote = "\u{201C}"  // "
        let rightCurlyQuote = "\u{201D}" // "
        let leftSingleQuote = "\u{2018}" // '
        let rightSingleQuote = "\u{2019}" // '

        let quoteCharacters = straightQuote + leftCurlyQuote + rightCurlyQuote + leftSingleQuote + rightSingleQuote
        let startsWithQuote = trimmed.first.map { quoteCharacters.contains($0) } ?? false
        let endsWithQuote = trimmed.last.map { quoteCharacters.contains($0) } ?? false

        if startsWithQuote || endsWithQuote {
            // Remove all types of quotes and return exact phrase
            let phrase = trimmed
                .trimmingCharacters(in: CharacterSet(charactersIn: quoteCharacters))
                .trimmingCharacters(in: .whitespaces)
            print("🔍 SearchTextParser: Detected quotes, phrase='\(phrase)'")
            return .exactPhrase(phrase)
        }

        // Split on whitespace to detect multiple terms
        let terms = trimmed.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // If multiple terms, use AND search
        if terms.count > 1 {
            return .multipleTerms(terms)
        }

        // Single term search
        if let singleTerm = terms.first {
            return .singleTerm(singleTerm)
        }

        // Empty search (shouldn't happen due to upstream checks, but handle gracefully)
        return .singleTerm(trimmed)
    }

    /// Check if a text field matches the search mode criteria
    /// - Parameters:
    ///   - fieldValue: The text field to search in (e.g., item name, notes)
    ///   - mode: The search mode to apply
    /// - Returns: True if the field matches the search criteria
    static func matches(fieldValue: String?, mode: SearchMode) -> Bool {
        guard let fieldValue = fieldValue else {
            return false
        }

        let lowercasedField = fieldValue.lowercased()

        switch mode {
        case .singleTerm(let term):
            return lowercasedField.contains(term.lowercased())

        case .multipleTerms(let terms):
            // ALL terms must be present (AND logic)
            return terms.allSatisfy { term in
                lowercasedField.contains(term.lowercased())
            }

        case .exactPhrase(let phrase):
            return lowercasedField.contains(phrase.lowercased())
        }
    }

    /// Check if an item matches the search mode across multiple fields
    /// - Parameters:
    ///   - fields: Array of field values to search across
    ///   - mode: The search mode to apply
    /// - Returns: True if any field matches the search criteria
    static func matchesAnyField(fields: [String?], mode: SearchMode) -> Bool {
        return fields.contains { fieldValue in
            matches(fieldValue: fieldValue, mode: mode)
        }
    }
}
