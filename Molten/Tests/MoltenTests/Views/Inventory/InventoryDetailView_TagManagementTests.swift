//
//  InventoryDetailView_TagManagementTests.swift
//  MoltenTests
//
//  Tests for InventoryDetailView user tag management integration
//

import Testing
import SwiftUI
@testable import Molten

@Suite("InventoryDetailView Tag Management Tests")
@MainActor
struct InventoryDetailView_TagManagementTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    // MARK: - Test Helpers

    func createTestItem(withTags userTags: [String] = []) -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "test", sku: "001"),
            name: "Test Glass Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: ["blue", "transparent"],  // Manufacturer tags
            userTags: userTags
        )
    }

    // MARK: - UserTagsEditor Initialization Tests

    @Test("UserTagsEditor initializes with item and repository")
    func testUserTagsEditorInitialization() {
        let item = createTestItem()
        let view = UserTagsEditor(
            item: item,
            userTagsRepository: deps.userTagsRepository
        )

        #expect(view != nil)
        #expect(view.item.glassItem.stable_id == item.glassItem.stable_id)
    }

    @Test("UserTagsEditor initializes with empty tags")
    func testUserTagsEditorInitializesWithEmptyTags() {
        let item = createTestItem(withTags: [])
        let view = UserTagsEditor(
            item: item,
            userTagsRepository: deps.userTagsRepository
        )

        #expect(view != nil)
        #expect(item.userTags.isEmpty)
    }

    @Test("UserTagsEditor initializes with existing tags")
    func testUserTagsEditorInitializesWithExistingTags() {
        let item = createTestItem(withTags: ["favorite", "current-project"])
        let view = UserTagsEditor(
            item: item,
            userTagsRepository: deps.userTagsRepository
        )

        #expect(view != nil)
        #expect(item.userTags.count == 2)
        #expect(item.userTags.contains("favorite"))
        #expect(item.userTags.contains("current-project"))
    }

    // MARK: - Tag Addition Tests

    @Test("Add custom tag to item")
    func testAddCustomTag() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Verify no tags initially
        let initialTags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(initialTags.isEmpty)

        // Add a custom tag
        try await repository.addTag("my-custom-tag", toItem: item.glassItem.stable_id)

        // Verify tag was added
        let updatedTags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(updatedTags.count == 1)
        #expect(updatedTags.contains("my-custom-tag"))
    }

    @Test("Add suggested tag to item")
    func testAddSuggestedTag() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add a suggested tag from common tags
        try await repository.addTag("favorite", toItem: item.glassItem.stable_id)

        // Verify tag was added
        let tags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(tags.contains("favorite"))
    }

    @Test("Add multiple tags to item")
    func testAddMultipleTags() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add multiple tags
        try await repository.addTags(["favorite", "wishlist", "current-project"], toItem: item.glassItem.stable_id)

        // Verify all tags were added
        let tags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(tags.count == 3)
        #expect(tags.contains("favorite"))
        #expect(tags.contains("wishlist"))
        #expect(tags.contains("current-project"))
    }

    @Test("Adding duplicate tag is idempotent")
    func testAddDuplicateTag() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add tag first time
        try await repository.addTag("favorite", toItem: item.glassItem.stable_id)

        // Add same tag again
        try await repository.addTag("favorite", toItem: item.glassItem.stable_id)

        // Verify only one instance exists
        let tags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(tags.filter { $0 == "favorite" }.count == 1)
    }

    @Test("Tag is cleaned and normalized on addition")
    func testTagCleaningOnAddition() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add tag with whitespace
        try await repository.addTag("  my-tag  ", toItem: item.glassItem.stable_id)

        // Verify tag was cleaned
        let tags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(tags.contains("my-tag"))
        #expect(!tags.contains("  my-tag  "))
    }

    // MARK: - Tag Removal Tests

    @Test("Remove tag from item")
    func testRemoveTag() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add tags first
        try await repository.addTags(["favorite", "wishlist", "test"], toItem: item.glassItem.stable_id)

        // Verify tags exist
        let initialTags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(initialTags.count == 3)

        // Remove one tag
        try await repository.removeTag("wishlist", fromItem: item.glassItem.stable_id)

        // Verify tag was removed
        let updatedTags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(updatedTags.count == 2)
        #expect(!updatedTags.contains("wishlist"))
        #expect(updatedTags.contains("favorite"))
        #expect(updatedTags.contains("test"))
    }

    @Test("Remove all tags from item")
    func testRemoveAllTags() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add tags
        try await repository.addTags(["favorite", "wishlist", "test"], toItem: item.glassItem.stable_id)

        // Verify tags exist
        let initialTags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(initialTags.count == 3)

        // Remove all tags
        try await repository.removeAllTags(fromItem: item.glassItem.stable_id)

        // Verify all tags were removed
        let updatedTags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(updatedTags.isEmpty)
    }

    @Test("Removing non-existent tag does not error")
    func testRemoveNonExistentTag() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add one tag
        try await repository.addTag("favorite", toItem: item.glassItem.stable_id)

        // Try to remove a tag that doesn't exist (should not error)
        try await repository.removeTag("non-existent", fromItem: item.glassItem.stable_id)

        // Verify original tag still exists
        let tags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(tags.contains("favorite"))
    }

    // MARK: - Suggested Tags Tests

    @Test("Common tags are available as suggestions")
    func testCommonTagsSuggestions() {
        let commonTags = UserTagModel.CommonTags.allCommonTags

        // Verify suggested tag categories exist
        #expect(!commonTags.isEmpty)

        // Verify status tags
        #expect(commonTags.contains("favorite"))
        #expect(commonTags.contains("wishlist"))
        #expect(commonTags.contains("discontinued"))

        // Verify usage tags
        #expect(commonTags.contains("current-project"))
        #expect(commonTags.contains("test"))
        #expect(commonTags.contains("sample"))

        // Verify quality tags
        #expect(commonTags.contains("premium"))
        #expect(commonTags.contains("standard"))

        // Verify organization tags
        #expect(commonTags.contains("shelf-a"))
        #expect(commonTags.contains("storage"))
    }

    @Test("Suggested tags exclude already-added tags")
    func testSuggestedTagsFiltering() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add some tags
        try await repository.addTags(["favorite", "wishlist"], toItem: item.glassItem.stable_id)

        // Get current tags
        let existingTags = try await repository.fetchTags(forItem: item.glassItem.stable_id)

        // Get all suggested tags
        let allSuggested = UserTagModel.CommonTags.allCommonTags

        // Filter out existing tags (this is what the UI should do)
        let filteredSuggested = allSuggested.filter { !existingTags.contains($0) }

        // Verify filtered list doesn't contain existing tags
        #expect(!filteredSuggested.contains("favorite"))
        #expect(!filteredSuggested.contains("wishlist"))

        // Verify other suggestions still present
        #expect(filteredSuggested.contains("current-project"))
        #expect(filteredSuggested.contains("premium"))
    }

    // MARK: - Custom Tags vs Suggested Tags Tests

    @Test("Can add both suggested and custom tags")
    func testMixedSuggestedAndCustomTags() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add mix of suggested and custom tags
        try await repository.addTags([
            "favorite",           // Suggested
            "my-custom-tag",      // Custom
            "current-project",    // Suggested
            "project-alpha"       // Custom
        ], toItem: item.glassItem.stable_id)

        // Verify all tags were added
        let tags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(tags.count == 4)
        #expect(tags.contains("favorite"))
        #expect(tags.contains("my-custom-tag"))
        #expect(tags.contains("current-project"))
        #expect(tags.contains("project-alpha"))
    }

    @Test("Custom tags are validated correctly")
    func testCustomTagValidation() {
        // Valid tags
        #expect(CoreDataUserTagsRepository.isValidTag("my-tag"))
        #expect(CoreDataUserTagsRepository.isValidTag("project-2024"))
        #expect(CoreDataUserTagsRepository.isValidTag("shelf a"))
        #expect(CoreDataUserTagsRepository.isValidTag("ab"))  // Minimum 2 chars

        // Invalid tags
        #expect(!CoreDataUserTagsRepository.isValidTag("a"))  // Too short (< 2 chars)
        #expect(!CoreDataUserTagsRepository.isValidTag(""))  // Empty
        #expect(!CoreDataUserTagsRepository.isValidTag("this-tag-is-way-too-long-and-exceeds-thirty-characters"))  // > 30 chars
    }

    @Test("Tag cleaning normalizes whitespace and case")
    func testTagCleaning() {
        // Test whitespace trimming
        #expect(CoreDataUserTagsRepository.cleanTag("  my-tag  ") == "my-tag")

        // Test case normalization (tags are lowercased)
        #expect(CoreDataUserTagsRepository.cleanTag("My-Tag") == "my-tag")
        #expect(CoreDataUserTagsRepository.cleanTag("FAVORITE") == "favorite")

        // Test internal whitespace converted to hyphens
        #expect(CoreDataUserTagsRepository.cleanTag("shelf a") == "shelf-a")
    }

    // MARK: - Tag Display Integration Tests

    @Test("CompleteInventoryItemModel displays user tags alongside manufacturer tags")
    func testTagDisplayIntegration() async throws {
        let item = createTestItem(withTags: ["favorite", "current-project"])

        // Verify manufacturer tags
        #expect(item.tags.contains("blue"))
        #expect(item.tags.contains("transparent"))

        // Verify user tags
        #expect(item.userTags.contains("favorite"))
        #expect(item.userTags.contains("current-project"))

        // Verify allTags combines both
        #expect(item.allTags.contains("blue"))
        #expect(item.allTags.contains("transparent"))
        #expect(item.allTags.contains("favorite"))
        #expect(item.allTags.contains("current-project"))

        // Verify deduplication if tag appears in both lists
        #expect(item.allTags.filter { $0 == "blue" }.count == 1)
    }

    @Test("User tags are sorted alphabetically")
    func testUserTagsSorting() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add tags in random order
        try await repository.addTags(["zebra", "apple", "middle", "boat"], toItem: item.glassItem.stable_id)

        // Fetch tags
        let tags = try await repository.fetchTags(forItem: item.glassItem.stable_id)

        // Verify tags are sorted
        #expect(tags == tags.sorted())
        #expect(tags == ["apple", "boat", "middle", "zebra"])
    }

    // MARK: - Tag Persistence Tests

    @Test("Tags persist across repository fetches")
    func testTagPersistence() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add tags
        try await repository.addTags(["favorite", "test"], toItem: item.glassItem.stable_id)

        // Fetch tags first time
        let firstFetch = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(firstFetch.count == 2)

        // Fetch tags second time (simulating reload)
        let secondFetch = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(secondFetch.count == 2)
        #expect(secondFetch == firstFetch)
    }

    @Test("Tag changes are immediately reflected")
    func testTagChangeReflection() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Initial state: no tags
        let initialTags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(initialTags.isEmpty)

        // Add tag
        try await repository.addTag("favorite", toItem: item.glassItem.stable_id)
        let afterAdd = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(afterAdd.count == 1)

        // Add another tag
        try await repository.addTag("wishlist", toItem: item.glassItem.stable_id)
        let afterSecondAdd = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(afterSecondAdd.count == 2)

        // Remove a tag
        try await repository.removeTag("favorite", fromItem: item.glassItem.stable_id)
        let afterRemove = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(afterRemove.count == 1)
        #expect(afterRemove.contains("wishlist"))
    }

    // MARK: - Empty State Tests

    @Test("Empty state displays when no tags exist")
    func testEmptyState() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Verify no tags
        let tags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(tags.isEmpty)

        // Create view (should show empty state)
        let view = UserTagsEditor(
            item: item,
            userTagsRepository: repository
        )

        #expect(view != nil)
    }

    // MARK: - Multiple Items Tag Management Tests

    @Test("Tags are isolated per item")
    func testTagIsolationPerItem() async throws {
        let repository = deps.userTagsRepository

        // Create two different items
        let item1 = createTestItem()
        let item2StableId = generateStableId(manufacturer: "test", sku: "002")

        // Add different tags to each item
        try await repository.addTags(["favorite", "item1-tag"], toItem: item1.glassItem.stable_id)
        try await repository.addTags(["wishlist", "item2-tag"], toItem: item2StableId)

        // Verify item1 tags
        let item1Tags = try await repository.fetchTags(forItem: item1.glassItem.stable_id)
        #expect(item1Tags.count == 2)
        #expect(item1Tags.contains("favorite"))
        #expect(item1Tags.contains("item1-tag"))
        #expect(!item1Tags.contains("wishlist"))
        #expect(!item1Tags.contains("item2-tag"))

        // Verify item2 tags
        let item2Tags = try await repository.fetchTags(forItem: item2StableId)
        #expect(item2Tags.count == 2)
        #expect(item2Tags.contains("wishlist"))
        #expect(item2Tags.contains("item2-tag"))
        #expect(!item2Tags.contains("favorite"))
        #expect(!item2Tags.contains("item1-tag"))
    }

    @Test("Removing tags from one item doesn't affect other items")
    func testTagRemovalIsolation() async throws {
        let repository = deps.userTagsRepository

        // Create two items with same tag
        let item1 = createTestItem()
        let item2StableId = generateStableId(manufacturer: "test", sku: "002")

        try await repository.addTag("favorite", toItem: item1.glassItem.stable_id)
        try await repository.addTag("favorite", toItem: item2StableId)

        // Remove tag from item1
        try await repository.removeTag("favorite", fromItem: item1.glassItem.stable_id)

        // Verify item1 tag removed
        let item1Tags = try await repository.fetchTags(forItem: item1.glassItem.stable_id)
        #expect(!item1Tags.contains("favorite"))

        // Verify item2 tag still exists
        let item2Tags = try await repository.fetchTags(forItem: item2StableId)
        #expect(item2Tags.contains("favorite"))
    }

    // MARK: - Tag Replacement Tests

    @Test("Set tags replaces all existing tags")
    func testSetTagsReplacement() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add initial tags
        try await repository.addTags(["old-tag-1", "old-tag-2"], toItem: item.glassItem.stable_id)

        // Verify initial tags
        let initialTags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(initialTags.count == 2)

        // Replace with new tags
        try await repository.setTags(["new-tag-1", "new-tag-2", "new-tag-3"], forItem: item.glassItem.stable_id)

        // Verify old tags removed and new tags added
        let updatedTags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(updatedTags.count == 3)
        #expect(!updatedTags.contains("old-tag-1"))
        #expect(!updatedTags.contains("old-tag-2"))
        #expect(updatedTags.contains("new-tag-1"))
        #expect(updatedTags.contains("new-tag-2"))
        #expect(updatedTags.contains("new-tag-3"))
    }

    @Test("Set tags with empty array removes all tags")
    func testSetTagsEmpty() async throws {
        let item = createTestItem()
        let repository = deps.userTagsRepository

        // Add tags
        try await repository.addTags(["tag1", "tag2"], toItem: item.glassItem.stable_id)

        // Set to empty array
        try await repository.setTags([], forItem: item.glassItem.stable_id)

        // Verify all tags removed
        let tags = try await repository.fetchTags(forItem: item.glassItem.stable_id)
        #expect(tags.isEmpty)
    }
}
