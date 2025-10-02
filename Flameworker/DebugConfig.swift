//
//  DebugConfig.swift
//  Flameworker
//
//  Created by Assistant on 10/2/25.
//

import Foundation

/// Centralized debug configuration for all logging flags in the application
/// Set flags to true to enable detailed logging for specific components
struct DebugConfig {
    
    // MARK: - Data Loading Debug Flags
    
    /// Enable detailed logging for DataLoadingService operations
    /// Shows JSON loading progress, merge operations, and item processing
    static let dataLoadingEnabled = false
    
    /// Enable detailed logging for CatalogItemManager operations  
    /// Shows item creation, updates, code construction, and attribute changes
    static let catalogManagementEnabled = false
    
    // MARK: - Future Debug Flags (Examples)
    
    /// Enable detailed logging for Core Data operations
    /// Shows fetch requests, saves, and entity management
    static let coreDataEnabled = false
    
    /// Enable detailed logging for UI operations
    /// Shows view updates, user interactions, and navigation
    static let userInterfaceEnabled = false
    
    /// Enable detailed logging for network operations
    /// Shows API calls, responses, and data synchronization
    static let networkEnabled = false
    
    /// Enable detailed logging for search and filtering operations
    /// Shows search queries, filter applications, and result processing
    static let searchEnabled = false
    
    // MARK: - Convenience Methods
    
    /// Enable all debug flags (useful for comprehensive debugging)
    static func enableAllFlags() -> DebugConfig.Type {
        // Note: This would require making the properties mutable
        // For now, manually change the flags above to true
        print("⚠️ To enable all flags, manually set them to true in DebugConfig.swift")
        return DebugConfig.self
    }
    
    /// Disable all debug flags (useful for production builds)
    static func disableAllFlags() -> DebugConfig.Type {
        // Note: This would require making the properties mutable
        // For now, manually change the flags above to false
        print("⚠️ To disable all flags, manually set them to false in DebugConfig.swift")
        return DebugConfig.self
    }
    
    // MARK: - Debug Status Summary
    
    /// Print current debug configuration to console
    static func printCurrentConfig() {
        print("🐛 Debug Configuration Status:")
        print("   Data Loading: \(dataLoadingEnabled ? "✅ ON" : "❌ OFF")")
        print("   Catalog Management: \(catalogManagementEnabled ? "✅ ON" : "❌ OFF")")
        print("   Core Data: \(coreDataEnabled ? "✅ ON" : "❌ OFF")")
        print("   User Interface: \(userInterfaceEnabled ? "✅ ON" : "❌ OFF")")
        print("   Network: \(networkEnabled ? "✅ ON" : "❌ OFF")")
        print("   Search: \(searchEnabled ? "✅ ON" : "❌ OFF")")
    }
}

// MARK: - Alternative Approach Using Environment Variables (Advanced)

/// Alternative debug configuration using environment variables or compiler flags
/// This approach allows runtime configuration without recompiling
#if DEBUG
extension DebugConfig {
    /// Check if a debug flag is enabled via environment variable
    /// Usage: DebugConfig.isEnabled("DATA_LOADING_DEBUG")
    static func isEnabled(_ flagName: String) -> Bool {
        // Check environment variable first
        if let envValue = ProcessInfo.processInfo.environment[flagName] {
            return envValue.lowercased() == "true" || envValue == "1"
        }
        
        // Fall back to compile-time flags based on name
        switch flagName {
        case "DATA_LOADING_DEBUG":
            return dataLoadingEnabled
        case "CATALOG_MANAGEMENT_DEBUG":
            return catalogManagementEnabled
        case "CORE_DATA_DEBUG":
            return coreDataEnabled
        case "UI_DEBUG":
            return userInterfaceEnabled
        case "NETWORK_DEBUG":
            return networkEnabled
        case "SEARCH_DEBUG":
            return searchEnabled
        default:
            return false
        }
    }
}
#endif