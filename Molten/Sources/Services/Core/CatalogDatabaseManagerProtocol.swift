//
//  CatalogDatabaseManagerProtocol.swift
//  Molten
//
//  Protocol for catalog database managers (production and test)
//

import Foundation
import SQLite3

/// Protocol for database managers that provide SQLite connections
protocol CatalogDatabaseManagerProtocol: Sendable {
    /// Perform a database operation with thread-safe access to the connection
    /// - Parameter operation: A closure that receives the database connection and performs operations
    /// - Returns: The result of the operation
    nonisolated func performDatabaseOperation<T>(_ operation: (OpaquePointer) throws -> T) throws -> T
}
