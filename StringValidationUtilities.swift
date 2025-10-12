//  StringValidationUtilities.swift
//  StringValidationUtilities.swift
//  Flameworker
//
//  Created by Assistant on 10/11/25.
//

import Foundation
@testable import Flameworker

/// Advanced string validation utilities for comprehensive edge case handling
struct StringValidationUtilities {
    
    /// Safely trims all types of whitespace and newline characters, including Unicode variants
    /// - Parameter input: The string to trim
    /// - Returns: Trimmed string with all whitespace removed from beginning and end
    static func safeTrim(_ input: String) -> String {
        // First, use standard whitespace trimming
        var trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle additional Unicode whitespace that .whitespacesAndNewlines might miss
        let additionalWhitespace = CharacterSet(charactersIn: 
            "\u{200B}" +    // Zero-width space
            "\u{FEFF}" +    // Byte order mark (BOM)
            "\u{00A0}" +    // Non-breaking space
            "\u{2000}" +    // En quad
            "\u{2001}" +    // Em quad  
            "\u{2002}" +    // En space
            "\u{2003}" +    // Em space
            "\u{2004}" +    // Three-per-em space
            "\u{2005}" +    // Four-per-em space
            "\u{2006}" +    // Six-per-em space
            "\u{2007}" +    // Figure space
            "\u{2008}" +    // Punctuation space
            "\u{2009}" +    // Thin space
            "\u{200A}" +    // Hair space
            "\u{3000}"      // Ideographic space
        )
        
        // Trim additional Unicode whitespace
        trimmed = trimmed.trimmingCharacters(in: additionalWhitespace)
        
        return trimmed
    }
    
    /// Validates an optional string, returning nil for empty/whitespace-only content
    /// - Parameters:
    ///   - input: Optional string to validate
    ///   - fieldName: Name of the field for error messages
    /// - Returns: Result containing trimmed string or nil, or validation error
    static func safeValidateOptional(_ input: String?, fieldName: String = "Field") -> Result<String?, AppError> {
        // Handle nil input
        guard let inputString = input else {
            return .success(nil)
        }
        
        // Trim the string
        let trimmed = safeTrim(inputString)
        
        // Return nil for empty content, trimmed string for valid content
        if trimmed.isEmpty {
            return .success(nil)
        } else {
            return .success(trimmed)
        }
    }
    
    /// Checks if a string is valid (non-empty after trimming)
    /// - Parameter input: String to validate
    /// - Returns: True if string contains non-whitespace content, false otherwise
    static func isValidNonEmptyString(_ input: String) -> Bool {
        return !safeTrim(input).isEmpty
    }
}