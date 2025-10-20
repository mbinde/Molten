//
//  CoreDataUserTagsRepositoryTests.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import Testing
import CoreData
@testable import Flameworker

/// Tests for CoreDataUserTagsRepository implementation
@Suite("CoreDataUserTagsRepository Tests")
struct CoreDataUserTagsRepositoryTests {

    // MARK: - Basic Tag Operations Tests

    @Test("Add and fetch single tag")
    func addAndFetchSingleTag() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTag("favorite", toItem: "test-item-1")

        let tags = try await repository.fetchTags(forItem: "test-item-1")

        #expect(tags.count == 1)
        #expect(tags.contains("favorite"))
    }

    @Test("Add multiple tags")
    func addMultipleTags() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTag("favorite", toItem: "test-item-1")
        try await repository.addTag("wishlist", toItem: "test-item-1")
        try await repository.addTag("current-project", toItem: "test-item-1")

        let tags = try await repository.fetchTags(forItem: "test-item-1")

        #expect(tags.count == 3)
        #expect(tags.contains("favorite"))
        #expect(tags.contains("wishlist"))
        #expect(tags.contains("current-project"))
    }

    @Test("Add tags array")
    func addTagsArray() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite", "wishlist", "test"], toItem: "test-item-1")

        let tags = try await repository.fetchTags(forItem: "test-item-1")

        #expect(tags.count == 3)
        #expect(tags.contains("favorite"))
        #expect(tags.contains("wishlist"))
        #expect(tags.contains("test"))
    }

    @Test("Add duplicate tag is idempotent")
    func addDuplicateTag() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTag("favorite", toItem: "test-item-1")
        try await repository.addTag("favorite", toItem: "test-item-1")

        let tags = try await repository.fetchTags(forItem: "test-item-1")

        #expect(tags.count == 1)
    }

    @Test("Tag cleaning and normalization")
    func tagCleaning() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTag("  Favorite  ", toItem: "test-item-1")
        try await repository.addTag("WISHLIST", toItem: "test-item-1")
        try await repository.addTag("current_project", toItem: "test-item-1")

        let tags = try await repository.fetchTags(forItem: "test-item-1")

        #expect(tags.contains("favorite"))
        #expect(tags.contains("wishlist"))
        #expect(tags.contains("current-project"))
    }

    @Test("Remove tag")
    func removeTag() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite", "wishlist", "test"], toItem: "test-item-1")
        try await repository.removeTag("wishlist", fromItem: "test-item-1")

        let tags = try await repository.fetchTags(forItem: "test-item-1")

        #expect(tags.count == 2)
        #expect(tags.contains("favorite"))
        #expect(tags.contains("test"))
        #expect(!tags.contains("wishlist"))
    }

    @Test("Remove all tags")
    func removeAllTags() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite", "wishlist", "test"], toItem: "test-item-1")
        try await repository.removeAllTags(fromItem: "test-item-1")

        let tags = try await repository.fetchTags(forItem: "test-item-1")

        #expect(tags.count == 0)
    }

    @Test("Set tags replaces existing tags")
    func setTags() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite", "wishlist"], toItem: "test-item-1")
        try await repository.setTags(["archived", "surplus"], forItem: "test-item-1")

        let tags = try await repository.fetchTags(forItem: "test-item-1")

        #expect(tags.count == 2)
        #expect(tags.contains("archived"))
        #expect(tags.contains("surplus"))
        #expect(!tags.contains("favorite"))
        #expect(!tags.contains("wishlist"))
    }

    // MARK: - Batch Operations Tests

    @Test("Fetch tags for multiple items")
    func fetchTagsForMultipleItems() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite", "test"], toItem: "test-item-1")
        try await repository.addTags(["wishlist", "archived"], toItem: "test-item-2")
        try await repository.addTags(["current-project"], toItem: "test-item-3")

        let tagsByItem = try await repository.fetchTagsForItems(["test-item-1", "test-item-2", "test-item-3", "test-item-4"])

        #expect(tagsByItem.count == 3)
        #expect(tagsByItem["test-item-1"]?.count == 2)
        #expect(tagsByItem["test-item-2"]?.count == 2)
        #expect(tagsByItem["test-item-3"]?.count == 1)
        #expect(tagsByItem["test-item-4"] == nil)
    }

    // MARK: - Tag Discovery Tests

    @Test("Get all distinct tags")
    func getAllTags() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite", "wishlist"], toItem: "test-item-1")
        try await repository.addTags(["favorite", "archived"], toItem: "test-item-2")
        try await repository.addTags(["current-project"], toItem: "test-item-3")

        let allTags = try await repository.getAllTags()

        #expect(allTags.count == 4)
        #expect(allTags.contains("favorite"))
        #expect(allTags.contains("wishlist"))
        #expect(allTags.contains("archived"))
        #expect(allTags.contains("current-project"))
    }

    @Test("Get tags with prefix")
    func getTagsWithPrefix() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite", "fantasy", "wishlist"], toItem: "test-item-1")
        try await repository.addTags(["archived", "favorite"], toItem: "test-item-2")

        let tagsWithF = try await repository.getTags(withPrefix: "f")

        #expect(tagsWithF.count == 2)
        #expect(tagsWithF.contains("favorite"))
        #expect(tagsWithF.contains("fantasy"))
    }

    @Test("Get most used tags")
    func getMostUsedTags() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite"], toItem: "test-item-1")
        try await repository.addTags(["favorite", "wishlist"], toItem: "test-item-2")
        try await repository.addTags(["favorite", "wishlist", "archived"], toItem: "test-item-3")
        try await repository.addTags(["current-project"], toItem: "test-item-4")

        let mostUsed = try await repository.getMostUsedTags(limit: 2)

        #expect(mostUsed.count == 2)
        #expect(mostUsed[0] == "favorite")
        #expect(mostUsed[1] == "wishlist")
    }

    // MARK: - Item Discovery Tests

    @Test("Fetch items with specific tag")
    func fetchItemsWithTag() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite", "test"], toItem: "test-item-1")
        try await repository.addTags(["favorite", "wishlist"], toItem: "test-item-2")
        try await repository.addTags(["wishlist", "archived"], toItem: "test-item-3")

        let itemsWithFavorite = try await repository.fetchItems(withTag: "favorite")

        #expect(itemsWithFavorite.count == 2)
        #expect(itemsWithFavorite.contains("test-item-1"))
        #expect(itemsWithFavorite.contains("test-item-2"))
    }

    @Test("Fetch items with all specified tags")
    func fetchItemsWithAllTags() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite", "wishlist", "test"], toItem: "test-item-1")
        try await repository.addTags(["favorite", "wishlist"], toItem: "test-item-2")
        try await repository.addTags(["favorite"], toItem: "test-item-3")

        let itemsWithBoth = try await repository.fetchItems(withAllTags: ["favorite", "wishlist"])

        #expect(itemsWithBoth.count == 2)
        #expect(itemsWithBoth.contains("test-item-1"))
        #expect(itemsWithBoth.contains("test-item-2"))
    }

    @Test("Fetch items with any of specified tags")
    func fetchItemsWithAnyTags() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite"], toItem: "test-item-1")
        try await repository.addTags(["wishlist"], toItem: "test-item-2")
        try await repository.addTags(["archived"], toItem: "test-item-3")

        let itemsWithAny = try await repository.fetchItems(withAnyTags: ["favorite", "wishlist"])

        #expect(itemsWithAny.count == 2)
        #expect(itemsWithAny.contains("test-item-1"))
        #expect(itemsWithAny.contains("test-item-2"))
    }

    // MARK: - Tag Analytics Tests

    @Test("Get tag usage counts")
    func getTagUsageCounts() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite"], toItem: "test-item-1")
        try await repository.addTags(["favorite", "wishlist"], toItem: "test-item-2")
        try await repository.addTags(["favorite", "wishlist", "archived"], toItem: "test-item-3")

        let usageCounts = try await repository.getTagUsageCounts()

        #expect(usageCounts["favorite"] == 3)
        #expect(usageCounts["wishlist"] == 2)
        #expect(usageCounts["archived"] == 1)
    }

    @Test("Get tags with minimum count threshold")
    func getTagsWithCounts() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite"], toItem: "test-item-1")
        try await repository.addTags(["favorite", "wishlist"], toItem: "test-item-2")
        try await repository.addTags(["favorite", "wishlist", "archived"], toItem: "test-item-3")
        try await repository.addTags(["current-project"], toItem: "test-item-4")

        let tagsWithMinCount = try await repository.getTagsWithCounts(minCount: 2)

        #expect(tagsWithMinCount.count == 2)
        #expect(tagsWithMinCount[0].tag == "favorite")
        #expect(tagsWithMinCount[0].count == 3)
        #expect(tagsWithMinCount[1].tag == "wishlist")
        #expect(tagsWithMinCount[1].count == 2)
    }

    @Test("Check tag existence")
    func tagExists() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTag("favorite", toItem: "test-item-1")

        let favoriteExists = try await repository.tagExists("favorite")
        let wishlistExists = try await repository.tagExists("wishlist")

        #expect(favoriteExists)
        #expect(!wishlistExists)
    }

    // MARK: - Edge Cases Tests

    @Test("Fetch tags for non-existent item returns empty array")
    func fetchTagsForNonExistentItem() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        let tags = try await repository.fetchTags(forItem: "non-existent-item")

        #expect(tags.count == 0)
    }

    @Test("Remove tag from non-existent item does not throw")
    func removeTagFromNonExistentItem() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.removeTag("favorite", fromItem: "non-existent-item")
    }

    @Test("Empty tag prefix returns all tags")
    func emptyTagPrefix() async throws {
        let testController = PersistenceController.createTestController()
        let repository = CoreDataUserTagsRepository(userTagsPersistentContainer: testController.container)

        try await repository.addTags(["favorite", "wishlist"], toItem: "test-item-1")

        let tags = try await repository.getTags(withPrefix: "")

        #expect(tags.count == 2)
    }
}
