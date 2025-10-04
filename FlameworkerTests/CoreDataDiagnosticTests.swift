//  CoreDataDiagnosticTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation

@Suite("Core Data Diagnostic Tests")
struct CoreDataDiagnosticTests {
    
    @Test("Basic test without main app import")
    func testWithoutMainAppImport() {
        // This test doesn't import the main app to see if that's causing the issue
        let basicString = "test"
        #expect(!basicString.isEmpty)
    }
}