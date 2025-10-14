//  CollectionSafetyUtilities.swift
//  Flameworker
//
//  Created by Assistant on 10/11/25.
//

import Foundation

/// Utility class for safe collection operations to prevent index out of bounds crashes
struct CollectionSafetyUtilities {
    
    /// Safely accesses an element at the specified index
    /// - Parameters:
    ///   - index: The index to access
    ///   - collection: The collection to access
    /// - Returns: The element at the index if valid, nil otherwise
    static func safeElement<T>(at index: Int, in collection: [T]) -> T? {
        guard index >= 0 && index < collection.count else {
            return nil
        }
        return collection[index]
    }
    
    /// Safely gets the first element of a collection
    /// - Parameter collection: The collection to access
    /// - Returns: The first element if it exists, nil otherwise
    static func safeFirst<T>(in collection: [T]) -> T? {
        return collection.first
    }
    
    /// Safely gets the last element of a collection
    /// - Parameter collection: The collection to access  
    /// - Returns: The last element if it exists, nil otherwise
    static func safeLast<T>(in collection: [T]) -> T? {
        return collection.last
    }
}