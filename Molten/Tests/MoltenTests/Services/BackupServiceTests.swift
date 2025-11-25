//
//  BackupServiceTests.swift
//  MoltenTests
//
//  Tests for BackupService - high-level service for automatic inventory backups
//  Coordinates backup key management, checksum computation, and API calls
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif
import Foundation
@testable import Molten

@Suite("BackupService Tests")
@MainActor
struct BackupServiceTests {

    // MARK: - Test Helpers

    private func createTestService(
        apiClient: MockBackupAPIClient = MockBackupAPIClient(),
        keyPairManager: KeyPairManager = KeyPairManager(),
        keyGenerator: BackupKeyGenerator = BackupKeyGenerator(),
        preferences: BackupPreferences? = nil,
        inventoryRepository: InventoryRepository = MockInventoryRepository()
    ) -> BackupService {
        let prefs = preferences ?? createTestPreferences()
        return BackupService(
            apiClient: apiClient,
            keyPairManager: keyPairManager,
            keyGenerator: keyGenerator,
            preferences: prefs,
            inventoryRepository: inventoryRepository
        )
    }

    private func createTestPreferences() -> BackupPreferences {
        let suiteName = "com.molten.tests.backup.service.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        return BackupPreferences(userDefaults: userDefaults)
    }

    // MARK: - Setup State Tests

    @Test("Should report not set up when no backup key")
    func testNotSetUpWithoutKey() {
        let preferences = createTestPreferences()
        let service = createTestService(preferences: preferences)

        #expect(service.isSetUp == false)
        #expect(service.isConfigured == false)
        #expect(service.backupKey == nil)
    }

    @Test("Should report set up when enabled with key")
    func testSetUpWhenEnabled() {
        let preferences = createTestPreferences()
        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.isEnabled = true

        let service = createTestService(preferences: preferences)

        #expect(service.isSetUp == true)
        #expect(service.isConfigured == true)
        #expect(service.backupKey == "ABC-DEF-GHJ")
    }

    @Test("Should report not set up when paused")
    func testNotSetUpWhenPaused() {
        let preferences = createTestPreferences()
        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.isEnabled = true
        preferences.isPaused = true

        let service = createTestService(preferences: preferences)

        #expect(service.isSetUp == false) // Not active for automatic backups
        #expect(service.isConfigured == true) // But still configured
        #expect(service.isPaused == true)
    }

    // MARK: - Enable Backups Tests

    @Test("Should enable backups and return key")
    func testEnableBackups() async throws {
        let mockAPI = MockBackupAPIClient()
        let preferences = createTestPreferences()
        let service = createTestService(apiClient: mockAPI, preferences: preferences)

        // Clean up any existing keys from previous tests
        KeyPairManager.deleteAllKeys()

        let key = try await service.enableBackups()

        #expect(!key.isEmpty)
        #expect(preferences.backupKey == key)
        #expect(preferences.isEnabled == true)
        #expect(mockAPI.registerCalled == true)
    }

    @Test("Should retry on conflict when enabling backups")
    func testEnableBackupsRetryOnConflict() async throws {
        let mockAPI = MockBackupAPIClient()
        mockAPI.conflictCount = 2 // Fail twice, then succeed
        let preferences = createTestPreferences()
        let service = createTestService(apiClient: mockAPI, preferences: preferences)

        KeyPairManager.deleteAllKeys()

        let key = try await service.enableBackups()

        #expect(!key.isEmpty)
        #expect(mockAPI.registerCallCount == 3) // 2 conflicts + 1 success
    }

    @Test("Should throw error after max conflict retries")
    func testEnableBackupsMaxRetries() async throws {
        let mockAPI = MockBackupAPIClient()
        mockAPI.conflictCount = 10 // Always fail
        let preferences = createTestPreferences()
        let service = createTestService(apiClient: mockAPI, preferences: preferences)

        KeyPairManager.deleteAllKeys()

        await #expect(throws: BackupAPIError.self) {
            _ = try await service.enableBackups()
        }
    }

    // MARK: - Pause/Resume Tests

    @Test("Should pause backups")
    func testPauseBackups() {
        let preferences = createTestPreferences()
        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.isEnabled = true

        let service = createTestService(preferences: preferences)

        #expect(service.isPaused == false)

        service.pauseBackups()

        #expect(service.isPaused == true)
        #expect(preferences.isPaused == true)
        #expect(service.isSetUp == false) // Not active when paused
        #expect(service.isConfigured == true) // But still configured
    }

    @Test("Should resume backups")
    func testResumeBackups() {
        let preferences = createTestPreferences()
        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.isEnabled = true
        preferences.isPaused = true

        let service = createTestService(preferences: preferences)

        #expect(service.isPaused == true)

        service.resumeBackups()

        #expect(service.isPaused == false)
        #expect(preferences.isPaused == false)
        #expect(service.isSetUp == true)
    }

    // MARK: - Delete Backup Key Tests

    @Test("Should delete backup key and clear preferences")
    func testDeleteBackupKey() {
        let preferences = createTestPreferences()
        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.isEnabled = true
        preferences.lastBackupTimestamp = Date()
        preferences.lastInventoryChecksum = "checksum"

        let service = createTestService(preferences: preferences)

        service.deleteBackupKey()

        #expect(preferences.backupKey == nil)
        #expect(preferences.isEnabled == false)
        #expect(preferences.lastBackupTimestamp == nil)
        #expect(preferences.lastInventoryChecksum == nil)
        #expect(service.isSetUp == false)
        #expect(service.isConfigured == false)
    }

    // MARK: - Backup Trigger Tests

    @Test("Should backup on app open when never backed up")
    func testShouldBackupOnAppOpenNeverBackedUp() {
        let preferences = createTestPreferences()
        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.isEnabled = true
        // No lastBackupTimestamp set

        let service = createTestService(preferences: preferences)

        #expect(service.shouldBackupOnAppOpen() == true)
    }

    @Test("Should backup on app open when 20+ hours passed")
    func testShouldBackupOnAppOpenAfter20Hours() {
        let preferences = createTestPreferences()
        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.isEnabled = true
        preferences.lastBackupTimestamp = Date().addingTimeInterval(-21 * 3600) // 21 hours ago

        let service = createTestService(preferences: preferences)

        #expect(service.shouldBackupOnAppOpen() == true)
    }

    @Test("Should not backup on app open when less than 20 hours passed")
    func testShouldNotBackupOnAppOpenBefore20Hours() {
        let preferences = createTestPreferences()
        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.isEnabled = true
        preferences.lastBackupTimestamp = Date().addingTimeInterval(-10 * 3600) // 10 hours ago

        let service = createTestService(preferences: preferences)

        #expect(service.shouldBackupOnAppOpen() == false)
    }

    @Test("Should not backup on app open when not set up")
    func testShouldNotBackupOnAppOpenWhenNotSetUp() {
        let preferences = createTestPreferences()
        // Not set up

        let service = createTestService(preferences: preferences)

        #expect(service.shouldBackupOnAppOpen() == false)
    }

    @Test("Should not backup on app open when paused")
    func testShouldNotBackupOnAppOpenWhenPaused() {
        let preferences = createTestPreferences()
        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.isEnabled = true
        preferences.isPaused = true
        // No lastBackupTimestamp - would normally trigger backup

        let service = createTestService(preferences: preferences)

        #expect(service.shouldBackupOnAppOpen() == false)
    }

    // MARK: - Perform Backup Tests

    @Test("Should perform backup and upload")
    func testPerformBackup() async throws {
        let mockAPI = MockBackupAPIClient()
        let mockRepo = MockInventoryRepository()
        let inventory = InventoryModel(
            id: UUID(),
            item_stable_id: "test-item-1",
            type: "rod",
            subtype: nil,
            subsubtype: nil,
            dimensions: nil,
            quantity: 5,
            containerCount: nil,
            location: "Studio"
        )
        _ = try await mockRepo.createInventory(inventory)

        let preferences = createTestPreferences()
        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.isEnabled = true

        // Store a key pair for signing
        let keyPairManager = KeyPairManager()
        KeyPairManager.deleteAllKeys()
        _ = try keyPairManager.generateAndStoreKeyPair(identifier: "com.molten.backup.key")

        let service = createTestService(
            apiClient: mockAPI,
            keyPairManager: keyPairManager,
            preferences: preferences,
            inventoryRepository: mockRepo
        )

        let results = try await service.performBackup()

        #expect(results.count == 1)
        #expect(results[0].type == .inventory)
        #expect(results[0].skipped == false)
        #expect(mockAPI.uploadCalled == true)
    }

    @Test("Should update last backup timestamp after successful backup")
    func testPerformBackupUpdatesTimestamp() async throws {
        let mockAPI = MockBackupAPIClient()
        let mockRepo = MockInventoryRepository()
        let inventory = InventoryModel(
            id: UUID(),
            item_stable_id: "test-item-1",
            type: "rod",
            subtype: nil,
            subsubtype: nil,
            dimensions: nil,
            quantity: 5,
            containerCount: nil,
            location: nil
        )
        _ = try await mockRepo.createInventory(inventory)

        let preferences = createTestPreferences()
        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.isEnabled = true

        let keyPairManager = KeyPairManager()
        KeyPairManager.deleteAllKeys()
        _ = try keyPairManager.generateAndStoreKeyPair(identifier: "com.molten.backup.key")

        let service = createTestService(
            apiClient: mockAPI,
            keyPairManager: keyPairManager,
            preferences: preferences,
            inventoryRepository: mockRepo
        )

        #expect(preferences.lastBackupTimestamp == nil)

        _ = try await service.performBackup()

        #expect(preferences.lastBackupTimestamp != nil)
    }

    @Test("Should throw unauthorized when no backup key")
    func testPerformBackupUnauthorized() async throws {
        let preferences = createTestPreferences()
        // No backup key set

        let service = createTestService(preferences: preferences)

        await #expect(throws: BackupAPIError.self) {
            _ = try await service.performBackup()
        }
    }

    // MARK: - Reroll Key Tests

    @Test("Should reroll backup key")
    func testRerollBackupKey() async throws {
        let mockAPI = MockBackupAPIClient()
        let mockRepo = MockInventoryRepository()
        let inventory = InventoryModel(
            id: UUID(),
            item_stable_id: "test-item-1",
            type: "rod",
            subtype: nil,
            subsubtype: nil,
            dimensions: nil,
            quantity: 5,
            containerCount: nil,
            location: nil
        )
        _ = try await mockRepo.createInventory(inventory)

        let preferences = createTestPreferences()
        preferences.backupKey = "OLD-KEY-123"
        preferences.isEnabled = true
        preferences.lastBackupTimestamp = Date().addingTimeInterval(-3600) // 1 hour ago
        preferences.lastInventoryChecksum = "oldchecksum"

        let keyPairManager = KeyPairManager()
        KeyPairManager.deleteAllKeys()
        _ = try keyPairManager.generateAndStoreKeyPair(identifier: "com.molten.backup.key")

        let service = createTestService(
            apiClient: mockAPI,
            keyPairManager: keyPairManager,
            preferences: preferences,
            inventoryRepository: mockRepo
        )

        let oldTimestamp = preferences.lastBackupTimestamp

        let newKey = try await service.rerollBackupKey()

        #expect(newKey != "OLD-KEY-123")
        #expect(preferences.backupKey == newKey)
        #expect(mockAPI.registerCalled == true)
        // After reroll, an immediate backup is performed, so timestamp and checksum are set fresh
        #expect(preferences.lastBackupTimestamp != nil)
        #expect(preferences.lastBackupTimestamp != oldTimestamp)
        #expect(preferences.lastInventoryChecksum != "oldchecksum")
    }

    @Test("Should throw unauthorized when rerolling without being enabled")
    func testRerollBackupKeyUnauthorized() async throws {
        let preferences = createTestPreferences()
        // Not enabled

        let service = createTestService(preferences: preferences)

        await #expect(throws: BackupAPIError.self) {
            _ = try await service.rerollBackupKey()
        }
    }
}

// MARK: - Mock Classes

class MockBackupAPIClient: BackupAPIClient {
    var registerCalled = false
    var registerCallCount = 0
    var uploadCalled = false
    var downloadCalled = false
    var conflictCount = 0

    init() {
        let mockSession = MockServiceURLSession()
        let mockAttestation = MockServiceAttestationManager()
        super.init(
            session: mockSession,
            baseURL: URL(string: "https://api.example.com")!,
            attestationManager: mockAttestation
        )
    }

    override func registerBackupKey(_ backupKey: String, publicKey: Data) async throws {
        registerCalled = true
        registerCallCount += 1

        if conflictCount > 0 {
            conflictCount -= 1
            throw BackupAPIError.conflict
        }
    }

    override func uploadBackup(
        backupKey: String,
        type: String,
        data: String,
        checksum: String,
        ownershipSignature: Data
    ) async throws -> BackupUploadResult {
        uploadCalled = true
        return BackupUploadResult(skipped: false, timestamp: ISO8601DateFormatter().string(from: Date()))
    }

    override func downloadBackup(backupKey: String, type: String) async throws -> BackupDownloadResult {
        downloadCalled = true
        return BackupDownloadResult(
            data: "base64data",
            checksum: "checksum",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            backupCount: 1
        )
    }
}

// Minimal mocks for MockBackupAPIClient initialization
private class MockServiceURLSession: URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    func download(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (URL, URLResponse) {
        throw URLError(.unsupportedURL) // Not used in backup tests
    }
}

private class MockServiceAttestationManager: AttestationManager {
    override var isSupported: Bool { false }
}
