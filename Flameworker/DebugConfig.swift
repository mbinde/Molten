//
//  DebugConfig.swift
//  Flameworker
//
//  Debug configuration and development utilities
//

import Foundation

// Global typealias to redirect any remaining FeatureFlags references
typealias FeatureFlags = DebugConfig.FeatureFlags

/// Debug configuration for development builds
struct DebugConfig {
    
    // MARK: - Development Utilities
    
    /// Enable verbose logging during development
    static let verboseLogging = true
    
    /// Enable development menu items
    static let showDeveloperMenu = false
    
    /// Enable performance monitoring
    static let performanceMonitoring = false
    
    // MARK: - Built-in Feature Flags for Debug Purposes
    
    struct FeatureFlags {
        // MARK: - Release Configuration
        static let isFullFeaturesEnabled = false
        
        // MARK: - Individual Feature Flags
        static let advancedSearch = isFullFeaturesEnabled
        static let advancedImageLoading = isFullFeaturesEnabled
        static let advancedUIComponents = isFullFeaturesEnabled
        static let performanceOptimizations = isFullFeaturesEnabled
        static let batchOperations = isFullFeaturesEnabled
        static let advancedFiltering = isFullFeaturesEnabled
        static let coeGlassFilter = true
        
        // MARK: - Always Enabled (Core Features)
        static let basicInventoryManagement = true
        static let coreDataPersistence = true
        static let basicSearch = true
        static let userPreferences = true
        
        // MARK: - Feature Flag Helpers
        static var searchImplementation: SearchType {
            return advancedSearch ? .advanced : .basic
        }
        
        static var imageLoadingStrategy: ImageLoadingType {
            return advancedImageLoading ? .async : .sync
        }
    }
    
    enum SearchType {
        case basic
        case advanced
    }

    enum ImageLoadingType {
        case sync
        case async
    }
    
    /// Access to debug feature flags
    static var allFeatureFlags: FeatureFlags.Type {
        return FeatureFlags.self
    }
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
