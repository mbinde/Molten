//
//  CoreDataProjectPlanRepositoryTests.swift
//  Molten
//
//  Tests for CoreDataProjectPlanRepository with relationship-based storage
//

#if canImport(Testing)
import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("CoreDataProjectPlanRepository Tests")
@MainActor
struct CoreDataProjectPlanRepositoryTests {

    // MARK: - Test Helpers

    func createTestController() -> PersistenceController {
        return PersistenceController.createTestController()
    }

    func createTestPlan(
        id: UUID = UUID(),
        title: String = "Test Plan",
        planType: ProjectPlanType = .recipe,
        isArchived: Bool = false,
        tags: [String] = ["test"],
        summary: String? = "Test summary",
        glassItems: [ProjectGlassItem] = [],
        referenceUrls: [ProjectReferenceUrl] = []
    ) -> ProjectPlanModel {
        return ProjectPlanModel(
            id: id,
            title: title,
            planType: planType,
            isArchived: isArchived,
            tags: tags,
            summary: summary,
            glassItems: glassItems,
            referenceUrls: referenceUrls
        )
    }

    // MARK: - Relationship-Based Storage Tests

    @Test("Core Data: Relationship-based storage for tags, glass items, and reference URLs")
    func testRelationshipBasedStorage() async throws {
        let controller = createTestController()
        let repository = CoreDataProjectPlanRepository(persistenceController: controller)

        let plan = ProjectPlanModel(
            title: "Test Relationships",
            planType: .recipe,
            tags: ["tag1", "tag2", "tag3"],
            glassItems: [
                ProjectGlassItem(naturalKey: "item1", quantity: 1.0, unit: "rods"),
                ProjectGlassItem(naturalKey: "item2", quantity: 2.5, unit: "tubes")
            ],
            referenceUrls: [
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
        )

        _ = try await repository.createPlan(plan)
        let fetched = try await repository.getPlan(id: plan.id)

        // Verify tags are stored as relationships (sorted alphabetically)
        #expect(fetched?.tags.sorted() == ["tag1", "tag2", "tag3"])

        // Verify glass items are stored as relationships (ordered by orderIndex)
        #expect(fetched?.glassItems.count == 2)
        #expect(fetched?.glassItems[0].naturalKey == "item1")
        #expect(fetched?.glassItems[0].quantity == 1.0)
        #expect(fetched?.glassItems[1].naturalKey == "item2")
        #expect(fetched?.glassItems[1].quantity == 2.5)

        // Verify reference URLs are stored as relationships (ordered by orderIndex)
        #expect(fetched?.referenceUrls.count == 2)
        #expect(fetched?.referenceUrls[0].url == "https://example.com/tutorial1")
        #expect(fetched?.referenceUrls[0].title == "Tutorial 1")
        #expect(fetched?.referenceUrls[1].url == "https://example.com/tutorial2")
    }

    @Test("Core Data: Update replaces relationships correctly")
    func testUpdateReplacesRelationships() async throws {
        let controller = createTestController()
        let repository = CoreDataProjectPlanRepository(persistenceController: controller)

        // Create plan with initial relationships
        let plan = ProjectPlanModel(
            title: "Test Update",
            planType: .recipe,
            tags: ["old-tag1", "old-tag2"],
            glassItems: [
                ProjectGlassItem(naturalKey: "old-item", quantity: 1.0, unit: "rods")
            ],
            referenceUrls: [
                ProjectReferenceUrl(url: "https://example.com/old")
            ]
        )
        _ = try await repository.createPlan(plan)

        // Update with completely different relationships
        let updatedPlan = ProjectPlanModel(
            id: plan.id,
            title: "Test Update",
            planType: .recipe,
            tags: ["new-tag1", "new-tag2", "new-tag3"],
            glassItems: [
                ProjectGlassItem(naturalKey: "new-item1", quantity: 2.0, unit: "tubes"),
                ProjectGlassItem(naturalKey: "new-item2", quantity: 3.0, unit: "rods")
            ],
            referenceUrls: [
                ProjectReferenceUrl(url: "https://example.com/new1", title: "New 1"),
                ProjectReferenceUrl(url: "https://example.com/new2", title: "New 2")
            ]
        )
        try await repository.updatePlan(updatedPlan)

        // Fetch and verify old relationships are gone, new ones are present
        let fetched = try await repository.getPlan(id: plan.id)

        #expect(fetched?.tags.sorted() == ["new-tag1", "new-tag2", "new-tag3"])
        #expect(!fetched!.tags.contains("old-tag1"))
        #expect(!fetched!.tags.contains("old-tag2"))

        #expect(fetched?.glassItems.count == 2)
        #expect(fetched?.glassItems[0].naturalKey == "new-item1")
        #expect(fetched?.glassItems[1].naturalKey == "new-item2")
        #expect(!fetched!.glassItems.contains(where: { $0.naturalKey == "old-item" }))

        #expect(fetched?.referenceUrls.count == 2)
        #expect(fetched?.referenceUrls[0].url == "https://example.com/new1")
        #expect(fetched?.referenceUrls[1].url == "https://example.com/new2")
        #expect(!fetched!.referenceUrls.contains(where: { $0.url == "https://example.com/old" }))
    }

    @Test("Core Data: Add reference URL creates proper relationship")
    func testAddReferenceUrl() async throws {
        let controller = createTestController()
        let repository = CoreDataProjectPlanRepository(persistenceController: controller)

        let plan = createTestPlan(referenceUrls: [])
        _ = try await repository.createPlan(plan)

        let newUrl = ProjectReferenceUrl(
            url: "https://example.com/added",
            title: "Added URL",
            description: "Dynamically added"
        )

        try await repository.addReferenceUrl(newUrl, to: plan.id)

        let fetched = try await repository.getPlan(id: plan.id)
        #expect(fetched?.referenceUrls.count == 1)
        #expect(fetched?.referenceUrls.first?.url == "https://example.com/added")
        #expect(fetched?.referenceUrls.first?.title == "Added URL")
    }

    @Test("Core Data: Update reference URL modifies existing relationship")
    func testUpdateReferenceUrl() async throws {
        let controller = createTestController()
        let repository = CoreDataProjectPlanRepository(persistenceController: controller)

        let originalUrl = ProjectReferenceUrl(
            url: "https://example.com/original",
            title: "Original"
        )
        let plan = createTestPlan(referenceUrls: [originalUrl])
        _ = try await repository.createPlan(plan)

        let updatedUrl = ProjectReferenceUrl(
            id: originalUrl.id,
            url: "https://example.com/updated",
            title: "Updated Title",
            description: "Updated description",
            dateAdded: originalUrl.dateAdded
        )

        try await repository.updateReferenceUrl(updatedUrl, in: plan.id)

        let fetched = try await repository.getPlan(id: plan.id)
        #expect(fetched?.referenceUrls.count == 1)
        #expect(fetched?.referenceUrls.first?.url == "https://example.com/updated")
        #expect(fetched?.referenceUrls.first?.title == "Updated Title")
        #expect(fetched?.referenceUrls.first?.description == "Updated description")
    }

    @Test("Core Data: Delete reference URL removes relationship")
    func testDeleteReferenceUrl() async throws {
        let controller = createTestController()
        let repository = CoreDataProjectPlanRepository(persistenceController: controller)

        let url1 = ProjectReferenceUrl(url: "https://example.com/url1", title: "URL 1")
        let url2 = ProjectReferenceUrl(url: "https://example.com/url2", title: "URL 2")
        let plan = createTestPlan(referenceUrls: [url1, url2])
        _ = try await repository.createPlan(plan)

        try await repository.deleteReferenceUrl(id: url1.id, from: plan.id)

        let fetched = try await repository.getPlan(id: plan.id)
        #expect(fetched?.referenceUrls.count == 1)
        #expect(fetched?.referenceUrls.first?.url == "https://example.com/url2")
    }

    @Test("Core Data: Empty relationships are handled correctly")
    func testEmptyRelationships() async throws {
        let controller = createTestController()
        let repository = CoreDataProjectPlanRepository(persistenceController: controller)

        let plan = ProjectPlanModel(
            title: "Empty Plan",
            planType: .idea,
            tags: [],
            glassItems: [],
            referenceUrls: []
        )

        _ = try await repository.createPlan(plan)
        let fetched = try await repository.getPlan(id: plan.id)

        #expect(fetched?.tags.isEmpty == true)
        #expect(fetched?.glassItems.isEmpty == true)
        #expect(fetched?.referenceUrls.isEmpty == true)
    }

    @Test("Core Data: Complex plan with all relationship types")
    func testComplexPlanWithAllRelationships() async throws {
        let controller = createTestController()
        let repository = CoreDataProjectPlanRepository(persistenceController: controller)

        let plan = ProjectPlanModel(
            title: "Complex Plan",
            planType: .recipe,
            tags: ["advanced", "sculpture", "color", "large-scale"],
            summary: "A comprehensive test plan with all relationship types",
            glassItems: [
                ProjectGlassItem(naturalKey: "be-clear-000", quantity: 5, unit: "rods", notes: "Base structure"),
                ProjectGlassItem(naturalKey: "be-blue-308", quantity: 3, unit: "rods", notes: "Accent color"),
                ProjectGlassItem(naturalKey: "ef-turquoise-142", quantity: 2.5, unit: "tubes", notes: "Details")
            ],
            referenceUrls: [
                ProjectReferenceUrl(url: "https://youtube.com/tutorial1", title: "Video Tutorial", description: "Main technique"),
                ProjectReferenceUrl(url: "https://pinterest.com/inspiration", title: "Inspiration Board"),
                ProjectReferenceUrl(url: "https://example.com/pattern", title: "Pattern PDF", description: "Download link")
            ]
        )

        _ = try await repository.createPlan(plan)
        let fetched = try await repository.getPlan(id: plan.id)

        #expect(fetched?.title == "Complex Plan")
        #expect(fetched?.tags.count == 4)
        #expect(fetched?.tags.contains("sculpture") == true)
        #expect(fetched?.glassItems.count == 3)
        #expect(fetched?.glassItems[0].notes == "Base structure")
        #expect(fetched?.glassItems[2].quantity == 2.5)
        #expect(fetched?.referenceUrls.count == 3)
        #expect(fetched?.referenceUrls[1].url == "https://pinterest.com/inspiration")
    }

    @Test("Core Data: Cascade delete removes all plan relationships")
    func testCascadeDeleteRemovesPlanRelationships() async throws {
        let controller = createTestController()
        let repository = CoreDataProjectPlanRepository(persistenceController: controller)
        let context = controller.container.viewContext

        // Create plan with tags, glass items, and reference URLs
        let plan = ProjectPlanModel(
            title: "Plan to Delete",
            planType: .recipe,
            tags: ["tag1", "tag2"],
            glassItems: [
                ProjectGlassItem(naturalKey: "item1", quantity: 1.0, unit: "rods")
            ],
            referenceUrls: [
                ProjectReferenceUrl(url: "https://example.com/url1", title: "URL 1")
            ]
        )
        _ = try await repository.createPlan(plan)

        // Verify relationships were created
        let tagsFetch = ProjectTag.fetchRequest()
        tagsFetch.predicate = NSPredicate(format: "plan.id == %@", plan.id as CVarArg)
        let tagsBeforeDelete = try await context.perform {
            try context.fetch(tagsFetch)
        }
        #expect(tagsBeforeDelete.count == 2)

        let glassItemsFetch = ProjectPlanGlassItem.fetchRequest()
        glassItemsFetch.predicate = NSPredicate(format: "plan.id == %@", plan.id as CVarArg)
        let glassItemsBeforeDelete = try await context.perform {
            try context.fetch(glassItemsFetch)
        }
        #expect(glassItemsBeforeDelete.count == 1)

        let urlsFetch = ProjectPlanReferenceUrl.fetchRequest()
        urlsFetch.predicate = NSPredicate(format: "plan.id == %@", plan.id as CVarArg)
        let urlsBeforeDelete = try await context.perform {
            try context.fetch(urlsFetch)
        }
        #expect(urlsBeforeDelete.count == 1)

        // Delete the plan
        try await repository.deletePlan(id: plan.id)

        // Verify all relationships were cascade deleted
        let tagsAfterDelete = try await context.perform {
            try context.fetch(tagsFetch)
        }
        #expect(tagsAfterDelete.isEmpty)

        let glassItemsAfterDelete = try await context.perform {
            try context.fetch(glassItemsFetch)
        }
        #expect(glassItemsAfterDelete.isEmpty)

        let urlsAfterDelete = try await context.perform {
            try context.fetch(urlsFetch)
        }
        #expect(urlsAfterDelete.isEmpty)
    }

    @Test("Core Data: Multiple plans can have same tag strings")
    func testMultiplePlansCanShareTagStrings() async throws {
        let controller = createTestController()
        let repository = CoreDataProjectPlanRepository(persistenceController: controller)

        // Create two plans with overlapping tags
        let plan1 = ProjectPlanModel(
            title: "Plan 1",
            planType: .recipe,
            tags: ["shared-tag", "plan1-tag"]
        )
        let plan2 = ProjectPlanModel(
            title: "Plan 2",
            planType: .idea,
            tags: ["shared-tag", "plan2-tag"]
        )

        _ = try await repository.createPlan(plan1)
        _ = try await repository.createPlan(plan2)

        // Verify both plans have their tags
        let fetched1 = try await repository.getPlan(id: plan1.id)
        let fetched2 = try await repository.getPlan(id: plan2.id)

        #expect(fetched1?.tags.contains("shared-tag") == true)
        #expect(fetched1?.tags.contains("plan1-tag") == true)
        #expect(fetched2?.tags.contains("shared-tag") == true)
        #expect(fetched2?.tags.contains("plan2-tag") == true)

        // Delete plan1 should not affect plan2's tags
        try await repository.deletePlan(id: plan1.id)

        let fetched2After = try await repository.getPlan(id: plan2.id)
        #expect(fetched2After?.tags.contains("shared-tag") == true)
        #expect(fetched2After?.tags.contains("plan2-tag") == true)
    }
}
#endif
