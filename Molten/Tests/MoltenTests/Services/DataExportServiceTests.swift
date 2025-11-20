//
//  DataExportServiceTests.swift
//  MoltenTests
//
//  Tests for data export functionality
//

import Testing
import Foundation
@testable import Molten

@Suite("Data Export Service", .serialized)
@MainActor
struct DataExportServiceTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())


    // MARK: - Test Data Setup

    private func createTestService() -> (DataExportService, AppDependencies) {
        let service = deps.dataExportService
        return (service, deps)
    }

    // MARK: - Basic Export Tests

    @Test("Export creates directory")
    func exportCreatesDirectory() async throws {
        let (service, deps) = createTestService()

        let result = await service.exportAllData()

        switch result {
        case .success(let exportResult):
            // Verify directory exists
            var isDirectory: ObjCBool = false
            #expect(FileManager.default.fileExists(atPath: exportResult.fileURL.path, isDirectory: &isDirectory))
            #expect(isDirectory.boolValue == true)

            // Clean up
            try? FileManager.default.removeItem(at: exportResult.fileURL)

        case .failure(let error):
            Issue.record("Export failed: \(error)")
        }
    }

    @Test("Export includes metadata")
    func exportIncludesMetadata() async throws {
        let (service, deps) = createTestService()

        let result = await service.exportAllData()

        switch result {
        case .success(let exportResult):
            // Verify export result has metadata
            #expect(exportResult.exportDate != nil)
            #expect(exportResult.fileSize > 0)
            #expect(exportResult.entityCounts.total >= 0)

            // Clean up
            try? FileManager.default.removeItem(at: exportResult.fileURL)

        case .failure(let error):
            Issue.record("Export failed: \(error)")
        }
    }

    @Test("Export with images option works")
    func exportWithImagesOption() async throws {
        let (service, deps) = createTestService()

        // Export with images
        let configWithImages = DataExportConfiguration(includeImages: true)
        let resultWithImages = await service.exportAllData(configuration: configWithImages)

        // Export without images
        let configWithoutImages = DataExportConfiguration(includeImages: false)
        let resultWithoutImages = await service.exportAllData(configuration: configWithoutImages)

        switch (resultWithImages, resultWithoutImages) {
        case (.success(let withImages), .success(let withoutImages)):
            #expect(withImages.includedImages == true)
            #expect(withoutImages.includedImages == false)

            // Clean up
            try? FileManager.default.removeItem(at: withImages.fileURL)
            try? FileManager.default.removeItem(at: withoutImages.fileURL)

        default:
            Issue.record("Export failed")
        }
    }

    // MARK: - Entity Count Tests

    @Test("Empty database exports with zero counts")
    func emptyDatabaseExport() async throws {
        let (service, deps) = createTestService()

        let result = await service.exportAllData()

        switch result {
        case .success(let exportResult):
            let counts = exportResult.entityCounts

            // Catalog has ~3840 items from bundled SQLite database
            #expect(counts.glassItems > 0, "Should include catalog items from bundled database")
            #expect(counts.inventoryRecords == 0, "No inventory added yet")
            #expect(counts.projects == 0, "No projects added yet")
            #expect(counts.logbookEntries == 0, "No logbook entries added yet")
            #expect(counts.purchaseRecords == 0, "No purchases added yet")
            #expect(counts.total == counts.glassItems, "Total should equal catalog items when no user data exists")

            // Clean up
            try? FileManager.default.removeItem(at: exportResult.fileURL)

        case .failure(let error):
            Issue.record("Export failed: \(error)")
        }
    }

    @Test("Export counts glass items correctly")
    func exportCountsGlassItems() async throws {
        // Configure testing mode once

        // Create services - they will all share the same cached mock repositories
        let catalogService = deps.catalogService
        let service = deps.dataExportService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let existingCount = catalogItems.count

        let result = await service.exportAllData()

        switch result {
        case .success(let exportResult):
            #expect(exportResult.entityCounts.glassItems >= existingCount)

            // Clean up
            try? FileManager.default.removeItem(at: exportResult.fileURL)

        case .failure(let error):
            Issue.record("Export failed: \(error)")
        }
    }

    @Test("Export counts inventory correctly")
    func exportCountsInventory() async throws {
        // Configure testing mode once

        // Create services - they will all share the same cached mock repositories
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let service = deps.dataExportService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let testItem = try catalogItems.first(where: { $0.sku != nil })!

        // Add inventory for the real catalog item
        _ = try await inventoryService.addInventory(
            quantity: 10.0,
            type: "rod",
            toItem: testItem.stable_id,
            atLocation: "shelf-1"
        )

        _ = try await inventoryService.addInventory(
            quantity: 5.0,
            type: "tube",
            toItem: testItem.stable_id,
            atLocation: "shelf-2"
        )

        let result = await service.exportAllData()

        switch result {
        case .success(let exportResult):
            #expect(exportResult.entityCounts.inventoryRecords == 2)

            // Clean up
            try? FileManager.default.removeItem(at: exportResult.fileURL)

        case .failure(let error):
            Issue.record("Export failed: \(error)")
        }
    }

    // MARK: - Configuration Tests

    @Test("Export configuration default values")
    func exportConfigurationDefaults() async throws {
        let config = DataExportConfiguration.default

        #expect(config.includeImages == true)
        #expect(config.includeUserNotes == true)
        #expect(config.includeArchivedProjects == false)
    }

    @Test("Export configuration custom values")
    func exportConfigurationCustom() async throws {
        let config = DataExportConfiguration(
            includeImages: false,
            includeUserNotes: false,
            includeArchivedProjects: true
        )

        #expect(config.includeImages == false)
        #expect(config.includeUserNotes == false)
        #expect(config.includeArchivedProjects == true)
    }

    @Test("Export excludes archived projects by default")
    func exportExcludesArchivedProjects() async throws {
        let (service, deps) = createTestService()
        let projectRepo = deps.projectRepository

        // Create active project
        let activeProject = ProjectModel(
            title: "Active Project",
            type: .idea,
            coe: "90",
            summary: nil
        )
        _ = try await projectRepo.createProject(activeProject)

        // Create archived project
        let archivedProject = ProjectModel(
            title: "Archived Project",
            type: .idea,
            isArchived: true,
            coe: "90",
            summary: nil
        )
        _ = try await projectRepo.createProject(archivedProject)

        // Export with default config (excludes archived)
        let defaultResult = await service.exportAllData()

        // Export with archived included
        let includeArchivedConfig = DataExportConfiguration(includeArchivedProjects: true)
        let includeArchivedResult = await service.exportAllData(configuration: includeArchivedConfig)

        switch (defaultResult, includeArchivedResult) {
        case (.success(let defaultExport), .success(let includeArchivedExport)):
            // Default should have 1 project (active only)
            #expect(defaultExport.entityCounts.projects == 1)

            // Include archived should have 2 projects
            #expect(includeArchivedExport.entityCounts.projects == 2)

            // Clean up
            try? FileManager.default.removeItem(at: defaultExport.fileURL)
            try? FileManager.default.removeItem(at: includeArchivedExport.fileURL)

        default:
            Issue.record("Export failed")
        }
    }

    // MARK: - File Format Tests

    @Test("Export directory contains JSON files")
    func exportDirectoryContainsJsonFiles() async throws {
        let (service, deps) = createTestService()

        let result = await service.exportAllData()

        switch result {
        case .success(let exportResult):
            // Verify directory contains expected JSON files
            let files = try FileManager.default.contentsOfDirectory(atPath: exportResult.fileURL.path)
            let jsonFiles = files.filter { $0.hasSuffix(".json") }

            // Should have at least metadata file
            #expect(jsonFiles.contains("export_metadata.json"))

            // Clean up
            try? FileManager.default.removeItem(at: exportResult.fileURL)

        case .failure(let error):
            Issue.record("Export failed: \(error)")
        }
    }

    // MARK: - Export Models Tests

    @Test("ExportGlassItem converts from GlassItemModel")
    func exportGlassItemConversion() async throws {
        let stableId = generateStableId(manufacturer: "bullseye", sku: "001")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            mfr_notes: "Test notes",
            coe: 90,
            url: "https://example.com",
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )

        let exportItem = ExportGlassItem.from(glassItem)

        #expect(exportItem.stableId == stableId)
        // naturalKey field was removed - stable_id is the only identifier now
        #expect(exportItem.name == "Clear Rod")
        #expect(exportItem.sku == "001")
        #expect(exportItem.manufacturer == "bullseye")
        #expect(exportItem.manufacturerNotes == "Test notes")
        #expect(exportItem.coe == 90)
        #expect(exportItem.url == "https://example.com")
        #expect(exportItem.manufacturerStatus == "available")
    }

    @Test("ExportInventory converts from InventoryModel")
    func exportInventoryConversion() async throws {
        let stableId = generateStableId(manufacturer: "bullseye", sku: "001")
        let inventory = InventoryModel(
            id: UUID(),
            item_stable_id: stableId,
            type: "rod",
            subtype: "6mm",
            quantity: 10.5,
            location: "shelf-1",
            date_added: Date(),
            date_modified: Date()
        )

        let exportInventory = ExportInventory.from(inventory)

        #expect(exportInventory.itemStableId == stableId)
        #expect(exportInventory.type == "rod")
        #expect(exportInventory.subtype == "6mm")
        #expect(exportInventory.quantity == 10.5)
        #expect(exportInventory.location == "shelf-1")
    }

    // MARK: - Error Handling Tests

    @Test("Export handles empty catalog gracefully")
    func exportHandlesEmptyCatalog() async throws {
        let (service, deps) = createTestService()

        // Don't create any data - export empty database

        let result = await service.exportAllData()

        switch result {
        case .success(let exportResult):
            // Should succeed - catalog has items from bundled database even if no user data exists
            #expect(exportResult.entityCounts.glassItems > 0, "Should include catalog items")
            #expect(exportResult.entityCounts.total > 0, "Total should include catalog items")
            #expect(FileManager.default.fileExists(atPath: exportResult.fileURL.path))

            // Clean up
            try? FileManager.default.removeItem(at: exportResult.fileURL)

        case .failure(let error):
            Issue.record("Export should succeed even with empty data: \(error)")
        }
    }

    // MARK: - Export Metadata Tests

    @Test("Export metadata has correct version")
    func exportMetadataVersion() async throws {
        let metadata = DataExportContainer(
            exportVersion: DataExportContainer.currentVersion,
            exportDate: Date(),
            appVersion: "1.0",
            includesImages: true,
            entityCounts: ExportEntityCounts(
                glassItems: 0,
                inventoryRecords: 0,
                projects: 0,
                logbookEntries: 0,
                purchaseRecords: 0,
                userImages: 0,
                userNotes: 0
            )
        )

        #expect(metadata.exportVersion == "1.0")
        #expect(metadata.includesImages == true)
    }

    @Test("Export entity counts total calculates correctly")
    func exportEntityCountsTotal() async throws {
        let counts = ExportEntityCounts(
            glassItems: 10,
            inventoryRecords: 20,
            projects: 5,
            logbookEntries: 3,
            purchaseRecords: 7,
            userImages: 15,
            userNotes: 8
        )

        #expect(counts.total == 68)
    }

    // MARK: - File Format Tests

    @Test("Export file names are correct")
    func exportFileNames() async throws {
        #expect(ExportFileName.metadata.rawValue == "export_metadata.json")
        #expect(ExportFileName.glassItems.rawValue == "glass_items.json")
        #expect(ExportFileName.inventory.rawValue == "inventory.json")
        #expect(ExportFileName.projects.rawValue == "projects.json")
        #expect(ExportFileName.logbook.rawValue == "logbook.json")
        #expect(ExportFileName.purchaseRecords.rawValue == "purchase_records.json")
        #expect(ExportFileName.userImages.rawValue == "user_images.json")
        #expect(ExportFileName.userNotes.rawValue == "user_notes.json")
    }

    @Test("Export file display names are user-friendly")
    func exportFileDisplayNames() async throws {
        #expect(ExportFileName.metadata.displayName == "Export Metadata")
        #expect(ExportFileName.glassItems.displayName == "Glass Items")
        #expect(ExportFileName.inventory.displayName == "Inventory")
        #expect(ExportFileName.projects.displayName == "Projects")
    }
}
