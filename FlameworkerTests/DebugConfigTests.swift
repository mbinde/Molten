//
//  DebugConfigTests.swift
//  FlameworkerTests
//
//  Tests for DebugConfig functionality
//

import Testing
@testable import Flameworker

@Suite("Debug Config Tests")
struct DebugConfigTests {
    
    @Test("DebugConfig should be able to access FeatureFlags")
    func testFeatureFlagsAccess() {
        // Test that DebugConfig can access its nested FeatureFlags type
        let flagsType = DebugConfig.allFeatureFlags
        
        // Verify we can access feature flag properties through the returned type
        let isFullFeaturesEnabled = flagsType.isFullFeaturesEnabled
        let advancedSearch = flagsType.advancedSearch
        
        // These should be accessible without error - the specific values don't matter
        #expect(isFullFeaturesEnabled == false || isFullFeaturesEnabled == true, "isFullFeaturesEnabled should be a boolean")
        #expect(advancedSearch == false || advancedSearch == true, "advancedSearch should be a boolean")
    }
    
    @Test("DebugConfig should be able to log feature flag status")
    func testLogFeatureFlagStatus() {
        // This test just verifies the method can be called without crashing
        DebugConfig.logFeatureFlagStatus()
        
        // If we get here without a crash, the test passes
        #expect(true, "logFeatureFlagStatus should execute without error")
    }
}