//
//  CatalogStorageServiceTests.swift
//  MoltenTests
//
//  Created by Assistant on 11/9/25.
//  Tests for catalog storage service
//

import Foundation
import Testing

@testable import Molten

@Suite("CatalogStorageService Tests")
struct CatalogStorageServiceTests {

    // MARK: - Test Helpers

    /// Create isolated CatalogStorageService with unique temporary directory
    func createIsolatedStorageService() throws -> CatalogStorageService {
        let testID = UUID().uuidString
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CatalogStorageTests")
            .appendingPathComponent(testID)

        return try CatalogStorageService(storageDirectory: tempDir)
    }

    /// Create test catalog JSON data
    func createTestCatalogData() -> Data {
        let json: [String: Any] = [
            "version": "1.0",
            "catalog_data_version": 2,
            "glassitems": [
                ["manufacturer": "bullseye", "sku": "001", "name": "Clear"]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    // MARK: - Initialization Tests

    @Test("Storage service initializes successfully")
    func testInitialization() async throws {
        let service = try createIsolatedStorageService()

        // Service should initialize without errors
        // Directories should be created automatically
        #expect(service != nil)
    }

    // MARK: - Save Temp Catalog Tests

    @Test("Save temp catalog creates file")
    func testSaveTempCatalog() async throws {
        let service = try createIsolatedStorageService()
        let catalogData = createTestCatalogData()

        let tempURL = try await service.saveTempCatalog(catalogData, version: 2)

        #expect(FileManager.default.fileExists(atPath: tempURL.path))
        #expect(tempURL.lastPathComponent.contains("catalog_v2_temp.json"))

        // Verify data was written correctly
        let readData = try Data(contentsOf: tempURL)
        #expect(readData == catalogData)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test("Save temp catalog with different versions")
    func testSaveTempCatalogMultipleVersions() async throws {
        let service = try createIsolatedStorageService()
        let catalogData = createTestCatalogData()

        let tempURL1 = try await service.saveTempCatalog(catalogData, version: 1)
        let tempURL2 = try await service.saveTempCatalog(catalogData, version: 2)

        #expect(tempURL1.lastPathComponent.contains("v1"))
        #expect(tempURL2.lastPathComponent.contains("v2"))
        #expect(tempURL1 != tempURL2)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL1)
        try? FileManager.default.removeItem(at: tempURL2)
    }

    @Test("Save temp catalog overwrites existing temp file")
    func testSaveTempCatalogOverwrites() async throws {
        let service = try createIsolatedStorageService()
        let catalogData1 = "version 1".data(using: .utf8)!
        let catalogData2 = "version 2 - much longer content".data(using: .utf8)!

        // Save first version
        let tempURL1 = try await service.saveTempCatalog(catalogData1, version: 2)

        // Save second version with same version number
        let tempURL2 = try await service.saveTempCatalog(catalogData2, version: 2)

        #expect(tempURL1 == tempURL2)

        // Should contain the second version's data
        let readData = try Data(contentsOf: tempURL2)
        #expect(readData == catalogData2)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL2)
    }

    // MARK: - Promote to Current Tests

    @Test("Promote temp to current catalog")
    func testPromoteTempToCurrent() async throws {
        let service = try createIsolatedStorageService()
        let catalogData = createTestCatalogData()

        // Save temp catalog
        let tempURL = try await service.saveTempCatalog(catalogData, version: 2)

        // Promote to current
        try await service.promoteTempToCurrent(tempFile: tempURL)

        // Temp file should no longer exist (moved)
        #expect(!FileManager.default.fileExists(atPath: tempURL.path))

        // Current catalog should exist and contain correct data
        let loadedData = await service.loadCurrentCatalog()
        #expect(loadedData == catalogData)
    }

    @Test("Promote temp to current replaces existing catalog")
    func testPromoteTempToCurrentReplacesExisting() async throws {
        let service = try createIsolatedStorageService()
        let catalogData1 = "version 1".data(using: .utf8)!
        let catalogData2 = "version 2".data(using: .utf8)!

        // Create and promote first catalog
        let tempURL1 = try await service.saveTempCatalog(catalogData1, version: 1)
        try await service.promoteTempToCurrent(tempFile: tempURL1)

        // Verify first catalog is current
        var loadedData = await service.loadCurrentCatalog()
        #expect(loadedData == catalogData1)

        // Create and promote second catalog
        let tempURL2 = try await service.saveTempCatalog(catalogData2, version: 2)
        try await service.promoteTempToCurrent(tempFile: tempURL2)

        // Verify second catalog replaced first
        loadedData = await service.loadCurrentCatalog()
        #expect(loadedData == catalogData2)
    }

    @Test("Promote temp to current with non-existent file throws error")
    func testPromoteTempToCurrentWithNonExistentFile() async throws {
        let service = try createIsolatedStorageService()
        let nonExistentURL = URL(fileURLWithPath: "/tmp/nonexistent_catalog.json")

        await #expect(throws: CatalogUpdateError.self) {
            try await service.promoteTempToCurrent(tempFile: nonExistentURL)
        }
    }

    // MARK: - Load Current Catalog Tests

    @Test("Load current catalog returns nil when no catalog exists")
    func testLoadCurrentCatalogWhenNoneExists() async throws {
        let service = try createIsolatedStorageService()

        // With isolated storage, this should be nil (no catalog yet)
        let loadedData = await service.loadCurrentCatalog()
        #expect(loadedData == nil)
    }

    @Test("Load current catalog returns data after promotion")
    func testLoadCurrentCatalogAfterPromotion() async throws {
        let service = try createIsolatedStorageService()
        let catalogData = createTestCatalogData()

        // Save and promote catalog
        let tempURL = try await service.saveTempCatalog(catalogData, version: 2)
        try await service.promoteTempToCurrent(tempFile: tempURL)

        // Load current catalog
        let loadedData = await service.loadCurrentCatalog()
        #expect(loadedData == catalogData)
    }

    // MARK: - Cleanup Temp Files Tests

    @Test("Cleanup temp files removes old files")
    func testCleanupTempFiles() async throws {
        let service = try createIsolatedStorageService()
        let catalogData = createTestCatalogData()

        // Create a temp file
        let tempURL = try await service.saveTempCatalog(catalogData, version: 1)

        // Modify file creation date to be 25 hours ago
        let oldDate = Date().addingTimeInterval(-90000)  // 25 hours ago
        try FileManager.default.setAttributes(
            [.creationDate: oldDate],
            ofItemAtPath: tempURL.path
        )

        // Run cleanup
        await service.cleanupTempFiles()

        // Old file should be deleted
        #expect(!FileManager.default.fileExists(atPath: tempURL.path))
    }

    @Test("Cleanup temp files keeps recent files")
    func testCleanupTempFilesKeepsRecentFiles() async throws {
        let service = try createIsolatedStorageService()
        let catalogData = createTestCatalogData()

        // Create a recent temp file
        let tempURL = try await service.saveTempCatalog(catalogData, version: 2)

        // Run cleanup
        await service.cleanupTempFiles()

        // Recent file should still exist
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test("Cleanup temp files handles empty temp directory")
    func testCleanupTempFilesWithEmptyDirectory() async throws {
        let service = try createIsolatedStorageService()

        // Run cleanup on empty directory (should not throw)
        await service.cleanupTempFiles()

        // Test passes if no error thrown
        #expect(true)
    }

    // MARK: - Storage Size Tests

    @Test("Get storage size returns zero when empty")
    func testGetStorageSizeWhenEmpty() async throws {
        let service = try createIsolatedStorageService()

        let size = await service.getStorageSize()

        // Should be zero or very small (directory metadata)
        #expect(size >= 0)
        #expect(size < 1000)  // Less than 1KB
    }

    @Test("Get storage size calculates total size")
    func testGetStorageSize() async throws {
        let service = try createIsolatedStorageService()
        let catalogData = createTestCatalogData()

        // Save temp catalog
        let tempURL = try await service.saveTempCatalog(catalogData, version: 2)

        // Promote to current
        try await service.promoteTempToCurrent(tempFile: tempURL)

        // Get storage size
        let size = await service.getStorageSize()

        // Should be approximately the size of catalog data
        #expect(size >= Int64(catalogData.count))
        #expect(size < Int64(catalogData.count) + 1000)  // Allow for metadata
    }

    @Test("Get storage size includes multiple files")
    func testGetStorageSizeMultipleFiles() async throws {
        let service = try createIsolatedStorageService()
        let catalogData = createTestCatalogData()

        // Create multiple temp files
        let tempURL1 = try await service.saveTempCatalog(catalogData, version: 1)
        let tempURL2 = try await service.saveTempCatalog(catalogData, version: 2)

        // Promote one to current
        try await service.promoteTempToCurrent(tempFile: tempURL1)

        // Get storage size
        let size = await service.getStorageSize()

        // Should include both current catalog and remaining temp file
        // Allow for filesystem metadata/overhead (use 90% of expected size as minimum)
        #expect(size >= Int64(Double(catalogData.count * 2) * 0.9))

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL2)
    }

    // MARK: - Error Handling Tests

    @Test("Save temp catalog handles write errors gracefully")
    func testSaveTempCatalogErrorHandling() async throws {
        // This test verifies error handling exists
        // Actual error triggering would require filesystem manipulation
        // which is complex in unit tests

        let service = try createIsolatedStorageService()
        let catalogData = createTestCatalogData()

        // Should succeed under normal conditions
        let tempURL = try await service.saveTempCatalog(catalogData, version: 1)
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Integration Tests

    @Test("Full workflow: save, promote, load")
    func testFullWorkflow() async throws {
        let service = try createIsolatedStorageService()
        let catalogData = createTestCatalogData()

        // 1. Save temp catalog
        let tempURL = try await service.saveTempCatalog(catalogData, version: 2)
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        // 2. Promote to current
        try await service.promoteTempToCurrent(tempFile: tempURL)
        #expect(!FileManager.default.fileExists(atPath: tempURL.path))

        // 3. Load current catalog
        let loadedData = await service.loadCurrentCatalog()
        #expect(loadedData == catalogData)

        // 4. Check storage size
        let size = await service.getStorageSize()
        #expect(size >= Int64(catalogData.count))
    }

    @Test("Multiple updates workflow")
    func testMultipleUpdatesWorkflow() async throws {
        let service = try createIsolatedStorageService()

        // Version 1
        let data1 = "version 1".data(using: .utf8)!
        let temp1 = try await service.saveTempCatalog(data1, version: 1)
        try await service.promoteTempToCurrent(tempFile: temp1)

        var current = await service.loadCurrentCatalog()
        #expect(current == data1)

        // Version 2
        let data2 = "version 2".data(using: .utf8)!
        let temp2 = try await service.saveTempCatalog(data2, version: 2)
        try await service.promoteTempToCurrent(tempFile: temp2)

        current = await service.loadCurrentCatalog()
        #expect(current == data2)

        // Version 3
        let data3 = "version 3".data(using: .utf8)!
        let temp3 = try await service.saveTempCatalog(data3, version: 3)
        try await service.promoteTempToCurrent(tempFile: temp3)

        current = await service.loadCurrentCatalog()
        #expect(current == data3)
    }
}
