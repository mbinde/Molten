//
//  DebugConfig.swift
//  Flameworker
//
//  Debug configuration and development utilities
//

import Foundation
import SwiftUI

/// Debug configuration for development builds
struct DebugConfig {

    // MARK: - Development Utilities

    /// Enable verbose logging during development
    static let verboseLogging = true

    /// Enable development menu items
    static let showDeveloperMenu = false

    /// Enable performance monitoring
    static let performanceMonitoring = false

    // MARK: - Subscription Tier Override (Debug/Testing)

    /// Enable subscription tier override for testing
    /// When true, uses debugSubscriptionTier instead of actual subscription status
    @AppStorage("debugOverrideSubscriptionTier") static var debugOverrideSubscriptionTier = false

    /// Debug subscription tier (only used when debugOverrideSubscriptionTier is true)
    /// 0 = free, 1 = premium
    @AppStorage("debugSubscriptionTierValue") static var debugSubscriptionTierValue = 0

    /// Get the debug subscription tier
    static var debugSubscriptionTier: SubscriptionTier {
        return debugSubscriptionTierValue == 1 ? .premium : .free
    }

    // MARK: - Performance Testing

    /// Disable image loading to test performance (temporary for debugging)
    /// Set to true to disable all product image loading
    /// NOTE: Testing confirmed images are NOT causing first-run keyboard delays
    /// (the delay was Xcode debugging overhead)
    static var disableImageLoading = false

    // MARK: - Feature Flags
    // NOTE: Feature flags have been moved to FeatureFlags.swift for better organization
}

// MARK: - Debug Utilities

extension DebugConfig {
    
    /// Print debug information if verbose logging is enabled
    static func debugPrint(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard verboseLogging else { return }
        let filename = (file as NSString).lastPathComponent
        print("🐛 [\(filename):\(line)] \(function): \(message)")
    }
    
    /// Log feature flag status for debugging
    static func logFeatureFlagStatus() {
        guard verboseLogging else { return }
        print("🚩 Feature Flags Status:")
        print("   Full Features Enabled: \(FeatureFlags.isFullFeaturesEnabled)")
        print("   Advanced Search: \(FeatureFlags.advancedSearch)")
        print("   Advanced Filtering: \(FeatureFlags.advancedFiltering)")
        print("   Advanced Image Loading: \(FeatureFlags.advancedImageLoading)")
        print("   Core Features: Always Enabled")
    }
}
