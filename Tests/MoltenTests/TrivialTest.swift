//
//  TrivialTest.swift
//  MoltenTests
//
//  Created for testing add-test-to-xcode.rb script
//

import Testing
@testable import Molten

/// Trivial test to verify add-test-to-xcode.rb script works correctly
@Suite("Trivial Test Suite")
struct TrivialTest {

    @Test("Should pass trivial test")
    func testTrivial() async throws {
        // Arrange
        let value = 1 + 1

        // Assert
        #expect(value == 2)
    }

    @Test("Should handle string comparison")
    func testStringComparison() async throws {
        // Arrange
        let greeting = "Hello"

        // Assert
        #expect(greeting == "Hello")
        #expect(greeting.count == 5)
    }
}
