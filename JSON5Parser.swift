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
        
        print("🔍 JSON5Parser: Starting conversion...")
        print("📄 Original length: \(jsonString.count)")
        
        // Remove multi-line comments first (they can span multiple lines)
        jsonString = removeMultiLineComments(jsonString)
        print("📄 After removing multi-line comments: \(jsonString.count)")
        
        // Remove single-line comments (// comment)
        jsonString = removeSingleLineComments(jsonString)
        print("📄 After removing single-line comments: \(jsonString.count)")
        
        // Handle trailing commas in objects and arrays
        jsonString = removeTrailingCommas(jsonString)
        print("📄 After removing trailing commas: \(jsonString.count)")
        
        // Clean up any double whitespace that might have been left
        jsonString = cleanupWhitespace(jsonString)
        print("📄 Final length: \(jsonString.count)")
        
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
        
        // Show a sample of the processed JSON for debugging
        let sampleLength = min(500, jsonString.count)
        print("📄 JSON5Parser: First \(sampleLength) chars of processed JSON:")
        print(String(jsonString.prefix(sampleLength)))
        
        // Convert back to data
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("❌ JSON5Parser: Failed to convert processed string back to data")
            throw JSON5Error.invalidEncoding
        }
        
        // Use standard JSONDecoder
        let decoder = JSONDecoder()
        
        do {
            let result = try decoder.decode(type, from: jsonData)
            print("✅ JSON5Parser: Successfully decoded JSON5 data")
            return result
        } catch let decodingError {
            print("❌ JSON5Parser: Decoding failed with error: \(decodingError)")
            
            // Show more context about what went wrong
            if let decodingError = decodingError as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: Expected \(type) at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type) at \(context.codingPath)")
                case .keyNotFound(let key, let context):
                    print("   Key not found: \(key) at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("   Data corrupted at \(context.codingPath): \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
            
            // Show a larger sample of the processed JSON around the error
            print("📄 Full processed JSON (for debugging):")
            let debugSample = String(jsonString.prefix(1000))
            print(debugSample)
            
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
                    print("🗑️ Removing comment on line \(lineNumber + 1): \(String(chars[i...]))")
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
        var commentCount = 0
        
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
                commentCount += 1
                print("🗑️ Found start of multi-line comment #\(commentCount)")
                i += 2 // Skip the /*
                
                // Find the end of the comment
                var foundEnd = false
                while i + 1 < chars.count {
                    if chars[i] == "*" && chars[i + 1] == "/" {
                        print("✅ Found end of multi-line comment #\(commentCount)")
                        i += 2 // Skip the */
                        foundEnd = true
                        break
                    }
                    i += 1
                }
                
                if !foundEnd {
                    print("⚠️ Unterminated multi-line comment found")
                }
                continue
            } else {
                result.append(char)
            }
            
            i += 1
        }
        
        print("🧹 Removed \(commentCount) multi-line comments")
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
        
        // Count how many trailing commas were removed
        let removedCount = (input.count - result.count)
        if removedCount > 0 {
            print("🧹 Removed \(removedCount) trailing commas")
        }
        
        return result
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