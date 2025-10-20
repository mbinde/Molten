//
//  CoreDataItemTagsRepositoryTests.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//  Comprehensive tests for CoreDataItemTagsRepository
//
// Target: RepositoryTests

import Testing
import CoreData
@testable import Flameworker

@Suite("CoreDataItemTagsRepository Tests")
struct CoreDataItemTagsRepositoryTests {

    let repository: CoreDataItemTagsRepository
    let persistentContainer: NSPersistentContainer

    init() throws {
        // Create in-memory Core Data stack for testing - ISOLATED from production
        persistentContainer = NSPersistentContainer(name: "Flameworker")

        // Use in-memory store for testing - completely isolated
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = URL(fileURLWithPath: "/dev/null")
        persistentContainer.persistentStoreDescriptions = [description]

        // Load persistent store synchronously for test setup
        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        persistentContainer.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }

        semaphore.wait()

        if let error = loadError {
            throw error
        }

        // Create repository with isolated container
        repository = CoreDataItemTagsRepository(itemTagsPersistentContainer: persistentContainer)

        // Clean up any existing data to ensure clean test state
        try cleanupExistingData()
    }

    private func cleanupExistingData() throws {
        let context = persistentContainer.viewContext

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
        let existingItems = try context.fetch(fetchRequest)

        for item in existingItems {
            context.delete(item)
        }

        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Basic Tag Operations Tests

    @Test("Add single tag to item")
    func addSingleTag() async throws {
        try await repository.addTag("red", toItem: "bullseye-001-0")

        let tags = try await repository.fetchTags(forItem: "bullseye-001-0")

        #expect(tags.count == 1)
        #expect(tags.contains("red"))
    }

    @Test("Add multiple tags to item")
    func addMultipleTags() async throws {
        try await repository.addTags(["red", "opaque", "warm"], toItem: "cim-123-0")

        let tags = try await repository.fetchTags(forItem: "cim-123-0")

        #expect(tags.count == 3)
        #expect(tags.contains("red"))
        #expect(tags.contains("opaque"))
        #expect(tags.contains("warm"))
    }

    @Test("Fetch tags for item with no tags")
    func fetchTagsEmptyItem() async throws {
        let tags = try await repository.fetchTags(forItem: "nonexistent-item")

        #expect(tags.isEmpty)
    }

    @Test("Remove specific tag from item")
    func removeSpecificTag() async throws {
        // Add tags
        try await repository.addTags(["red", "opaque", "warm"], toItem: "ef-456-0")

        // Remove one tag
        try await repository.removeTag("opaque", fromItem: "ef-456-0")

        // Verify
        let tags = try await repository.fetchTags(forItem: "ef-456-0")

        #expect(tags.count == 2)
        #expect(tags.contains("red"))
        #expect(tags.contains("warm"))
        #expect(!tags.contains("opaque"))
    }

    @Test("Remove all tags from item")
    func removeAllTags() async throws {
        // Add tags
        try await repository.addTags(["red", "opaque", "warm"], toItem: "tag-001")

        // Remove all
        try await repository.removeAllTags(fromItem: "tag-001")

        // Verify
        let tags = try await repository.fetchTags(forItem: "tag-001")

        #expect(tags.isEmpty)
    }

    @Test("Set tags replaces existing tags")
    func setTagsReplacesExisting() async throws {
        // Add initial tags
        try await repository.addTags(["red", "opaque"], toItem: "set-001")

        // Set new tags
        try await repository.setTags(["blue", "transparent"], forItem: "set-001")

        // Verify
        let tags = try await repository.fetchTags(forItem: "set-001")

        #expect(tags.count == 2)
        #expect(tags.contains("blue"))
        #expect(tags.contains("transparent"))
        #expect(!tags.contains("red"))
        #expect(!tags.contains("opaque"))
    }

    // MARK: - Tag Validation and Cleaning Tests

    @Test("Tag cleaning normalizes to lowercase")
    func tagCleaningLowercase() async throws {
        try await repository.addTag("RED", toItem: "clean-001")

        let tags = try await repository.fetchTags(forItem: "clean-001")

        #expect(tags.count == 1)
        #expect(tags.first == "red")
    }

    @Test("Tag cleaning handles spaces and underscores")
    func tagCleaningSpaces() async throws {
        try await repository.addTag("olive green", toItem: "clean-002")

        let tags = try await repository.fetchTags(forItem: "clean-002")

        #expect(tags.count == 1)
        #expect(tags.first == "olive-green")
    }

    @Test("Adding duplicate tag is idempotent")
    func addDuplicateTagIdempotent() async throws {
        try await repository.addTag("red", toItem: "dup-001")
        try await repository.addTag("red", toItem: "dup-001")
        try await repository.addTag("RED", toItem: "dup-001") // Different case

        let tags = try await repository.fetchTags(forItem: "dup-001")

        #expect(tags.count == 1)
        #expect(tags.first == "red")
    }

    // MARK: - Tag Discovery Tests

    @Test("Get all distinct tags")
    func getAllDistinctTags() async throws {
        try await repository.addTags(["red", "blue"], toItem: "item1")
        try await repository.addTags(["red", "green"], toItem: "item2")
        try await repository.addTags(["blue", "yellow"], toItem: "item3")

        let allTags = try await repository.getAllTags()

        #expect(allTags.count == 4)
        #expect(allTags.contains("red"))
        #expect(allTags.contains("blue"))
        #expect(allTags.contains("green"))
        #expect(allTags.contains("yellow"))
    }

    @Test("Get tags with prefix")
    func getTagsWithPrefix() async throws {
        try await repository.addTags(["red", "blue", "brown", "green"], toItem: "prefix-001")

        let tagsWithB = try await repository.getTags(withPrefix: "b")

        #expect(tagsWithB.count == 2)
        #expect(tagsWithB.contains("blue"))
        #expect(tagsWithB.contains("brown"))
        #expect(!tagsWithB.contains("red"))
    }

    @Test("Get most used tags")
    func getMostUsedTags() async throws {
        // Add tags to multiple items
        try await repository.addTags(["red", "opaque"], toItem: "item1")
        try await repository.addTags(["red", "warm"], toItem: "item2")
        try await repository.addTags(["red", "bright"], toItem: "item3")
        try await repository.addTags(["blue"], toItem: "item4")

        let mostUsed = try await repository.getMostUsedTags(limit: 2)

        #expect(mostUsed.count == 2)
        #expect(mostUsed.first == "red") // Used 3 times
    }

    @Test("Check if tag exists")
    func tagExists() async throws {
        try await repository.addTag("red", toItem: "exist-001")

        let redExists = try await repository.tagExists("red")
        let blueExists = try await repository.tagExists("blue")

        #expect(redExists == true)
        #expect(blueExists == false)
    }

    // MARK: - Item Discovery Tests

    @Test("Fetch items with specific tag")
    func fetchItemsWithTag() async throws {
        try await repository.addTag("red", toItem: "item1")
        try await repository.addTag("red", toItem: "item2")
        try await repository.addTag("blue", toItem: "item3")

        let itemsWithRed = try await repository.fetchItems(withTag: "red")

        #expect(itemsWithRed.count == 2)
        #expect(itemsWithRed.contains("item1"))
        #expect(itemsWithRed.contains("item2"))
        #expect(!itemsWithRed.contains("item3"))
    }

    @Test("Fetch items with all specified tags")
    func fetchItemsWithAllTags() async throws {
        try await repository.addTags(["red", "opaque", "warm"], toItem: "item1")
        try await repository.addTags(["red", "opaque"], toItem: "item2")
        try await repository.addTags(["red", "warm"], toItem: "item3")

        let itemsWithAll = try await repository.fetchItems(withAllTags: ["red", "opaque"])

        #expect(itemsWithAll.count == 2)
        #expect(itemsWithAll.contains("item1"))
        #expect(itemsWithAll.contains("item2"))
        #expect(!itemsWithAll.contains("item3"))
    }

    @Test("Fetch items with any of specified tags")
    func fetchItemsWithAnyTags() async throws {
        try await repository.addTags(["red"], toItem: "item1")
        try await repository.addTags(["blue"], toItem: "item2")
        try await repository.addTags(["green"], toItem: "item3")

        let itemsWithAny = try await repository.fetchItems(withAnyTags: ["red", "blue"])

        #expect(itemsWithAny.count == 2)
        #expect(itemsWithAny.contains("item1"))
        #expect(itemsWithAny.contains("item2"))
        #expect(!itemsWithAny.contains("item3"))
    }

    // MARK: - Tag Analytics Tests

    @Test("Get tag usage counts")
    func getTagUsageCounts() async throws {
        try await repository.addTag("red", toItem: "item1")
        try await repository.addTag("red", toItem: "item2")
        try await repository.addTag("red", toItem: "item3")
        try await repository.addTag("blue", toItem: "item4")

        let usageCounts = try await repository.getTagUsageCounts()

        #expect(usageCounts["red"] == 3)
        #expect(usageCounts["blue"] == 1)
    }

    @Test("Get tags with minimum count")
    func getTagsWithMinimumCount() async throws {
        try await repository.addTag("red", toItem: "item1")
        try await repository.addTag("red", toItem: "item2")
        try await repository.addTag("red", toItem: "item3")
        try await repository.addTag("blue", toItem: "item4")
        try await repository.addTag("blue", toItem: "item5")
        try await repository.addTag("green", toItem: "item6")

        let tagsWithMin2 = try await repository.getTagsWithCounts(minCount: 2)

        #expect(tagsWithMin2.count == 2)

        let tagNames = tagsWithMin2.map { $0.tag }
        #expect(tagNames.contains("red"))
        #expect(tagNames.contains("blue"))
        #expect(!tagNames.contains("green"))

        // Verify sorted by count descending
        if tagsWithMin2.count >= 2 {
            #expect(tagsWithMin2[0].count >= tagsWithMin2[1].count)
        }
    }

    // MARK: - Edge Case Tests

    @Test("Handle empty tag list")
    func handleEmptyTagList() async throws {
        try await repository.addTags([], toItem: "empty-001")

        let tags = try await repository.fetchTags(forItem: "empty-001")

        #expect(tags.isEmpty)
    }

    @Test("Handle whitespace-only tags")
    func handleWhitespaceOnlyTags() async throws {
        try await repository.addTags(["  ", "   "], toItem: "whitespace-001")

        let tags = try await repository.fetchTags(forItem: "whitespace-001")

        // Whitespace-only tags should be filtered out during cleaning/validation
        #expect(tags.isEmpty)
    }

    @Test("Remove nonexistent tag is idempotent")
    func removeNonexistentTag() async throws {
        try await repository.addTag("red", toItem: "remove-001")

        // Remove a tag that doesn't exist - should not throw
        try await repository.removeTag("blue", fromItem: "remove-001")

        // Original tag should still be there
        let tags = try await repository.fetchTags(forItem: "remove-001")

        #expect(tags.count == 1)
        #expect(tags.contains("red"))
    }

    @Test("Multiple items with same tags")
    func multipleItemsSameTags() async throws {
        try await repository.addTags(["red", "opaque"], toItem: "item1")
        try await repository.addTags(["red", "opaque"], toItem: "item2")
        try await repository.addTags(["red", "opaque"], toItem: "item3")

        let itemsWithRed = try await repository.fetchItems(withTag: "red")
        let itemsWithOpaque = try await repository.fetchItems(withTag: "opaque")

        #expect(itemsWithRed.count == 3)
        #expect(itemsWithOpaque.count == 3)
    }

    @Test("Tags are returned sorted")
    func tagsAreSorted() async throws {
        try await repository.addTags(["zebra", "apple", "mango", "banana"], toItem: "sort-001")

        let tags = try await repository.fetchTags(forItem: "sort-001")

        #expect(tags == ["apple", "banana", "mango", "zebra"])
    }

    @Test("Compilation verification")
    func compilationVerification() {
        // This test exists primarily to verify that the CoreDataItemTagsRepository compiles correctly
        #expect(repository != nil)
        #expect(persistentContainer != nil)
    }
}
