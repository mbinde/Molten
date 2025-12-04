//
//  LabelStorageServiceTests.swift
//  MoltenTests
//
//  Tests for label storage service
//

import Foundation
import Testing

@testable import Molten

@Suite("LabelStorageService Tests")
struct LabelStorageServiceTests {

    // MARK: - Test Setup

    /// Creates a temporary directory for test storage
    private func createTestDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LabelStorageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Cleans up test directory
    private func cleanupTestDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Initialization Tests

    @Test("Storage service initializes with custom directory")
    func testInitialization() async throws {
        let testDir = try createTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        let service = try LabelStorageService(storageDirectory: testDir)

        // Verify directories were created
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: testDir.path, isDirectory: &isDir)
        #expect(exists == true)
        #expect(isDir.boolValue == true)

        // Verify Temp subdirectory was created
        let tempDir = testDir.appendingPathComponent("Temp", isDirectory: true)
        let tempExists = FileManager.default.fileExists(atPath: tempDir.path, isDirectory: &isDir)
        #expect(tempExists == true)
        #expect(isDir.boolValue == true)
    }

    // MARK: - Save Temp Database Tests

    @Test("Saves temp database successfully")
    func testSaveTempDatabase() async throws {
        let testDir = try createTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        let service = try LabelStorageService(storageDirectory: testDir)

        // Create test data (SQLite header for validation)
        let sqliteHeader = "SQLite format 3\0".data(using: .utf8)!
        var testData = Data()
        testData.append(sqliteHeader)
        testData.append(Data(repeating: 0, count: 1000))

        let tempFile = try await service.saveTempDatabase(testData, version: 5)

        // Verify file was saved
        #expect(FileManager.default.fileExists(atPath: tempFile.path) == true)

        // Verify file name contains version
        #expect(tempFile.lastPathComponent.contains("v5"))

        // Verify file contents
        let savedData = try Data(contentsOf: tempFile)
        #expect(savedData.count == testData.count)
    }

    // MARK: - Get Current Database URL Tests

    @Test("Returns correct current database URL")
    func testGetCurrentDatabaseURL() async throws {
        let testDir = try createTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        let service = try LabelStorageService(storageDirectory: testDir)

        let currentURL = await service.getCurrentDatabaseURL()

        // Should be labels.db in the storage directory
        #expect(currentURL.lastPathComponent == "labels.db")
        #expect(currentURL.deletingLastPathComponent().path == testDir.path)
    }

    // MARK: - Has Downloaded Database Tests

    @Test("Reports no downloaded database when none exists")
    func testHasDownloadedDatabaseWhenNone() async throws {
        let testDir = try createTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        let service = try LabelStorageService(storageDirectory: testDir)

        let hasDownloaded = await service.hasDownloadedDatabase()
        #expect(hasDownloaded == false)
    }

    @Test("Reports downloaded database when exists")
    func testHasDownloadedDatabaseWhenExists() async throws {
        let testDir = try createTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        let service = try LabelStorageService(storageDirectory: testDir)

        // Create the current database file
        let currentURL = await service.getCurrentDatabaseURL()
        let testData = "test database content".data(using: .utf8)!
        try testData.write(to: currentURL)

        let hasDownloaded = await service.hasDownloadedDatabase()
        #expect(hasDownloaded == true)
    }

    // MARK: - Promote Temp to Current Tests

    @Test("Promotes temp database to current successfully")
    func testPromoteTempToCurrent() async throws {
        let testDir = try createTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        let service = try LabelStorageService(storageDirectory: testDir)

        // Create a temp file
        let testContent = "new database content".data(using: .utf8)!
        let tempFile = try await service.saveTempDatabase(testContent, version: 1)

        // Promote to current
        try await service.promoteTempToCurrent(tempFile: tempFile)

        // Verify temp file was moved (no longer exists)
        #expect(FileManager.default.fileExists(atPath: tempFile.path) == false)

        // Verify current file exists with correct content
        let currentURL = await service.getCurrentDatabaseURL()
        #expect(FileManager.default.fileExists(atPath: currentURL.path) == true)

        let currentContent = try Data(contentsOf: currentURL)
        #expect(currentContent == testContent)
    }

    @Test("Promotion replaces existing current database")
    func testPromoteReplacesExisting() async throws {
        let testDir = try createTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        let service = try LabelStorageService(storageDirectory: testDir)

        // Create an existing current database
        let currentURL = await service.getCurrentDatabaseURL()
        let oldContent = "old database content".data(using: .utf8)!
        try oldContent.write(to: currentURL)

        // Create and promote new temp file
        let newContent = "new database content".data(using: .utf8)!
        let tempFile = try await service.saveTempDatabase(newContent, version: 2)
        try await service.promoteTempToCurrent(tempFile: tempFile)

        // Verify current has new content
        let currentContent = try Data(contentsOf: currentURL)
        #expect(currentContent == newContent)
    }

    // MARK: - Cleanup Tests

    @Test("Cleanup removes old temp files")
    func testCleanupTempFiles() async throws {
        let testDir = try createTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        let service = try LabelStorageService(storageDirectory: testDir)

        // Create a temp file
        let testContent = "temp content".data(using: .utf8)!
        let tempFile = try await service.saveTempDatabase(testContent, version: 1)

        // File should exist initially
        #expect(FileManager.default.fileExists(atPath: tempFile.path) == true)

        // Cleanup (won't delete because file is recent)
        await service.cleanupTempFiles()

        // File should still exist (it's less than 24 hours old)
        #expect(FileManager.default.fileExists(atPath: tempFile.path) == true)
    }

    // MARK: - Storage Size Tests

    @Test("Reports storage size correctly")
    func testGetStorageSize() async throws {
        let testDir = try createTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        let service = try LabelStorageService(storageDirectory: testDir)

        // Initially empty (except for Temp directory)
        let initialSize = await service.getStorageSize()

        // Create some files
        let content1 = Data(repeating: 0, count: 1000)
        let content2 = Data(repeating: 0, count: 2000)

        _ = try await service.saveTempDatabase(content1, version: 1)
        _ = try await service.saveTempDatabase(content2, version: 2)

        let newSize = await service.getStorageSize()

        // Size should have increased by at least the file sizes
        #expect(newSize >= initialSize + 3000)
    }
}
