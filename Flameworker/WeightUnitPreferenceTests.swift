//  WeightUnitPreferenceTests.swift
//  FlameworkerTests
//
//  Extracted from FlameworkerTests.swift on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("WeightUnitPreference Tests", .serialized)
struct WeightUnitPreferenceTests {
    
    @Test("Current weight unit defaults to pounds when no preference set")
    func testDefaultToPounds() async {
        let testSuiteName = "DefaultTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Ensure clean start
        WeightUnitPreference.resetToStandard()
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        // Add a small delay to ensure UserDefaults has properly synchronized
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Verify no value is set (should be nil in fresh UserDefaults)
        let storedValue = testUserDefaults.string(forKey: WeightUnitPreference.storageKey)
        #expect(storedValue == nil, "Fresh UserDefaults should have no value, but got: \(storedValue ?? "nil")")
        
        let current = WeightUnitPreference.current
        #expect(current == .pounds, "Should default to pounds when no preference is set, but got: \(current)")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Current weight unit defaults to pounds when empty string preference")
    func testDefaultToPoundsWithEmptyString() {
        let testSuiteName = "EmptyTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Ensure clean start
        WeightUnitPreference.resetToStandard()
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        testUserDefaults.set("", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        
        let current = WeightUnitPreference.current
        #expect(current == .pounds, "Should default to pounds when preference is empty string, but got: \(current)")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Current weight unit returns pounds for 'Pounds' preference")
    func testPoundsPreference() async {
        let testSuiteName = "PoundsTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Ensure clean start
        WeightUnitPreference.resetToStandard()
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        testUserDefaults.set("Pounds", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        
        // Add a small delay to ensure UserDefaults has properly synchronized
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let current = WeightUnitPreference.current
        #expect(current == .pounds, "Should return pounds for 'Pounds' preference, but got: \(current)")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Current weight unit returns kilograms for 'Kilograms' preference")
    func testKilogramsPreference() async {
        let testSuiteName = "KilogramsTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Ensure clean start
        WeightUnitPreference.resetToStandard()
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        
        testUserDefaults.set("Kilograms", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        
        // Add a small delay to ensure UserDefaults has properly synchronized
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Verify the value was actually set
        let storedValue = testUserDefaults.string(forKey: WeightUnitPreference.storageKey)
        #expect(storedValue == "Kilograms", "UserDefaults should store 'Kilograms', but got: \(storedValue ?? "nil")")
        
        let current = WeightUnitPreference.current
        #expect(current == .kilograms, "Should return kilograms for 'Kilograms' preference, but got: \(current)")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Current weight unit defaults to pounds for invalid preference")
    func testInvalidPreferenceDefaultsToPounds() {
        let testSuiteName = "InvalidTest_\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Ensure clean start
        WeightUnitPreference.resetToStandard()
        WeightUnitPreference.setUserDefaults(testUserDefaults)
        testUserDefaults.set("InvalidUnit", forKey: WeightUnitPreference.storageKey)
        testUserDefaults.synchronize()
        
        let current = WeightUnitPreference.current
        #expect(current == .pounds, "Should default to pounds for invalid preference, but got: \(current)")
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testUserDefaults.removeSuite(named: testSuiteName)
    }
}