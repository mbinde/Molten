//
//  InventorySharingViewModelTests.swift
//  MoltenTests
//
//  Tests for InventorySharingViewModel - presentation logic for sharing UI
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif
import Foundation
import CoreData
@testable import Molten

@Suite("InventorySharingViewModel Tests", .serialized)
@MainActor
struct InventorySharingViewModelTests {

    // MARK: - Test Lifecycle

    init() {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()
    }

    private func cleanupUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.myShareCode")
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.myShareMetadata")
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.friendShares")
        UserDefaults.standard.synchronize() // Force changes to disk immediately for .serialized tests
    }

    // MARK: - Lifecycle Tests

    @Test("Should load share data on appear")
    func testLoadShareData() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        // Setup - create a share first
        let mockManager = createMockSharingManager()
        let metadata = MyShareMetadata(displayName: "Alice", shareNotes: "My collection")
        _ = try await mockManager.createMyShare(items: [], metadata: metadata)

        // Create ViewModel
        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: createMockCatalogService()
        )

        // Test
        await viewModel.loadShareData()

        // Verify
        #expect(viewModel.myShareCode != nil)
        #expect(viewModel.myShareMetadata?.displayName == "Alice")
        #expect(viewModel.displayName == "Alice")
        #expect(viewModel.shareNotes == "My collection")
    }

    @Test("Should populate form fields from existing metadata")
    func testPopulateFormFields() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        // Setup
        let mockManager = createMockSharingManager()
        let metadata = MyShareMetadata(displayName: "Bob's Shop", shareNotes: "Boro specialist")
        _ = try await mockManager.createMyShare(items: [], metadata: metadata)

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: createMockCatalogService()
        )

        // Test
        await viewModel.loadShareData()

        // Verify
        #expect(viewModel.displayName == "Bob's Shop")
        #expect(viewModel.shareNotes == "Boro specialist")
    }

    // MARK: - Create Share Tests

    @Test("Should create share with metadata")
    func testCreateShareWithMetadata() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        let mockManager = createMockSharingManager()
        let mockCatalogService = createMockCatalogService()

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: mockCatalogService
        )

        viewModel.displayName = "Alice"
        viewModel.shareNotes = "My glass collection"

        // Test
        await viewModel.createMyShare()

        // Verify
        #expect(viewModel.myShareCode != nil)
        #expect(viewModel.myShareMetadata?.displayName == "Alice")
        #expect(viewModel.myShareMetadata?.shareNotes == "My glass collection")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Should trim whitespace from metadata")
    func testTrimWhitespaceFromMetadata() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        let mockManager = createMockSharingManager()
        let mockCatalogService = createMockCatalogService()

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: mockCatalogService
        )

        viewModel.displayName = "  Alice  "
        viewModel.shareNotes = "  My collection  "

        // Test
        await viewModel.createMyShare()

        // Verify
        #expect(viewModel.myShareMetadata?.displayName == "Alice")
        #expect(viewModel.myShareMetadata?.shareNotes == "My collection")
    }

    @Test("Should handle empty notes as nil")
    func testEmptyNotesAsNil() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        let mockManager = createMockSharingManager()
        let mockCatalogService = createMockCatalogService()

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: mockCatalogService
        )

        viewModel.displayName = "Alice"
        viewModel.shareNotes = "   "  // Only whitespace

        // Test
        await viewModel.createMyShare()

        // Verify
        #expect(viewModel.myShareMetadata?.shareNotes == nil)
    }

    @Test("Should validate display name is not empty")
    func testValidateDisplayNameNotEmpty() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        let mockManager = createMockSharingManager()
        let mockCatalogService = createMockCatalogService()

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: mockCatalogService
        )

        viewModel.displayName = "   "  // Only whitespace
        viewModel.shareNotes = "Notes"

        // Test
        await viewModel.createMyShare()

        // Verify
        #expect(viewModel.errorMessage == "Please enter a display name")
        #expect(viewModel.myShareCode == nil)
    }

    // MARK: - Update Metadata Tests

    @Test("Should update share metadata")
    func testUpdateShareMetadata() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        // Setup - create initial share
        let mockManager = createMockSharingManager()
        let mockCatalogService = createMockCatalogService()
        let metadata = MyShareMetadata(displayName: "Alice", shareNotes: "Old notes")
        _ = try await mockManager.createMyShare(items: [], metadata: metadata)

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: mockCatalogService
        )
        await viewModel.loadShareData()

        // Update form fields
        viewModel.displayName = "Alice Smith"
        viewModel.shareNotes = "New notes"

        // Test
        await viewModel.updateMyShareMetadata()

        // Verify
        #expect(viewModel.myShareMetadata?.displayName == "Alice Smith")
        #expect(viewModel.myShareMetadata?.shareNotes == "New notes")
        #expect(viewModel.showingEditMetadata == false)
    }

    @Test("Should validate display name when updating")
    func testValidateDisplayNameWhenUpdating() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        // Setup
        let mockManager = createMockSharingManager()
        let mockCatalogService = createMockCatalogService()
        let metadata = MyShareMetadata(displayName: "Alice", shareNotes: "Notes")
        _ = try await mockManager.createMyShare(items: [], metadata: metadata)

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: mockCatalogService
        )
        await viewModel.loadShareData()

        viewModel.displayName = ""  // Empty

        // Test
        await viewModel.updateMyShareMetadata()

        // Verify
        #expect(viewModel.errorMessage == "Please enter a display name")
    }

    // MARK: - Add Friend Tests

    @Test("Should add friend with nickname")
    func testAddFriendWithNickname() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        let mockManager = createMockSharingManager()
        let mockCatalogService = createMockCatalogService()

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: mockCatalogService
        )

        viewModel.friendShareCode = "ABC123"
        viewModel.friendName = "Bob"
        viewModel.friendNickname = "Bob from GAS 2025"

        // Test
        await viewModel.addFriend()

        // Verify
        #expect(viewModel.friendShares.count == 1)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.showingAddFriend == false)

        // Form should be cleared
        #expect(viewModel.friendShareCode == "")
        #expect(viewModel.friendName == "")
        #expect(viewModel.friendNickname == "")
    }

    @Test("Should add friend without optional fields")
    func testAddFriendWithoutOptionalFields() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        let mockManager = createMockSharingManager()
        let mockCatalogService = createMockCatalogService()

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: mockCatalogService
        )

        viewModel.friendShareCode = "ABC123"
        viewModel.friendName = ""  // Empty (should be nil)
        viewModel.friendNickname = ""  // Empty (should be nil)

        // Test
        await viewModel.addFriend()

        // Verify
        #expect(viewModel.friendShares.count == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Should validate share code is not empty")
    func testValidateShareCodeNotEmpty() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        let mockManager = createMockSharingManager()
        let mockCatalogService = createMockCatalogService()

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: mockCatalogService
        )

        viewModel.friendShareCode = ""  // Empty

        // Test
        await viewModel.addFriend()

        // Verify
        #expect(viewModel.errorMessage == "Please enter a share code")
        #expect(viewModel.friendShares.isEmpty)
    }

    @Test("Should show warning for invalid signature")
    func testShowWarningForInvalidSignature() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        let mockManager = createMockSharingManagerWithInvalidSignature()
        let mockCatalogService = createMockCatalogService()

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: mockCatalogService
        )

        viewModel.friendShareCode = "INVALID"

        // Test
        await viewModel.addFriend()

        // Verify
        #expect(viewModel.errorMessage == "Warning: Share signature is invalid. Data may have been tampered with.")
    }

    // MARK: - Delete Share Tests

    @Test("Should delete share and clear metadata")
    func testDeleteShare() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        // Setup
        let mockManager = createMockSharingManager()
        let mockCatalogService = createMockCatalogService()
        let metadata = MyShareMetadata(displayName: "Alice")
        _ = try await mockManager.createMyShare(items: [], metadata: metadata)

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: mockCatalogService
        )
        await viewModel.loadShareData()

        // Test
        await viewModel.deleteMyShare()

        // Verify
        #expect(viewModel.myShareCode == nil)
    }

    // MARK: - Copy Share Code Tests

    @Test("Should copy share code to clipboard")
    func testCopyShareCode() async throws {
        // Note: This test verifies the method doesn't crash
        // Actual clipboard testing would require UI testing

        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        let mockManager = createMockSharingManager()
        let mockCatalogService = createMockCatalogService()
        let metadata = MyShareMetadata(displayName: "Alice")
        _ = try await mockManager.createMyShare(items: [], metadata: metadata)

        let viewModel = InventorySharingViewModel(
            sharingManager: mockManager,
            catalogService: mockCatalogService
        )
        await viewModel.loadShareData()

        // Test - should not crash
        viewModel.copyShareCode()
    }

    // MARK: - Error Handling Tests

    @Test("Should clear error message")
    func testClearError() async throws {
        cleanupUserDefaults()
        KeyPairManager.deleteAllKeys()

        let viewModel = InventorySharingViewModel(
            sharingManager: createMockSharingManager(),
            catalogService: createMockCatalogService()
        )

        viewModel.errorMessage = "Test error"

        // Test
        viewModel.clearError()

        // Verify
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Helper Methods

    private func createMockSharingManager() -> InventorySharingManager {
        // Create isolated test controller
        let testController = PersistenceController.createTestController()
        RepositoryFactory.configureForTestingWithCoreData(controller: testController)

        let testContext = testController.container.viewContext
        let catalogRepo = RepositoryFactory.createGlassItemRepository()
        let shareRecordRepo = CoreDataShareRecordRepository(context: testContext)
        let sharedInventoryRepo = CoreDataSharedInventoryRepository(
            context: testContext,
            catalogRepository: catalogRepo
        )

        // CRITICAL: Use test-specific UserDefaults suite to isolate tests
        // Create a unique suite name for this test run to avoid cross-test pollution
        let testSuiteName = "com.molten.test.sharing.\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        let testMetadataRepo = ShareMetadataRepository(userDefaults: testUserDefaults)

        let mockCoordinator = MockInventorySharingCoordinator()
        mockCoordinator.mockDownloadResult = SnapshotResult(
            items: [],
            timestamp: Date(),
            version: "1.0",
            isValid: true,
            ownerName: "Test User",
            ownerShareNotes: nil
        )
        return InventorySharingManager(
            coordinator: mockCoordinator,
            metadataRepository: testMetadataRepo,
            shareRecordRepository: shareRecordRepo,
            sharedInventoryRepository: sharedInventoryRepo
        )
    }

    private func createMockSharingManagerWithInvalidSignature() -> InventorySharingManager {
        // Create isolated test controller
        let testController = PersistenceController.createTestController()
        RepositoryFactory.configureForTestingWithCoreData(controller: testController)

        let testContext = testController.container.viewContext
        let catalogRepo = RepositoryFactory.createGlassItemRepository()
        let shareRecordRepo = CoreDataShareRecordRepository(context: testContext)
        let sharedInventoryRepo = CoreDataSharedInventoryRepository(
            context: testContext,
            catalogRepository: catalogRepo
        )

        // CRITICAL: Use test-specific UserDefaults suite to isolate tests
        let testSuiteName = "com.molten.test.sharing.\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        let testMetadataRepo = ShareMetadataRepository(userDefaults: testUserDefaults)

        let mockCoordinator = MockInventorySharingCoordinator()
        mockCoordinator.mockDownloadResult = SnapshotResult(
            items: [],
            timestamp: Date(),
            version: "1.0",
            isValid: false,  // Invalid signature
            ownerName: "Test User",
            ownerShareNotes: nil
        )
        return InventorySharingManager(
            coordinator: mockCoordinator,
            metadataRepository: testMetadataRepo,
            shareRecordRepository: shareRecordRepo,
            sharedInventoryRepository: sharedInventoryRepo
        )
    }

    private func createMockCatalogService() -> CatalogService {
        RepositoryFactory.configureForTesting()
        return RepositoryFactory.createCatalogService()
    }
}
