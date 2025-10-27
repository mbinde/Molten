//
//  ArrayExtensionsTests.swift
//  MoltenTests
//
//  Created by Claude Code on 10/26/25.
//  Tests for Array+Extensions following TDD and Swift 6 concurrency guidelines
//

import Testing
import Foundation
@testable import Molten

@Suite("Array Extensions Tests")
struct ArrayExtensionsTests {

    // MARK: - chunked(into:) Tests

    @Test("Chunk array into equal-sized chunks")
    func testChunkedEqualSize() {
        let array = [1, 2, 3, 4, 5, 6]
        let chunks = array.chunked(into: 2)

        #expect(chunks.count == 3)
        #expect(chunks[0] == [1, 2])
        #expect(chunks[1] == [3, 4])
        #expect(chunks[2] == [5, 6])
    }

    @Test("Chunk array with uneven division")
    func testChunkedUnevenSize() {
        let array = [1, 2, 3, 4, 5]
        let chunks = array.chunked(into: 2)

        #expect(chunks.count == 3)
        #expect(chunks[0] == [1, 2])
        #expect(chunks[1] == [3, 4])
        #expect(chunks[2] == [5])
    }

    @Test("Chunk empty array")
    func testChunkedEmptyArray() {
        let array: [Int] = []
        let chunks = array.chunked(into: 3)

        #expect(chunks.isEmpty)
    }

    @Test("Chunk with size larger than array")
    func testChunkedLargeSize() {
        let array = [1, 2, 3]
        let chunks = array.chunked(into: 10)

        #expect(chunks.count == 1)
        #expect(chunks[0] == [1, 2, 3])
    }

    @Test("Chunk with size of 1")
    func testChunkedSizeOne() {
        let array = [1, 2, 3]
        let chunks = array.chunked(into: 1)

        #expect(chunks.count == 3)
        #expect(chunks[0] == [1])
        #expect(chunks[1] == [2])
        #expect(chunks[2] == [3])
    }

    @Test("Chunk with zero size returns whole array")
    func testChunkedZeroSize() {
        let array = [1, 2, 3, 4]
        let chunks = array.chunked(into: 0)

        #expect(chunks.count == 1)
        #expect(chunks[0] == [1, 2, 3, 4])
    }

    @Test("Chunk with negative size returns whole array")
    func testChunkedNegativeSize() {
        let array = [1, 2, 3]
        let chunks = array.chunked(into: -1)

        #expect(chunks.count == 1)
        #expect(chunks[0] == [1, 2, 3])
    }

    // MARK: - Safe Subscript Tests

    @Test("Safe subscript with valid index")
    func testSafeSubscriptValidIndex() {
        let array = [10, 20, 30, 40]

        #expect(array[safe: 0] == 10)
        #expect(array[safe: 2] == 30)
        #expect(array[safe: 3] == 40)
    }

    @Test("Safe subscript with negative index returns nil")
    func testSafeSubscriptNegativeIndex() {
        let array = [10, 20, 30]

        #expect(array[safe: -1] == nil)
        #expect(array[safe: -10] == nil)
    }

    @Test("Safe subscript with out of bounds index returns nil")
    func testSafeSubscriptOutOfBounds() {
        let array = [10, 20, 30]

        #expect(array[safe: 3] == nil)
        #expect(array[safe: 100] == nil)
    }

    @Test("Safe subscript on empty array returns nil")
    func testSafeSubscriptEmptyArray() {
        let array: [Int] = []

        #expect(array[safe: 0] == nil)
    }

    // MARK: - removing(_:) Tests

    @Test("Remove single occurrence of element")
    func testRemoveSingleOccurrence() {
        let array = [1, 2, 3, 4, 5]
        let result = array.removing(3)

        #expect(result == [1, 2, 4, 5])
    }

    @Test("Remove multiple occurrences of element")
    func testRemoveMultipleOccurrences() {
        let array = [1, 2, 3, 2, 4, 2, 5]
        let result = array.removing(2)

        #expect(result == [1, 3, 4, 5])
    }

    @Test("Remove element not in array")
    func testRemoveNonExistentElement() {
        let array = [1, 2, 3]
        let result = array.removing(99)

        #expect(result == [1, 2, 3])
    }

    @Test("Remove from empty array")
    func testRemoveFromEmptyArray() {
        let array: [Int] = []
        let result = array.removing(1)

        #expect(result.isEmpty)
    }

    @Test("Remove with strings")
    func testRemoveStrings() {
        let array = ["apple", "banana", "apple", "cherry"]
        let result = array.removing("apple")

        #expect(result == ["banana", "cherry"])
    }

    // MARK: - removing(where:) Tests

    @Test("Remove elements matching predicate")
    func testRemoveWherePredicate() {
        let array = [1, 2, 3, 4, 5, 6]
        let result = array.removing { $0 % 2 == 0 }

        #expect(result == [1, 3, 5])
    }

    @Test("Remove where no elements match")
    func testRemoveWhereNoMatches() {
        let array = [1, 3, 5, 7]
        let result = array.removing { $0 > 10 }

        #expect(result == [1, 3, 5, 7])
    }

    @Test("Remove where all elements match")
    func testRemoveWhereAllMatch() {
        let array = [2, 4, 6, 8]
        let result = array.removing { $0 % 2 == 0 }

        #expect(result.isEmpty)
    }

    // MARK: - Collection.isNotEmpty Tests

    @Test("isNotEmpty returns true for non-empty array")
    func testIsNotEmptyTrue() {
        let array = [1, 2, 3]

        #expect(array.isNotEmpty == true)
    }

    @Test("isNotEmpty returns false for empty array")
    func testIsNotEmptyFalse() {
        let array: [Int] = []

        #expect(array.isNotEmpty == false)
    }

    @Test("isNotEmpty with single element")
    func testIsNotEmptySingleElement() {
        let array = [42]

        #expect(array.isNotEmpty == true)
    }

    // MARK: - grouped(by keyPath:) Tests

    @Test("Group by key path")
    func testGroupedByKeyPath() {
        struct Item {
            let category: String
            let value: Int
        }

        let items = [
            Item(category: "A", value: 1),
            Item(category: "B", value: 2),
            Item(category: "A", value: 3),
            Item(category: "C", value: 4),
            Item(category: "B", value: 5)
        ]

        let grouped = items.grouped(by: \.category)

        #expect(grouped.keys.count == 3)
        #expect(grouped["A"]?.count == 2)
        #expect(grouped["B"]?.count == 2)
        #expect(grouped["C"]?.count == 1)
    }

    @Test("Group empty sequence")
    func testGroupedEmpty() {
        struct Item {
            let category: String
        }

        let items: [Item] = []
        let grouped = items.grouped(by: \.category)

        #expect(grouped.isEmpty)
    }

    // MARK: - grouped(by transform:) Tests

    @Test("Group by transform function")
    func testGroupedByTransform() {
        let numbers = [1, 2, 3, 4, 5, 6, 7, 8]
        let grouped = numbers.grouped { $0 % 3 }

        #expect(grouped.keys.count == 3)
        #expect(grouped[0] == [3, 6])
        #expect(grouped[1] == [1, 4, 7])
        #expect(grouped[2] == [2, 5, 8])
    }

    @Test("Group strings by first character")
    func testGroupedStringsByFirstChar() {
        let words = ["apple", "apricot", "banana", "blueberry", "cherry"]
        let grouped = words.grouped { $0.first! }

        #expect(grouped.keys.count == 3)
        #expect(grouped["a"]?.count == 2)
        #expect(grouped["b"]?.count == 2)
        #expect(grouped["c"]?.count == 1)
    }

    // MARK: - count(where:) Tests

    @Test("Count elements matching predicate")
    func testCountWherePredicate() {
        let numbers = [1, 2, 3, 4, 5, 6, 7, 8]
        let evenCount = numbers.count { $0 % 2 == 0 }

        #expect(evenCount == 4)
    }

    @Test("Count where no elements match")
    func testCountWhereNoMatches() {
        let numbers = [1, 3, 5, 7]
        let evenCount = numbers.count { $0 % 2 == 0 }

        #expect(evenCount == 0)
    }

    @Test("Count where all elements match")
    func testCountWhereAllMatch() {
        let numbers = [2, 4, 6, 8]
        let evenCount = numbers.count { $0 % 2 == 0 }

        #expect(evenCount == 4)
    }

    @Test("Count on empty sequence")
    func testCountWhereEmpty() {
        let numbers: [Int] = []
        let count = numbers.count { $0 > 0 }

        #expect(count == 0)
    }

    // MARK: - removingDuplicates() Tests

    @Test("Remove duplicates preserving order")
    func testRemovingDuplicates() {
        let array = [1, 2, 3, 2, 4, 1, 5, 3]
        let result = array.removingDuplicates()

        #expect(result == [1, 2, 3, 4, 5])
    }

    @Test("Remove duplicates from array with no duplicates")
    func testRemovingDuplicatesNoDuplicates() {
        let array = [1, 2, 3, 4, 5]
        let result = array.removingDuplicates()

        #expect(result == [1, 2, 3, 4, 5])
    }

    @Test("Remove duplicates from empty array")
    func testRemovingDuplicatesEmpty() {
        let array: [Int] = []
        let result = array.removingDuplicates()

        #expect(result.isEmpty)
    }

    @Test("Remove duplicates with strings")
    func testRemovingDuplicatesStrings() {
        let array = ["apple", "banana", "apple", "cherry", "banana"]
        let result = array.removingDuplicates()

        #expect(result == ["apple", "banana", "cherry"])
    }

    // MARK: - removingDuplicates(by:) Tests

    @Test("Remove duplicates by key path")
    func testRemovingDuplicatesByKeyPath() {
        struct Person: Equatable {
            let id: Int
            let name: String
        }

        let people = [
            Person(id: 1, name: "Alice"),
            Person(id: 2, name: "Bob"),
            Person(id: 1, name: "Alice Duplicate"),
            Person(id: 3, name: "Charlie"),
            Person(id: 2, name: "Bob Duplicate")
        ]

        let result = people.removingDuplicates(by: \.id)

        #expect(result.count == 3)
        #expect(result[0].id == 1)
        #expect(result[1].id == 2)
        #expect(result[2].id == 3)
    }

    @Test("Remove duplicates by key path with no duplicates")
    func testRemovingDuplicatesByKeyPathNoDuplicates() {
        struct Item: Equatable {
            let id: Int
        }

        let items = [Item(id: 1), Item(id: 2), Item(id: 3)]
        let result = items.removingDuplicates(by: \.id)

        #expect(result.count == 3)
    }

    // MARK: - removingDuplicatesUnordered() Tests

    @Test("Remove duplicates unordered")
    func testRemovingDuplicatesUnordered() {
        let array = [1, 2, 3, 2, 4, 1, 5, 3]
        let result = array.removingDuplicatesUnordered()

        // Order not guaranteed, so check count and contents
        #expect(result.count == 5)
        #expect(result.contains(1))
        #expect(result.contains(2))
        #expect(result.contains(3))
        #expect(result.contains(4))
        #expect(result.contains(5))
    }

    @Test("Remove duplicates unordered from array with no duplicates")
    func testRemovingDuplicatesUnorderedNoDuplicates() {
        let array = [1, 2, 3, 4, 5]
        let result = array.removingDuplicatesUnordered()

        #expect(result.count == 5)
    }

    @Test("Remove duplicates unordered from empty array")
    func testRemovingDuplicatesUnorderedEmpty() {
        let array: [Int] = []
        let result = array.removingDuplicatesUnordered()

        #expect(result.isEmpty)
    }
}
