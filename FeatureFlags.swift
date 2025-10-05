import Foundation

/// Feature flags for controlling app complexity during releases
struct FeatureFlags {
    
    // MARK: - Release Configuration
    
    /// Set to false for simplified release builds
    static let isFullFeaturesEnabled = false
    
    // MARK: - Individual Feature Flags
    
    /// Advanced search with fuzzy matching and filters
    static let advancedSearch = isFullFeaturesEnabled
    
    /// Async image loading with caching
    static let advancedImageLoading = isFullFeaturesEnabled
    
    /// Complex UI components and animations
    static let advancedUIComponents = isFullFeaturesEnabled
    
    /// Performance optimizations and caching
    static let performanceOptimizations = isFullFeaturesEnabled
    
    /// Batch Core Data operations
    static let batchOperations = isFullFeaturesEnabled
    
    /// Advanced filtering and sorting
    static let advancedFiltering = isFullFeaturesEnabled
    
    // MARK: - Always Enabled (Core Features)
    
    /// Basic CRUD operations - always enabled
    static let basicInventoryManagement = true
    
    /// Core Data persistence - always enabled
    static let coreDataPersistence = true
    
    /// Basic search - always enabled
    static let basicSearch = true
    
    /// User preferences - always enabled
    static let userPreferences = true
}

// MARK: - Feature Flag Helpers

extension FeatureFlags {
    
    /// Returns the appropriate search implementation based on feature flags
    static var searchImplementation: SearchType {
        return advancedSearch ? .advanced : .basic
    }
    
    /// Returns the appropriate image loading strategy
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