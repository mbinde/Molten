//
//  TransformableMigrationHelperTests.swift
//  Molten
//
//  Tests for TransformableMigrationHelper to ensure proper migration from
//  Transformable attributes to relationship-based storage
//

#if canImport(Testing)
import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("TransformableMigrationHelper Tests")
struct TransformableMigrationHelperTests {

    // MARK: - Test Helpers

    func createTestContext() -> NSManagedObjectContext {
        let controller = PersistenceController.createTestController()
        return controller.container.viewContext
    }

    // MARK: - Tags Migration Tests

    @Test("Migrate tags from ProjectLog")
    func testMigrateTagsFromLog() async throws {
        let context = createTestContext()

        // Create a ProjectLog entity with old-style tags data
        let log = ProjectLog(context: context)
        log.id = UUID()
        log.title = "Test Log"
        log.date_created = Date()
        log.date_modified = Date()
        log.status = "inProgress"

        // Simulate old Transformable tags data (JSON encoded array)
        let oldTags = ["tag1", "tag2", "tag3"]
        let encoder = JSONEncoder()
        log.setValue(try encoder.encode(oldTags), forKey: "tags")

        try context.save()

        // Run migration
        try TransformableMigrationHelper.migrateTags(for: log, in: context)
        try context.save()

        // Verify new ProjectTag entities were created
        let tagsFetch = ProjectTag.fetchRequest()
        tagsFetch.predicate = NSPredicate(format: "log == %@", log)
        let tags = try context.fetch(tagsFetch)

        #expect(tags.count == 3)
        let tagStrings = tags.compactMap { $0.tag }.sorted()
        #expect(tagStrings == ["tag1", "tag2", "tag3"])

        // Verify all tags point to the correct log
        #expect(tags.allSatisfy { $0.log == log })
    }

    @Test("Migrate tags from ProjectPlan")
    func testMigrateTagsFromPlan() async throws {
        let context = createTestContext()

        // Create a ProjectPlan entity with old-style tags data
        let plan = ProjectPlan(context: context)
        plan.id = UUID()
        plan.title = "Test Plan"
        plan.plan_type = "recipe"
        plan.date_created = Date()
        plan.date_modified = Date()

        // Simulate old Transformable tags data
        let oldTags = ["advanced", "sculpture"]
        let encoder = JSONEncoder()
        plan.setValue(try encoder.encode(oldTags), forKey: "tags")

        try context.save()

        // Run migration
        try TransformableMigrationHelper.migrateTags(for: plan, in: context)
        try context.save()

        // Verify new ProjectTag entities were created
        let tagsFetch = ProjectTag.fetchRequest()
        tagsFetch.predicate = NSPredicate(format: "plan == %@", plan)
        let tags = try context.fetch(tagsFetch)

        #expect(tags.count == 2)
        let tagStrings = tags.compactMap { $0.tag }.sorted()
        #expect(tagStrings == ["advanced", "sculpture"])
    }

    @Test("Migrate tags handles empty array")
    func testMigrateTagsEmptyArray() async throws {
        let context = createTestContext()

        let log = ProjectLog(context: context)
        log.id = UUID()
        log.title = "Test Log"
        log.date_created = Date()
        log.date_modified = Date()
        log.status = "inProgress"

        // Set empty tags array
        let encoder = JSONEncoder()
        log.setValue(try encoder.encode([String]()), forKey: "tags")

        try context.save()

        // Run migration (should not create any tags)
        try TransformableMigrationHelper.migrateTags(for: log, in: context)
        try context.save()

        // Verify no tags were created
        let tagsFetch = ProjectTag.fetchRequest()
        tagsFetch.predicate = NSPredicate(format: "log == %@", log)
        let tags = try context.fetch(tagsFetch)

        #expect(tags.isEmpty)
    }

    // MARK: - Techniques Migration Tests

    @Test("Migrate techniques from ProjectLog")
    func testMigrateTechniquesFromLog() async throws {
        let context = createTestContext()

        let log = ProjectLog(context: context)
        log.id = UUID()
        log.title = "Test Log"
        log.date_created = Date()
        log.date_modified = Date()
        log.status = "inProgress"

        // Simulate old Transformable techniques data
        let oldTechniques = ["lampworking", "fuming", "implosion"]
        let encoder = JSONEncoder()
        log.setValue(try encoder.encode(oldTechniques), forKey: "techniques_used")

        try context.save()

        // Run migration
        try TransformableMigrationHelper.migrateTechniques(for: log, in: context)
        try context.save()

        // Verify new ProjectTechnique entities were created
        let techniquesFetch = ProjectTechnique.fetchRequest()
        techniquesFetch.predicate = NSPredicate(format: "log == %@", log)
        let techniques = try context.fetch(techniquesFetch)

        #expect(techniques.count == 3)
        let techniqueStrings = techniques.compactMap { $0.technique }.sorted()
        #expect(techniqueStrings == ["fuming", "implosion", "lampworking"])
    }

    // MARK: - Reference URLs Migration Tests

    @Test("Migrate reference URLs from ProjectPlan")
    func testMigrateReferenceUrlsFromPlan() async throws {
        let context = createTestContext()

        let plan = ProjectPlan(context: context)
        plan.id = UUID()
        plan.title = "Test Plan"
        plan.plan_type = "tutorial"
        plan.date_created = Date()
        plan.date_modified = Date()

        // Simulate old Transformable reference URLs data
        let oldUrls = [
            ProjectReferenceUrl(
                url: "https://example.com/tutorial1",
                title: "Tutorial 1",
                description: "First tutorial"
            ),
            ProjectReferenceUrl(
                url: "https://example.com/tutorial2",
                title: "Tutorial 2"
            )
        ]
        let encoder = JSONEncoder()
        plan.setValue(try encoder.encode(oldUrls), forKey: "reference_urls_data")

        try context.save()

        // Run migration
        try TransformableMigrationHelper.migrateReferenceUrls(for: plan, in: context)
        try context.save()

        // Verify new ProjectPlanReferenceUrl entities were created
        let urlsFetch = ProjectPlanReferenceUrl.fetchRequest()
        urlsFetch.predicate = NSPredicate(format: "plan == %@", plan)
        urlsFetch.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        let urls = try context.fetch(urlsFetch)

        #expect(urls.count == 2)
        #expect(urls[0].url == "https://example.com/tutorial1")
        #expect(urls[0].title == "Tutorial 1")
        #expect(urls[0].urlDescription == "First tutorial")
        #expect(urls[1].url == "https://example.com/tutorial2")
        #expect(urls[1].title == "Tutorial 2")
    }

    // MARK: - Glass Items Migration Tests

    @Test("Migrate glass items from ProjectLog")
    func testMigrateGlassItemsFromLog() async throws {
        let context = createTestContext()

        let log = ProjectLog(context: context)
        log.id = UUID()
        log.title = "Test Log"
        log.date_created = Date()
        log.date_modified = Date()
        log.status = "completed"

        // Simulate old Transformable glass items data
        let oldItems = [
            ProjectGlassItem(
                naturalKey: "be-clear-000",
                quantity: 5.0,
                unit: "rods",
                notes: "Base structure"
            ),
            ProjectGlassItem(
                naturalKey: "be-blue-308",
                quantity: 3.5,
                unit: "rods",
                notes: "Accent color"
            )
        ]
        let encoder = JSONEncoder()
        log.setValue(try encoder.encode(oldItems), forKey: "glass_items_data")

        try context.save()

        // Run migration
        try TransformableMigrationHelper.migrateLogGlassItems(for: log, in: context)
        try context.save()

        // Verify new ProjectLogGlassItem entities were created
        let itemsFetch = ProjectLogGlassItem.fetchRequest()
        itemsFetch.predicate = NSPredicate(format: "log == %@", log)
        itemsFetch.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        let items = try context.fetch(itemsFetch)

        #expect(items.count == 2)
        #expect(items[0].itemNaturalKey == "be-clear-000")
        #expect(items[0].quantity == 5.0)
        #expect(items[0].notes == "Base structure")
        #expect(items[0].orderIndex == 0)
        #expect(items[1].itemNaturalKey == "be-blue-308")
        #expect(items[1].quantity == 3.5)
        #expect(items[1].orderIndex == 1)
    }

    @Test("Migrate glass items from ProjectPlan")
    func testMigrateGlassItemsFromPlan() async throws {
        let context = createTestContext()

        let plan = ProjectPlan(context: context)
        plan.id = UUID()
        plan.title = "Test Plan"
        plan.plan_type = "recipe"
        plan.date_created = Date()
        plan.date_modified = Date()

        // Simulate old Transformable glass items data
        let oldItems = [
            ProjectGlassItem(naturalKey: "ef-turquoise-142", quantity: 2.0, unit: "tubes")
        ]
        let encoder = JSONEncoder()
        plan.setValue(try encoder.encode(oldItems), forKey: "glass_items_data")

        try context.save()

        // Run migration
        try TransformableMigrationHelper.migratePlanGlassItems(for: plan, in: context)
        try context.save()

        // Verify new ProjectPlanGlassItem entities were created
        let itemsFetch = ProjectPlanGlassItem.fetchRequest()
        itemsFetch.predicate = NSPredicate(format: "plan == %@", plan)
        let items = try context.fetch(itemsFetch)

        #expect(items.count == 1)
        #expect(items[0].itemNaturalKey == "ef-turquoise-142")
        #expect(items[0].quantity == 2.0)
    }

    @Test("Migrate glass items from ProjectStep")
    func testMigrateGlassItemsFromStep() async throws {
        let context = createTestContext()

        // Create a plan first
        let plan = ProjectPlan(context: context)
        plan.id = UUID()
        plan.title = "Test Plan"
        plan.plan_type = "recipe"
        plan.date_created = Date()
        plan.date_modified = Date()

        let step = ProjectStep(context: context)
        step.id = UUID()
        step.title = "Test Step"
        step.order_index = 0
        step.plan = plan

        // Simulate old Transformable glass items data
        let oldItems = [
            ProjectGlassItem(naturalKey: "cim-ivory-104", quantity: 1.5, unit: "rods", notes: "For this step")
        ]
        let encoder = JSONEncoder()
        step.setValue(try encoder.encode(oldItems), forKey: "glass_items_needed_data")

        try context.save()

        // Run migration
        try TransformableMigrationHelper.migrateStepGlassItems(for: step, in: context)
        try context.save()

        // Verify new ProjectStepGlassItem entities were created
        let itemsFetch = ProjectStepGlassItem.fetchRequest()
        itemsFetch.predicate = NSPredicate(format: "step == %@", step)
        let items = try context.fetch(itemsFetch)

        #expect(items.count == 1)
        #expect(items[0].itemNaturalKey == "cim-ivory-104")
        #expect(items[0].quantity == 1.5)
        #expect(items[0].notes == "For this step")
    }

    // MARK: - UserDefaults Tracking Tests

    @Test("Migration tracking prevents duplicate runs")
    func testMigrationTrackingPreventsDuplicates() async throws {
        let context = createTestContext()

        // Clear any existing migration flags
        UserDefaults.standard.removeObject(forKey: "migratedToMolten6_Tags")
        UserDefaults.standard.removeObject(forKey: "migratedToMolten6_Complete")

        // Create test data
        let log = ProjectLog(context: context)
        log.id = UUID()
        log.title = "Test Log"
        log.date_created = Date()
        log.date_modified = Date()
        log.status = "inProgress"

        let oldTags = ["test-tag"]
        let encoder = JSONEncoder()
        log.setValue(try encoder.encode(oldTags), forKey: "tags")
        try context.save()

        // Run migration for the first time
        try TransformableMigrationHelper.migrateAllTags(in: context)

        // Verify UserDefaults flag was set
        #expect(UserDefaults.standard.bool(forKey: "migratedToMolten6_Tags") == true)

        // Count tags created
        let tagsFetch1 = ProjectTag.fetchRequest()
        let tags1 = try context.fetch(tagsFetch1)
        let initialCount = tags1.count

        // Run migration again (should be skipped due to UserDefaults flag)
        try TransformableMigrationHelper.migrateAllTags(in: context)

        // Verify tag count didn't change (migration was skipped)
        let tagsFetch2 = ProjectTag.fetchRequest()
        let tags2 = try context.fetch(tagsFetch2)
        #expect(tags2.count == initialCount)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "migratedToMolten6_Tags")
        UserDefaults.standard.removeObject(forKey: "migratedToMolten6_Complete")
    }

    // MARK: - Edge Case Tests

    @Test("Migration handles nil data gracefully")
    func testMigrationHandlesNilData() async throws {
        let context = createTestContext()

        let log = ProjectLog(context: context)
        log.id = UUID()
        log.title = "Test Log"
        log.date_created = Date()
        log.date_modified = Date()
        log.status = "inProgress"
        // Don't set any tags data (nil)

        try context.save()

        // Run migration (should not crash)
        try TransformableMigrationHelper.migrateTags(for: log, in: context)
        try context.save()

        // Verify no tags were created
        let tagsFetch = ProjectTag.fetchRequest()
        tagsFetch.predicate = NSPredicate(format: "log == %@", log)
        let tags = try context.fetch(tagsFetch)

        #expect(tags.isEmpty)
    }

    @Test("Migration handles corrupt JSON data gracefully")
    func testMigrationHandlesCorruptData() async throws {
        let context = createTestContext()

        let log = ProjectLog(context: context)
        log.id = UUID()
        log.title = "Test Log"
        log.date_created = Date()
        log.date_modified = Date()
        log.status = "inProgress"

        // Set corrupt data that can't be decoded
        let corruptData = "not valid json".data(using: .utf8)!
        log.setValue(corruptData, forKey: "tags")

        try context.save()

        // Run migration (should not crash, just skip corrupt data)
        try TransformableMigrationHelper.migrateTags(for: log, in: context)
        try context.save()

        // Verify no tags were created
        let tagsFetch = ProjectTag.fetchRequest()
        tagsFetch.predicate = NSPredicate(format: "log == %@", log)
        let tags = try context.fetch(tagsFetch)

        #expect(tags.isEmpty)
    }

    @Test("Migration filters out empty strings")
    func testMigrationFiltersEmptyStrings() async throws {
        let context = createTestContext()

        let log = ProjectLog(context: context)
        log.id = UUID()
        log.title = "Test Log"
        log.date_created = Date()
        log.date_modified = Date()
        log.status = "inProgress"

        // Include empty strings that should be filtered out
        let tagsWithEmpties = ["valid-tag", "", "another-tag", "   ", "third-tag"]
        let encoder = JSONEncoder()
        log.setValue(try encoder.encode(tagsWithEmpties), forKey: "tags")

        try context.save()

        // Run migration
        try TransformableMigrationHelper.migrateTags(for: log, in: context)
        try context.save()

        // Verify only non-empty tags were created
        let tagsFetch = ProjectTag.fetchRequest()
        tagsFetch.predicate = NSPredicate(format: "log == %@", log)
        let tags = try context.fetch(tagsFetch)

        #expect(tags.count == 3)
        let tagStrings = tags.compactMap { $0.tag }.sorted()
        #expect(tagStrings == ["another-tag", "third-tag", "valid-tag"])
    }

    @Test("Migration preserves order for glass items with orderIndex")
    func testMigrationPreservesOrder() async throws {
        let context = createTestContext()

        let log = ProjectLog(context: context)
        log.id = UUID()
        log.title = "Test Log"
        log.date_created = Date()
        log.date_modified = Date()
        log.status = "completed"

        // Create items in specific order
        let orderedItems = [
            ProjectGlassItem(naturalKey: "first-item", quantity: 1.0, unit: "rods"),
            ProjectGlassItem(naturalKey: "second-item", quantity: 2.0, unit: "rods"),
            ProjectGlassItem(naturalKey: "third-item", quantity: 3.0, unit: "rods"),
            ProjectGlassItem(naturalKey: "fourth-item", quantity: 4.0, unit: "rods")
        ]
        let encoder = JSONEncoder()
        log.setValue(try encoder.encode(orderedItems), forKey: "glass_items_data")

        try context.save()

        // Run migration
        try TransformableMigrationHelper.migrateLogGlassItems(for: log, in: context)
        try context.save()

        // Verify order is preserved via orderIndex
        let itemsFetch = ProjectLogGlassItem.fetchRequest()
        itemsFetch.predicate = NSPredicate(format: "log == %@", log)
        itemsFetch.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        let items = try context.fetch(itemsFetch)

        #expect(items.count == 4)
        #expect(items[0].itemNaturalKey == "first-item")
        #expect(items[0].orderIndex == 0)
        #expect(items[1].itemNaturalKey == "second-item")
        #expect(items[1].orderIndex == 1)
        #expect(items[2].itemNaturalKey == "third-item")
        #expect(items[2].orderIndex == 2)
        #expect(items[3].itemNaturalKey == "fourth-item")
        #expect(items[3].orderIndex == 3)
    }

    @Test("Migration handles large datasets")
    func testMigrationHandlesLargeDatasets() async throws {
        let context = createTestContext()

        let log = ProjectLog(context: context)
        log.id = UUID()
        log.title = "Test Log"
        log.date_created = Date()
        log.date_modified = Date()
        log.status = "inProgress"

        // Create a large number of tags
        let largeTags = (1...100).map { "tag-\($0)" }
        let encoder = JSONEncoder()
        log.setValue(try encoder.encode(largeTags), forKey: "tags")

        try context.save()

        // Run migration
        try TransformableMigrationHelper.migrateTags(for: log, in: context)
        try context.save()

        // Verify all tags were migrated
        let tagsFetch = ProjectTag.fetchRequest()
        tagsFetch.predicate = NSPredicate(format: "log == %@", log)
        let tags = try context.fetch(tagsFetch)

        #expect(tags.count == 100)
    }

    @Test("Migration sets dateAdded for new entities")
    func testMigrationSetsDateAdded() async throws {
        let context = createTestContext()

        let log = ProjectLog(context: context)
        log.id = UUID()
        log.title = "Test Log"
        log.date_created = Date()
        log.date_modified = Date()
        log.status = "inProgress"

        let oldTags = ["tag-with-date"]
        let encoder = JSONEncoder()
        log.setValue(try encoder.encode(oldTags), forKey: "tags")

        try context.save()

        let migrationStartTime = Date()
        try TransformableMigrationHelper.migrateTags(for: log, in: context)
        try context.save()

        // Verify dateAdded was set and is recent
        let tagsFetch = ProjectTag.fetchRequest()
        tagsFetch.predicate = NSPredicate(format: "log == %@", log)
        let tags = try context.fetch(tagsFetch)

        #expect(tags.count == 1)
        #expect(tags[0].dateAdded != nil)
        #expect(tags[0].dateAdded! >= migrationStartTime)
    }
}
#endif
