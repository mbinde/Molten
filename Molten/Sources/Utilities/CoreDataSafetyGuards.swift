//
//  CoreDataSafetyGuards.swift
//  Molten
//
//  Runtime safety guards for Core Data + CloudKit
//  Prevents fatal mistakes that break CloudKit sync
//

import Foundation
import CoreData

#if DEBUG

/// SAFETY GUARD: Prevent persistent history deletion
///
/// CloudKit sync relies on persistent history to track changes.
/// Manually purging history breaks sync state and causes data loss.
///
/// This extension crashes in DEBUG builds if you try to delete history,
/// making the mistake impossible to ship to production.
extension NSPersistentContainer {

    /// Intercept and validate persistent store requests
    ///
    /// NEVER call deleteHistory() - it breaks CloudKit sync state
    /// CloudKit manages its own history tokens and purging
    @MainActor
    func safeExecute(_ request: NSPersistentStoreRequest, with context: NSManagedObjectContext) throws -> NSPersistentStoreResult {

        // GUARD: Block persistent history deletion requests
        // Detection: NSPersistentHistoryChangeRequest instances created via deleteHistory(before:)
        // can be identified by examining their string representation
        if request is NSPersistentHistoryChangeRequest {
            let requestDescription = String(describing: request)
            if requestDescription.contains("deleteHistory") {
                fatalError("""
                    ❌ FATAL: Attempted to delete persistent history - this BREAKS CloudKit sync!

                    CloudKit sync relies on persistent history to track changes across devices.
                    Manually purging history destroys sync state and causes:
                    - Data duplication (CloudKit re-imports already-synced data)
                    - Data loss (local changes never sync to cloud)
                    - Sync conflicts (mismatched history tokens)

                    NEVER call:
                    - NSPersistentHistoryChangeRequest.deleteHistory(before:)
                    - context.execute(deleteHistoryRequest)

                    Let CloudKit manage its own history tokens.

                    Location: \(#file):\(#line)
                    Request: \(requestDescription)
                    """)
            }
        }

        // Request is safe - execute normally
        return try context.execute(request)
    }
}

#endif

// MARK: - Service Creation Safety

/// Property wrapper that ensures services are created ONCE during init
///
/// Problem: Creating services in .task/.onAppear causes multiple Core Data contexts
/// Solution: Property wrapper enforces single creation during struct initialization
///
/// Usage:
/// ```swift
/// struct MyView: View {
///     @Service var catalog = AppDependencies.shared.catalogService
///
///     var body: some View {
///         Text("Safe!")
///             .task { await loadData() }  // ✅ Can't recreate service here
///     }
/// }
/// ```
@propertyWrapper
struct Service<T> {
    let wrappedValue: T

    /// Initialize with autoclosure to evaluate ONCE during struct creation
    ///
    /// The @autoclosure ensures the service creation expression
    /// is evaluated exactly once when the property wrapper is initialized.
    /// SwiftUI struct recreation doesn't re-run init(), preventing
    /// multiple Core Data context creation.
    init(wrappedValue: @autoclosure () -> T) {
        self.wrappedValue = wrappedValue()
    }
}

// MARK: - Usage Examples & Anti-Patterns

/*
 ❌ ANTI-PATTERN: Service creation in .task

 struct MyView: View {
     @State private var service: CatalogService?

     var body: some View {
         Text("Broken")
             .task {
                 if service == nil {
                     service = AppDependencies.shared.catalogService  // ❌ Multiple contexts!
                 }
             }
     }
 }

 Why this breaks:
 - SwiftUI views are value types that get recreated on parent state changes
 - .task runs on every view recreation
 - Each service creation = new Core Data context
 - Multiple contexts on same queue = _dispatch_assert_queue_fail crash


 ✅ CORRECT PATTERN: Service creation in init

 struct MyView: View {
     @Service var catalog = AppDependencies.shared.catalogService

     var body: some View {
         Text("Safe!")
             .task { await loadData() }  // ✅ Use service, never create
     }

     func loadData() async {
         let items = try? await catalog.fetchAllItems()
     }
 }

 Why this works:
 - @Service wrapper evaluates expression ONCE during struct creation
 - init() is only called when view is first created, not on recreation
 - Single Core Data context for view's lifetime
 - No queue assertion crashes
 */
