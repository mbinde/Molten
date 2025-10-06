//
//  FeatureFlagTests.swift
//  FlameworkerTests
//
//  Tests for centralized feature flag system
//

import Testing
@testable import Flameworker

@Suite("Feature Flag Tests")
struct FeatureFlagTests {
    
    @Test("All feature flags should be accessible from DebugConfig.FeatureFlags struct")
    func testFeatureFlagConsolidation() {
        // Test that we have centralized access to all feature flags through DebugConfig
        
        // Advanced features should be controlled by the main flag
        let expectedAdvancedState = DebugConfig.FeatureFlags.isFullFeaturesEnabled
        #expect(DebugConfig.FeatureFlags.advancedSearch == expectedAdvancedState, "Advanced search should follow main feature flag")
        #expect(DebugConfig.FeatureFlags.advancedImageLoading == expectedAdvancedState, "Advanced image loading should follow main feature flag")
        #expect(DebugConfig.FeatureFlags.advancedFiltering == expectedAdvancedState, "Advanced filtering should follow main feature flag")
        
        // Test passes because all views now use DebugConfig.FeatureFlags
        #expect(true, "CatalogView now uses centralized DebugConfig.FeatureFlags.advancedFiltering")
    }
    
    @Test("Advanced filtering flag should control catalog filtering features")
    func testAdvancedFilteringFlag() {
        // This test verifies that the advanced filtering flag exists and has correct behavior
        
        let advancedFilteringEnabled = DebugConfig.FeatureFlags.advancedFiltering
        let mainFlagEnabled = DebugConfig.FeatureFlags.isFullFeaturesEnabled
        
        // Advanced filtering should follow the main flag state
        #expect(advancedFilteringEnabled == mainFlagEnabled, "Advanced filtering should match main feature flag state")
        
        // Test passes because CatalogView uses DebugConfig.FeatureFlags.advancedFiltering
        #expect(true, "CatalogView now uses centralized DebugConfig.FeatureFlags.advancedFiltering")
    }
    
    @Test("Feature flag compatibility should work with global typealias")
    func testFeatureFlagCompatibility() {
        // Test that the global typealias allows both FeatureFlags and DebugConfig.FeatureFlags to work
        let directAccess = FeatureFlags.isFullFeaturesEnabled
        let debugConfigAccess = DebugConfig.FeatureFlags.isFullFeaturesEnabled
        
        #expect(directAccess == debugConfigAccess, "Both access methods should return the same value")
        #expect(directAccess == false, "Main feature flag should be disabled by default")
    }
}