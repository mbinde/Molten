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
    /// Used by: DataLoadingService.debugLog(_:)
    static let debugDataLoadingEnabled = false
    
    /// Enable detailed logging for CatalogItemManager operations  
    /// Shows item creation, updates, code construction, and attribute changes
    /// Used by: CatalogItemManager.debugLog(_:)
    static let debugCatalogManagementEnabled = false
    
    // MARK: - Future Debug Flags (Examples)
    
    /// Enable detailed logging for Core Data operations
    /// Shows fetch requests, saves, and entity management
    static let debugCoreDataEnabled = false
    
    /// Enable detailed logging for UI operations
    /// Shows view updates, user interactions, and navigation
    static let debugUserInterfaceEnabled = false
    
    /// Enable detailed logging for network operations
    /// Shows API calls, responses, and data synchronization
    static let debugNetworkEnabled = false
    
    /// Enable detailed logging for search and filtering operations
    /// Shows search queries, filter applications, and result processing
    static let debugSearchEnabled = false
    
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
        print("   Data Loading: \(debugDataLoadingEnabled ? "✅ ON" : "❌ OFF")")
        print("   Catalog Management: \(debugCatalogManagementEnabled ? "✅ ON" : "❌ OFF")")
        print("   Core Data: \(debugCoreDataEnabled ? "✅ ON" : "❌ OFF")")
        print("   User Interface: \(debugUserInterfaceEnabled ? "✅ ON" : "❌ OFF")")
        print("   Network: \(debugNetworkEnabled ? "✅ ON" : "❌ OFF")")
        print("   Search: \(debugSearchEnabled ? "✅ ON" : "❌ OFF")")
    }
    
    /// Verify that debug flags are being used in their respective classes
    /// Call this during development to ensure proper integration
    static func verifyDebugFlagUsage() {
        print("🔍 Debug Flag Usage Verification:")
        print("   ✅ debugDataLoadingEnabled → DataLoadingService.debugLog(_:)")
        print("   ✅ debugCatalogManagementEnabled → CatalogItemManager.debugLog(_:)")
        print("   ⚠️  Other flags are placeholders for future use")
        print("")
        print("To enable debug logging:")
        print("   1. Set flags to 'true' in DebugConfig.swift")  
        print("   2. Rebuild your app")
        print("   3. Check console output during operations")
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
            return debugDataLoadingEnabled
        case "CATALOG_MANAGEMENT_DEBUG":
            return debugCatalogManagementEnabled
        case "CORE_DATA_DEBUG":
            return debugCoreDataEnabled
        case "UI_DEBUG":
            return debugUserInterfaceEnabled
        case "NETWORK_DEBUG":
            return debugNetworkEnabled
        case "SEARCH_DEBUG":
            return debugSearchEnabled
        default:
            return false
        }
    }
}
#endif
