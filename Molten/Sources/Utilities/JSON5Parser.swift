//
//  JSON5Parser.swift
//  Flameworker
//
//  Created by Assistant on 9/28/25.
//

import Foundation

class JSON5Parser {
    
    /// Converts JSON5 string to valid JSON string by removing comments and handling JSON5 features
    static func convertJSON5ToJSON(_ json5String: String) -> String {
        var jsonString = json5String

        // Remove multi-line comments first (they can span multiple lines)
        jsonString = removeMultiLineComments(jsonString)

        // Remove single-line comments (// comment)
        jsonString = removeSingleLineComments(jsonString)

        // Handle trailing commas in objects and arrays
        jsonString = removeTrailingCommas(jsonString)

        // Clean up any double whitespace that might have been left
        jsonString = cleanupWhitespace(jsonString)

        return jsonString
    }
    
    /// Parse JSON5 data directly to a Decodable type
    static func parseJSON5<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        // Convert data to string
        guard let json5String = String(data: data, encoding: .utf8) else {
            throw JSON5Error.invalidEncoding
        }

        // Convert JSON5 to valid JSON
        let jsonString = convertJSON5ToJSON(json5String)

        // Convert back to data
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw JSON5Error.invalidEncoding
        }

        // Use standard JSONDecoder
        let decoder = JSONDecoder()

        do {
            let result = try decoder.decode(type, from: jsonData)
            return result
        } catch let decodingError {
            throw JSON5Error.parsingFailed("JSON5 decoding failed: \(decodingError.localizedDescription)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    private static func removeSingleLineComments(_ input: String) -> String {
        let lines = input.components(separatedBy: .newlines)
        var processedLines: [String] = []
        
        for (lineNumber, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and lines that are only comments
            if trimmed.isEmpty || trimmed.hasPrefix("//") {
                processedLines.append("")
                continue
            }
            
            // Handle // comments at end of lines (but not inside strings)
            var processedLine = ""
            var insideString = false
            var escapeNext = false
            var i = 0
            let chars = Array(line)
            
            while i < chars.count {
                let char = chars[i]
                
                if escapeNext {
                    processedLine.append(char)
                    escapeNext = false
                } else if char == "\\" && insideString {
                    processedLine.append(char)
                    escapeNext = true
                } else if char == "\"" && !escapeNext {
                    processedLine.append(char)
                    insideString.toggle()
                } else if !insideString && char == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
                    // Found // comment outside of string, remove everything from here to end of line
                    break
                } else {
                    processedLine.append(char)
                }
                
                i += 1
            }
            
            // Trim trailing whitespace that might be left after removing comments
            processedLine = processedLine.trimmingCharacters(in: .whitespacesAndNewlines)
            processedLines.append(processedLine)
        }
        
        return processedLines.joined(separator: "\n")
    }
    
    private static func removeMultiLineComments(_ input: String) -> String {
        var result = ""
        var i = 0
        let chars = Array(input)
        var insideString = false
        var escapeNext = false

        while i < chars.count {
            let char = chars[i]

            if escapeNext {
                result.append(char)
                escapeNext = false
            } else if char == "\\" && insideString {
                result.append(char)
                escapeNext = true
            } else if char == "\"" && !escapeNext {
                result.append(char)
                insideString.toggle()
            } else if !insideString && char == "/" && i + 1 < chars.count && chars[i + 1] == "*" {
                // Start of multi-line comment
                i += 2 // Skip the /*

                // Find the end of the comment
                while i + 1 < chars.count {
                    if chars[i] == "*" && chars[i + 1] == "/" {
                        i += 2 // Skip the */
                        break
                    }
                    i += 1
                }
                continue
            } else {
                result.append(char)
            }

            i += 1
        }

        return result
    }
    
    private static func removeTrailingCommas(_ input: String) -> String {
        // Remove trailing commas before } or ] (with optional whitespace)
        let pattern = try! NSRegularExpression(pattern: ",\\s*([}\\]])", options: [])
        let result = pattern.stringByReplacingMatches(
            in: input,
            options: [],
            range: NSRange(location: 0, length: input.count),
            withTemplate: "$1"
        )

        return result
    }
    
    private static func cleanupWhitespace(_ input: String) -> String {
        // Replace multiple consecutive newlines with single newlines
        let pattern = try! NSRegularExpression(pattern: "\n\\s*\n\\s*\n", options: [])
        return pattern.stringByReplacingMatches(in: input, options: [], range: NSRange(location: 0, length: input.count), withTemplate: "\n\n")
    }
}

// MARK: - JSON5 Specific Errors

enum JSON5Error: Error, LocalizedError, Equatable {
    case invalidEncoding
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Failed to encode/decode JSON5 string"
        case .parsingFailed(let message):
            return "JSON5 parsing failed: \(message)"
        }
    }

    static func == (lhs: JSON5Error, rhs: JSON5Error) -> Bool {
        switch (lhs, rhs) {
        case (.invalidEncoding, .invalidEncoding):
            return true
        case (.parsingFailed(let lhsMessage), .parsingFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}