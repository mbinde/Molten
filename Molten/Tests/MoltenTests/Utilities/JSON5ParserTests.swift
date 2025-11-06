//
//  JSON5ParserTests.swift
//  MoltenTests
//
//  Unit tests for JSON5Parser utility
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Molten

@MainActor
@Suite("JSON5Parser Tests")
struct JSON5ParserTests {

    // MARK: - Single-Line Comment Removal Tests

    @Test("Remove single-line comment at end of line")
    func testRemoveSingleLineCommentAtEnd() {
        let json5 = """
        {
            "name": "test" // This is a comment
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("test"))
        #expect(!result.contains("This is a comment"))
    }

    @Test("Remove single-line comment on its own line")
    func testRemoveSingleLineCommentOwnLine() {
        let json5 = """
        {
            // This is a comment
            "name": "test"
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("name"))
        #expect(!result.contains("This is a comment"))
    }

    @Test("Preserve // inside string values")
    func testPreserveDoubleSlashInString() {
        let json5 = """
        {
            "url": "https://example.com"
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("https://example.com"))
    }

    @Test("Multiple single-line comments")
    func testMultipleSingleLineComments() {
        let json5 = """
        {
            // Comment 1
            "name": "test", // Comment 2
            // Comment 3
            "value": 123 // Comment 4
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("name"))
        #expect(result.contains("value"))
        #expect(!result.contains("Comment 1"))
        #expect(!result.contains("Comment 2"))
        #expect(!result.contains("Comment 3"))
        #expect(!result.contains("Comment 4"))
    }

    // MARK: - Multi-Line Comment Removal Tests

    @Test("Remove multi-line comment")
    func testRemoveMultiLineComment() {
        let json5 = """
        {
            /* This is a
               multi-line comment */
            "name": "test"
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("name"))
        #expect(!result.contains("multi-line comment"))
    }

    @Test("Remove multiple multi-line comments")
    func testRemoveMultipleMultiLineComments() {
        let json5 = """
        {
            /* Comment 1 */
            "name": "test",
            /* Comment 2 */
            "value": 123
            /* Comment 3 */
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("name"))
        #expect(result.contains("value"))
        #expect(!result.contains("Comment 1"))
        #expect(!result.contains("Comment 2"))
        #expect(!result.contains("Comment 3"))
    }

    @Test("Preserve /* inside string values")
    func testPreserveSlashStarInString() {
        let json5 = """
        {
            "pattern": "/* wildcard */"
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("/* wildcard */"))
    }

    // MARK: - Trailing Comma Removal Tests

    @Test("Remove trailing comma in object")
    func testRemoveTrailingCommaInObject() {
        let json5 = """
        {
            "name": "test",
            "value": 123,
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("123"))
        #expect(!result.contains("123,"))
    }

    @Test("Remove trailing comma in array")
    func testRemoveTrailingCommaInArray() {
        let json5 = """
        [
            "item1",
            "item2",
        ]
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("item2"))
        #expect(!result.contains("item2,"))
    }

    @Test("Remove trailing comma with whitespace")
    func testRemoveTrailingCommaWithWhitespace() {
        let json5 = """
        {
            "name": "test",
            "value": 123  ,
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("123"))
        #expect(!result.contains("123  ,"))
    }

    @Test("Multiple trailing commas")
    func testMultipleTrailingCommas() {
        let json5 = """
        {
            "array": [1, 2, 3,],
            "nested": {
                "a": 1,
                "b": 2,
            },
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        // Should not contain any trailing commas before } or ]
        let lines = result.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix("}") || trimmed.hasSuffix("]") {
                #expect(!trimmed.contains(",}"))
                #expect(!trimmed.contains(",]"))
            }
        }
    }

    // MARK: - Complex JSON5 Tests

    @Test("Handle mixed comments and trailing commas")
    func testMixedCommentsAndTrailingCommas() {
        let json5 = """
        {
            // This is a name field
            "name": "test", // inline comment
            /* This is a multi-line
               comment about the value */
            "value": 123,
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("name"))
        #expect(result.contains("value"))
        #expect(!result.contains("//"))
        #expect(!result.contains("/*"))
        #expect(!result.contains("*/"))
    }

    @Test("Nested objects and arrays with JSON5 features")
    func testNestedStructures() {
        let json5 = """
        {
            // Top-level comment
            "nested": {
                "array": [1, 2, 3,], // trailing comma in array
                "object": {
                    "key": "value", // trailing comma in nested object
                },
            },
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("nested"))
        #expect(result.contains("array"))
        #expect(result.contains("object"))
        #expect(!result.contains("Top-level comment"))
    }

    // MARK: - parseJSON5 Tests

    struct TestModel: Codable, Equatable {
        let name: String
        let value: Int
    }

    @Test("Parse JSON5 to model")
    func testParseJSON5ToModel() throws {
        let json5 = """
        {
            // This is a test model
            "name": "test",
            "value": 123,
        }
        """

        let data = json5.data(using: .utf8)!
        let model = try JSON5Parser.parseJSON5(data, as: TestModel.self)

        #expect(model.name == "test")
        #expect(model.value == 123)
    }

    @Test("Parse JSON5 array")
    func testParseJSON5Array() throws {
        let json5 = """
        [
            {
                "name": "item1",
                "value": 1,
            },
            // Comment between items
            {
                "name": "item2",
                "value": 2,
            },
        ]
        """

        let data = json5.data(using: .utf8)!
        let models = try JSON5Parser.parseJSON5(data, as: [TestModel].self)

        #expect(models.count == 2)
        #expect(models[0].name == "item1")
        #expect(models[1].name == "item2")
    }

    @Test("Parse JSON5 with complex nesting")
    func testParseJSON5ComplexNesting() throws {
        struct ComplexModel: Codable {
            let items: [TestModel]
            let metadata: [String: String]
        }

        let json5 = """
        {
            // Items array
            "items": [
                {
                    "name": "first",
                    "value": 1,
                },
                /* Second item with
                   multi-line comment */
                {
                    "name": "second",
                    "value": 2,
                },
            ],
            // Metadata object
            "metadata": {
                "author": "test",
                "version": "1.0",
            },
        }
        """

        let data = json5.data(using: .utf8)!
        let model = try JSON5Parser.parseJSON5(data, as: ComplexModel.self)

        #expect(model.items.count == 2)
        #expect(model.metadata["author"] == "test")
        #expect(model.metadata["version"] == "1.0")
    }

    // MARK: - Error Handling Tests

    @Test("Invalid encoding throws error")
    func testInvalidEncodingError() {
        let invalidData = Data([0xFF, 0xFE, 0xFD]) // Invalid UTF-8

        do {
            _ = try JSON5Parser.parseJSON5(invalidData, as: TestModel.self)
            Issue.record("Expected error to be thrown")
        } catch let error as JSON5Error {
            #expect(error == .invalidEncoding)
        } catch {
            Issue.record("Expected JSON5Error.invalidEncoding")
        }
    }

    @Test("Malformed JSON5 throws parsing error")
    func testMalformedJSON5Error() {
        let json5 = """
        {
            "name": "test"
            "value": 123  // Missing comma
        }
        """

        let data = json5.data(using: .utf8)!

        do {
            _ = try JSON5Parser.parseJSON5(data, as: TestModel.self)
            Issue.record("Expected error to be thrown")
        } catch let error as JSON5Error {
            if case .parsingFailed(let message) = error {
                #expect(message.contains("decoding failed"))
            } else {
                Issue.record("Expected parsingFailed error")
            }
        } catch {
            // Might also throw DecodingError, which is acceptable
            #expect(true)
        }
    }

    // MARK: - JSON5Error Tests

    @Test("JSON5Error.invalidEncoding has description")
    func testInvalidEncodingErrorDescription() {
        let error = JSON5Error.invalidEncoding
        #expect(error.errorDescription?.contains("encode/decode") == true)
    }

    @Test("JSON5Error.parsingFailed has description with message")
    func testParsingFailedErrorDescription() {
        let error = JSON5Error.parsingFailed("Test error message")
        #expect(error.errorDescription?.contains("Test error message") == true)
    }

    @Test("JSON5Error cases are equatable")
    func testJSON5ErrorEquatable() {
        #expect(JSON5Error.invalidEncoding == JSON5Error.invalidEncoding)
        #expect(JSON5Error.parsingFailed("test") == JSON5Error.parsingFailed("test"))
        #expect(JSON5Error.parsingFailed("test1") != JSON5Error.parsingFailed("test2"))
        #expect(JSON5Error.invalidEncoding != JSON5Error.parsingFailed("test"))
    }

    // MARK: - Edge Cases

    @Test("Empty JSON5 string")
    func testEmptyJSON5() {
        let json5 = ""
        let result = JSON5Parser.convertJSON5ToJSON(json5)
        #expect(result.isEmpty)
    }

    @Test("JSON5 with only comments")
    func testOnlyComments() {
        let json5 = """
        // Just a comment
        /* And another one */
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.isEmpty)
    }

    @Test("Valid JSON is unchanged")
    func testValidJSONUnchanged() {
        let validJSON = """
        {
            "name": "test",
            "value": 123
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(validJSON)

        // Should be parseable as JSON
        let data = result.data(using: .utf8)!
        let decoder = JSONDecoder()
        let model = try? decoder.decode(TestModel.self, from: data)

        #expect(model?.name == "test")
        #expect(model?.value == 123)
    }

    @Test("Escaped quotes in strings are preserved")
    func testEscapedQuotes() {
        let json5 = """
        {
            "text": "He said \\"hello\\" to me"
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)
        #expect(result.contains("He said \\\"hello\\\" to me"))
    }

    @Test("URLs with double slashes are preserved")
    func testURLsPreserved() {
        let json5 = """
        {
            "url": "https://example.com/path",
            "protocol": "http://",
            "comment": "test" // This should be removed
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("https://example.com/path"))
        #expect(result.contains("http://"))
        #expect(!result.contains("This should be removed"))
    }

    @Test("Mixed comment styles")
    func testMixedCommentStyles() {
        let json5 = """
        {
            /* Block comment */ "name": "test", // Line comment
            "value": /* inline block */ 123
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        #expect(result.contains("name"))
        #expect(result.contains("value"))
        #expect(!result.contains("Block comment"))
        #expect(!result.contains("Line comment"))
        #expect(!result.contains("inline block"))
    }

    @Test("Unterminated multi-line comment is handled")
    func testUnterminatedMultiLineComment() {
        let json5 = """
        {
            "name": "test",
            /* This comment is not closed
            "value": 123
        }
        """

        // Should handle gracefully (removes everything after /*)
        let result = JSON5Parser.convertJSON5ToJSON(json5)
        #expect(result.contains("name"))
    }

    @Test("Comment-like strings in data")
    func testCommentLikeStringsInData() {
        let json5 = """
        {
            "pattern": "/* not a comment */",
            "instruction": "Use // to comment",
            "code": "if (a /* inline */ b) {}"
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        // Strings should be preserved
        #expect(result.contains("/* not a comment */"))
        #expect(result.contains("Use // to comment"))
        #expect(result.contains("if (a /* inline */ b) {}"))
    }

    @Test("Whitespace cleanup")
    func testWhitespaceCleanup() {
        let json5 = """
        {
            // Comment 1

            // Comment 2


            // Comment 3
            "name": "test"
        }
        """

        let result = JSON5Parser.convertJSON5ToJSON(json5)

        // Should reduce excessive newlines
        #expect(!result.contains("\n\n\n\n"))
    }
}
