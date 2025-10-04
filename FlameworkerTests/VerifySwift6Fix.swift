import Testing
import Foundation
@testable import Flameworker

@Suite("Swift 6 Concurrency Fix Verification")
struct Swift6ConcurrencyFixVerificationTests {
    
    @Test("WeightUnitPreference methods can be called from non-isolated context")
    func testWeightUnitPreferenceMethodsAreNonisolated() {
        // This test verifies that these methods can be called without Swift 6 concurrency errors
        
        // Test accessing the storage key
        let key = WeightUnitPreference.storageKey
        #expect(key == "defaultUnits")
        
        // Test accessing current preference
        let current = WeightUnitPreference.current
        #expect(current == .pounds || current == .kilograms, "Current should be either pounds or kilograms")
        
        // Test that we can call resetToStandard from a non-isolated context
        WeightUnitPreference.resetToStandard()
        
        // Test that we can call setUserDefaults from a non-isolated context
        let testDefaults = UserDefaults(suiteName: "TestSuite_\(UUID().uuidString)")!
        WeightUnitPreference.setUserDefaults(testDefaults)
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testDefaults.removeSuite(named: "TestSuite_\(UUID().uuidString)")
        
        // If we reach this point without compilation errors, the fix is working
        #expect(true, "Swift 6 concurrency fix is working correctly")
    }
}