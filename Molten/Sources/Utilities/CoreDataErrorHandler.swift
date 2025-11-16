//
//  CoreDataErrorHandler.swift
//  Molten
//
//  Enhanced error reporting for Core Data operations
//  Provides context about where errors occur to aid debugging
//

import Foundation
import CoreData
import OSLog

/// Utility for reporting Core Data errors with enhanced context
enum CoreDataErrorHandler {
    private static let log = Logger(subsystem: "com.flameworker.app", category: "coredata-errors")

    /// Saves a Core Data context with enhanced error reporting
    /// - Parameters:
    ///   - context: The managed object context to save
    ///   - function: The calling function name (use #function)
    ///   - file: The calling file name (use #fileID)
    ///   - line: The calling line number (use #line)
    /// - Throws: The original Core Data error after logging details
    static func save(
        context: NSManagedObjectContext,
        function: String = #function,
        file: String = #fileID,
        line: Int = #line
    ) throws {
        do {
            try context.save()
        } catch let error as NSError {
            // Extract just the filename from the full path
            let filename = file.components(separatedBy: "/").last ?? file

            // Log detailed error information
            log.error("❌ Core Data save failed in \(filename):\(line) \(function)")
            log.error("   Error: \(error.localizedDescription)")
            log.error("   Domain: \(error.domain), Code: \(error.code)")

            // Print to console for test visibility
            print("❌ Core Data save failed in \(filename):\(line) \(function)")
            print("   Error: \(error.localizedDescription)")
            print("   Domain: \(error.domain), Code: \(error.code)")

            // Log userInfo for additional context (especially for configuration errors)
            if let userInfo = error.userInfo as? [String: Any] {
                // Format userInfo for better readability
                let formattedUserInfo = userInfo.map { key, value in
                    "      \(key): \(value)"
                }.joined(separator: "\n")
                log.error("   UserInfo:\n\(formattedUserInfo)")
                print("   UserInfo:")
                for (key, value) in userInfo {
                    print("      \(key): \(value)")
                }
            }

            // For configuration mismatch errors, provide additional guidance
            if error.domain == NSCocoaErrorDomain && error.code == 134100 {
                // 134100 = NSPersistentStoreIncompatibleVersionHashError
                log.error("   ⚠️  This is a model configuration mismatch error")
                log.error("   💡 Likely causes:")
                log.error("      - Entity belongs to different configuration than store")
                log.error("      - Two-store architecture issue (Local vs Cloud)")
                log.error("      - Migration needed or failed")
                print("   ⚠️  This is a model configuration mismatch error")
                print("   💡 Likely causes:")
                print("      - Entity belongs to different configuration than store")
                print("      - Two-store architecture issue (Local vs Cloud)")
                print("      - Migration needed or failed")
            }

            // Re-throw the original error
            throw error
        }
    }

    /// Saves a Core Data context asynchronously with enhanced error reporting
    /// - Parameters:
    ///   - context: The managed object context to save
    ///   - function: The calling function name (use #function)
    ///   - file: The calling file name (use #fileID)
    ///   - line: The calling line number (use #line)
    /// - Throws: The original Core Data error after logging details
    static func saveAsync(
        context: NSManagedObjectContext,
        function: String = #function,
        file: String = #fileID,
        line: Int = #line
    ) async throws {
        try await context.perform {
            try save(context: context, function: function, file: file, line: line)
        }
    }
}
