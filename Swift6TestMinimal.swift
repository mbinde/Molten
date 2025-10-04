//
//  Swift6TestMinimal.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
@testable import Flameworker

// Minimal test to isolate the Swift 6 concurrency issue
@Suite("Minimal Swift 6 Test")
struct Swift6TestMinimal {
    
    @Test("Basic enum equality test")
    func testBasicEnumEquality() {
        // Test the most basic enum usage to see where the issue comes from
        let impact1 = ImpactFeedbackStyle.light
        let impact2 = ImpactFeedbackStyle.light
        
        // This should work without any actor isolation issues
        #expect(impact1 == impact2)
    }
    
    @Test("Array contains test")
    func testArrayContains() {
        let impacts: [ImpactFeedbackStyle] = [.light, .medium]
        
        // This uses Equatable conformance
        #expect(impacts.contains(.light))
    }
    
    @Test("Set operations test")
    func testSetOperations() {
        let impactSet: Set<ImpactFeedbackStyle> = [.light, .medium]
        
        // This uses Hashable conformance
        #expect(impactSet.contains(.light))
    }
}