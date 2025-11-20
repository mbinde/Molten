//
//  CoreDataHelper.swift
//  Molten
//
//  Helper utilities to eliminate Core Data boilerplate
//

import CoreData
import Foundation

/// Helper to eliminate the withCheckedThrowingContinuation + context.perform boilerplate
/// that appears 100+ times across Core Data repositories
enum CoreDataHelper {

    /// Execute a Core Data operation on a background context and return the result
    /// Eliminates the need to write withCheckedThrowingContinuation + context.perform every time
    ///
    /// Example usage:
    /// ```swift
    /// func fetchItems() async throws -> [ItemModel] {
    ///     try await CoreDataHelper.performAsync(on: backgroundContext) { context in
    ///         let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Item")
    ///         let results = try context.fetch(fetchRequest)
    ///         return results.map { ItemModel(from: $0) }
    ///     }
    /// }
    /// ```
    static func performAsync<T>(
        on context: NSManagedObjectContext,
        _ operation: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            context.perform {
                do {
                    let result = try operation(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Execute a Core Data operation that doesn't return a value
    /// Use this for save/delete operations
    ///
    /// Example usage:
    /// ```swift
    /// func deleteItem(_ id: UUID) async throws {
    ///     try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
    ///         // Find and delete the item
    ///         // Save context
    ///     }
    /// }
    /// ```
    static func performAsyncVoid(
        on context: NSManagedObjectContext,
        _ operation: @escaping @Sendable (NSManagedObjectContext) throws -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    try operation(context)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
