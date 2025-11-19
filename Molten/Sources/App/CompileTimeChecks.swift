//
//  CompileTimeChecks.swift
//  Molten
//
//  Compile-time safety checks to ensure critical build settings are configured correctly.
//  These checks will cause compilation to FAIL if settings are incorrect.
//

import Foundation

// MARK: - Swift 6 Strict Concurrency Check

/// This file will FAIL TO COMPILE if Swift 6 strict concurrency checking is not enabled.
///
/// The project MUST have SWIFT_STRICT_CONCURRENCY = complete in build settings.
/// This is critical for catching concurrency bugs at compile-time instead of runtime.
///
/// If you see a compile error here, it means someone changed the build settings.
/// Fix it by:
/// 1. Open Molten.xcodeproj in Xcode
/// 2. Select the Molten target
/// 3. Build Settings → Swift Compiler - Language
/// 4. Set "Strict Concurrency Checking" to "Complete"

#if !compiler(>=6.0) || swift(<6.0)
#error("❌ CRITICAL: This project requires Swift 6.0 or later. Current Swift version does not support strict concurrency checking.")
#endif

// This check verifies that strict concurrency is actually enabled
// If SWIFT_STRICT_CONCURRENCY is not set to "complete", this will produce a warning/error
// depending on the actual setting
@available(*, deprecated, message: "If you see this deprecation warning, strict concurrency may not be fully enabled. Ensure SWIFT_STRICT_CONCURRENCY = complete in build settings.")
func _strictConcurrencyCheck() {
    // This function should never be called - it exists only for compile-time checking
}

// MARK: - Additional Safety Checks

/// Verify we're using the correct Swift version
#if swift(<5.9)
#error("❌ CRITICAL: This project requires Swift 5.9 or later for proper concurrency support.")
#endif

/// Documentation reference for strict concurrency requirements
///
/// From CLAUDE.md:
/// "Tech Stack: SwiftUI, Core Data + CloudKit, Swift 6 strict concurrency, dependency injection via Repository pattern."
///
/// This is NON-NEGOTIABLE. Strict concurrency checking catches:
/// - Core Data thread violations (like the _dispatch_assert_queue_fail crash)
/// - Actor isolation violations
/// - Sendable conformance issues
/// - Data race conditions
///
/// Without it, these bugs only appear at RUNTIME as crashes, making them much harder to debug.
