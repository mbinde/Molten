//
//  Array+Extensions.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Extensions for Array to provide common utility methods
extension Array {
    /// Split array into chunks of specified size
    /// - Parameter size: The maximum size of each chunk
    /// - Returns: An array of arrays, each containing at most `size` elements
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }

        var result: [[Element]] = []
        var currentIndex = 0

        while currentIndex < count {
            let endIndex = Swift.min(currentIndex + size, count)
            let chunk = Array(self[currentIndex..<endIndex])
            result.append(chunk)
            currentIndex = endIndex
        }

        return result
    }
    
    /// Safely access an element at the specified index
    /// - Parameter index: The index to access
    /// - Returns: The element at the index if valid, nil otherwise
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
    
    /// Remove all occurrences of the specified element
    /// - Parameter element: The element to remove
    /// - Returns: A new array with all occurrences of the element removed
    func removing(_ element: Element) -> [Element] where Element: Equatable {
        var result: [Element] = []
        for item in self {
            if item != element {
                result.append(item)
            }
        }
        return result
    }
    
    /// Remove all occurrences of elements that match the predicate
    /// - Parameter predicate: A closure that takes an element and returns true if it should be removed
    /// - Returns: A new array with matching elements removed
    func removing(where predicate: @Sendable (Element) throws -> Bool) rethrows -> [Element] {
        var result: [Element] = []
        for item in self {
            if try !predicate(item) {
                result.append(item)
            }
        }
        return result
    }
}

// MARK: - Collection Extensions

extension Collection {
    /// Check if the collection is not empty
    var isNotEmpty: Bool {
        return !isEmpty
    }
}

// MARK: - Sequence Extensions

extension Sequence {
    /// Group elements by a key derived from each element
    /// - Parameter keyPath: A key path to the property to group by
    /// - Returns: A dictionary where keys are the grouping values and values are arrays of elements
    func grouped<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Key: [Element]] {
        return Dictionary(grouping: self) { $0[keyPath: keyPath] }
    }
    
    /// Group elements by the result of a transform function
    /// - Parameter transform: A closure that transforms an element into a grouping key
    /// - Returns: A dictionary where keys are the grouping values and values are arrays of elements
    func grouped<Key: Hashable>(by transform: @Sendable (Element) throws -> Key) rethrows -> [Key: [Element]] {
        return try Dictionary(grouping: self, by: transform)
    }
    
    /// Count elements that match a predicate
    /// - Parameter predicate: A closure that returns true for elements to count
    /// - Returns: The number of elements that match the predicate
    func count(where predicate: @Sendable (Element) throws -> Bool) rethrows -> Int {
        return try filter(predicate).count
    }
}

// MARK: - Array-specific Extensions

extension Array where Element: Equatable {
    /// Remove duplicates while preserving order
    /// - Returns: A new array with duplicates removed
    func removingDuplicates() -> [Element] {
        var result: [Element] = []
        for element in self {
            if !result.contains(element) {
                result.append(element)
            }
        }
        return result
    }
    
    /// Remove duplicates using a key path for comparison
    /// - Parameter keyPath: The key path to use for duplicate detection
    /// - Returns: A new array with duplicates removed based on the key path
    func removingDuplicates<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Element] {
        var seen: Set<Key> = []
        var result: [Element] = []
        
        for element in self {
            let key = element[keyPath: keyPath]
            if !seen.contains(key) {
                seen.insert(key)
                result.append(element)
            }
        }
        return result
    }
}

extension Array where Element: Hashable {
    /// Remove duplicates using Set for O(n) performance
    /// - Returns: A new array with duplicates removed (order may not be preserved)
    func removingDuplicatesUnordered() -> [Element] {
        return Array(Set(self))
    }
}