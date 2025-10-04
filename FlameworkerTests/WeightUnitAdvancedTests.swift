//  WeightUnitAdvancedTests.swift
//  FlameworkerTests
//
//  Extracted from FlameworkerTests.swift on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("WeightUnit Edge Cases Tests")
struct WeightUnitEdgeCasesTests {
    
    @Test("WeightUnit conversion handles zero values")
    func testConversionWithZeroValues() {
        let poundsToKg = WeightUnit.pounds.convert(0.0, to: .kilograms)
        #expect(poundsToKg == 0.0, "Zero pounds should convert to zero kilograms")
        
        let kgToPounds = WeightUnit.kilograms.convert(0.0, to: .pounds)
        #expect(kgToPounds == 0.0, "Zero kilograms should convert to zero pounds")
    }
    
    @Test("WeightUnit conversion handles negative values")
    func testConversionWithNegativeValues() {
        let result = WeightUnit.pounds.convert(-10.0, to: .kilograms)
        #expect(result < 0, "Negative input should produce negative output")
        #expect(abs(result - (-4.53592)) < 0.0001, "Should correctly convert negative values")
    }
    
    @Test("WeightUnit conversion handles very large values")
    func testConversionWithLargeValues() {
        let largeValue = 1000000.0
        let result = WeightUnit.pounds.convert(largeValue, to: .kilograms)
        #expect(result > 0, "Should handle large values without overflow")
        #expect(abs(result - (largeValue * 0.453592)) < 1.0, "Should maintain precision with large values")
    }
    
    @Test("WeightUnit conversion handles very small values")
    func testConversionWithSmallValues() {
        let smallValue = 0.001
        let result = WeightUnit.pounds.convert(smallValue, to: .kilograms)
        #expect(result > 0, "Should handle small positive values")
        #expect(abs(result - (smallValue * 0.453592)) < 0.000001, "Should maintain precision with small values")
    }
}

@Suite("WeightUnit Thread Safety Tests")
struct WeightUnitThreadSafetyTests {
    
    @Test("WeightUnitPreference thread safety with concurrent access")
    func testWeightUnitPreferenceThreadSafety() async {
        let testSuiteName = "ThreadSafetyTest_\(UUID().uuidString)"
        guard let testUserDefaults = UserDefaults(suiteName: testSuiteName) else {
            Issue.record("Failed to create test UserDefaults")
            return
        }
        
        testUserDefaults.set("Pounds", forKey: WeightUnitPreference.storageKey)
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        // Test concurrent access to WeightUnitPreference.current
        await withTaskGroup(of: WeightUnit.self) { group in
            // Add multiple concurrent tasks
            for _ in 0..<10 {
                group.addTask {
                    return WeightUnitPreference.current
                }
            }
            
            // Collect all results
            var results: [WeightUnit] = []
            for await result in group {
                results.append(result)
            }
            
            // All results should be consistent
            #expect(results.count == 10, "Should have 10 results")
            #expect(results.allSatisfy { $0 == .pounds }, "All concurrent reads should return same value")
        }
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
}