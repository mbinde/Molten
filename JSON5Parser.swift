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
        
        // Remove single-line comments (// comment)
        jsonString = removeSingleLineComments(jsonString)
        
        // Remove multi-line comments (/* comment */)
        jsonString = removeMultiLineComments(jsonString)
        
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
        
        print("🔍 JSON5Parser: Original JSON5 length: \(json5String.count)")
        
        // Convert JSON5 to valid JSON
        let jsonString = convertJSON5ToJSON(json5String)
        
        print("🔍 JSON5Parser: Processed JSON length: \(jsonString.count)")
        print("📄 JSON5Parser: First 200 chars of processed JSON:")
        print(String(jsonString.prefix(200)))
        
        // Convert back to data
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw JSON5Error.invalidEncoding
        }
        
        // Use standard JSONDecoder
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: jsonData)
    }
    
    // MARK: - Private Helper Methods
    
    private static func removeSingleLineComments(_ input: String) -> String {
        let lines = input.components(separatedBy: .newlines)
        var processedLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip lines that start with //
            if trimmed.hasPrefix("//") {
                // Keep the line break to maintain JSON structure
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
                } else if char == "\"" {
                    processedLine.append(char)
                    insideString.toggle()
                } else if !insideString && char == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
                    // Found // comment outside of string, stop processing this line
                    break
                } else {
                    processedLine.append(char)
                }
                
                i += 1
            }
            
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
            } else if char == "\"" {
                result.append(char)
                insideString.toggle()
            } else if !insideString && char == "/" && i + 1 < chars.count && chars[i + 1] == "*" {
                // Start of multi-line comment, skip until */
                i += 2
                while i + 1 < chars.count {
                    if chars[i] == "*" && chars[i + 1] == "/" {
                        i += 2
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
        // Remove trailing commas before } or ]
        let pattern1 = try! NSRegularExpression(pattern: ",\\s*([}\\]])", options: [])
        let result1 = pattern1.stringByReplacingMatches(in: input, options: [], range: NSRange(location: 0, length: input.count), withTemplate: "$1")
        
        return result1
    }
    
    private static func cleanupWhitespace(_ input: String) -> String {
        // Replace multiple consecutive newlines with single newlines
        let pattern = try! NSRegularExpression(pattern: "\n\\s*\n\\s*\n", options: [])
        return pattern.stringByReplacingMatches(in: input, options: [], range: NSRange(location: 0, length: input.count), withTemplate: "\n\n")
    }
}

// MARK: - JSON5 Specific Errors

enum JSON5Error: Error, LocalizedError {
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
}