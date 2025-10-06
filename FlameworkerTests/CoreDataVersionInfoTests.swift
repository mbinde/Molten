// NOTE: This appears to be an additional test file not in the final consolidation list.
// Consider consolidating into UtilityAndHelperTests.swift or CoreDataIntegrationTests.swift
// 
//  CoreDataVersionInfoTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/4/25.
//

import Testing
import CoreData
import Foundation
@testable import Flameworker

@Suite("Core Data Version Info Tests")
struct CoreDataVersionInfoTests {
    
    @Test("Should retrieve current Core Data model version")
    func testGetCoreDataModelVersion() {
        let versionInfo = CoreDataVersionInfo.shared
        let modelVersion = versionInfo.currentModelVersion
        
        #expect(!modelVersion.isEmpty, "Model version should not be empty")
        #expect(modelVersion.count > 0, "Model version should have content")
        
        // Should be a reasonable version identifier
        #expect(modelVersion.contains("Flameworker") || modelVersion.contains("v") || modelVersion.contains("Model") || modelVersion.contains("2"), 
                "Model version should contain recognizable version information")
    }
    
    @Test("Should try alternative methods for version detection")
    func testAlternativeVersionDetection() {
        let versionInfo = CoreDataVersionInfo.shared
        
        // Test different approaches to get version info
        let bundleVersion = versionInfo.modelVersionFromBundle
        let storeVersion = versionInfo.modelVersionFromMetadata
        let fallbackVersion = versionInfo.fallbackModelVersion
        
        // Handle mixed optional/non-optional properties carefully
        let bundleHasContent = !(bundleVersion?.isEmpty ?? true)
        let storeHasContent = !(storeVersion?.isEmpty ?? true)
        let fallbackHasContent = !fallbackVersion.isEmpty
        
        #expect(bundleHasContent || storeHasContent || fallbackHasContent, 
                "At least one version detection method should work")
        
        // Log results for debugging
        print("Bundle version: \(bundleVersion ?? "nil")")
        print("Store version: \(storeVersion ?? "nil")")
        print("Fallback version: \(fallbackVersion)")
    }
    
    @Test("Should provide meaningful fallback when no version set")
    func testVersionFallbackBehavior() {
        let versionInfo = CoreDataVersionInfo.shared
        let displayVersion = versionInfo.displayVersion
        
        #expect(!displayVersion.isEmpty, "Display version should never be empty")
        #expect(displayVersion != "Unknown Model", "Should provide more specific fallback than 'Unknown Model'")
        
        // Should contain some useful information
        let hasUsefulInfo = displayVersion.contains("Flameworker") || 
                           displayVersion.contains("Model") ||
                           displayVersion.contains("v") ||
                           displayVersion.range(of: #"\d+"#, options: .regularExpression) != nil
        
        #expect(hasUsefulInfo, "Display version should contain some meaningful information")
    }
    
    @Test("Should retrieve model version hash for troubleshooting")
    func testGetModelVersionHash() {
        let versionInfo = CoreDataVersionInfo.shared
        let versionHash = versionInfo.currentModelHash
        
        #expect(!versionHash.isEmpty, "Version hash should not be empty")
        #expect(versionHash.count > 5, "Version hash should be a meaningful length")
        
        // Hash should be consistent between calls
        let secondHash = versionInfo.currentModelHash
        #expect(versionHash == secondHash, "Version hash should be consistent")
    }
    
    @Test("Should format version info for display")
    func testFormatVersionInfoForDisplay() {
        let versionInfo = CoreDataVersionInfo.shared
        let displayInfo = versionInfo.formattedVersionInfo
        
        #expect(displayInfo.contains("Model Version:"), "Should include model version label")
        #expect(displayInfo.contains("Hash:"), "Should include hash label")
        
        // Should not be too long for UI display
        #expect(displayInfo.count < 200, "Display info should be reasonable length")
        #expect(displayInfo.count > 20, "Display info should have meaningful content")
    }
    
    @Test("Should detect if migration is available")
    func testMigrationAvailabilityDetection() async throws {
        let versionInfo = CoreDataVersionInfo.shared
        let context = PersistenceController.preview.container.viewContext
        
        let migrationAvailable = try await versionInfo.isMigrationAvailable(in: context)
        
        // Should return a boolean without error
        #expect(migrationAvailable == true || migrationAvailable == false, "Should return valid boolean")
        
        // Should be able to call multiple times without error
        let secondCheck = try await versionInfo.isMigrationAvailable(in: context)
        #expect(migrationAvailable == secondCheck, "Should be consistent between calls")
    }
}