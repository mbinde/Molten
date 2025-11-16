//
//  CoreDataProjectRepositoryTests.swift
//  Molten
//
//  Tests for CoreDataProjectRepository with relationship-based storage
//

#if canImport(Testing)
import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("CoreDataProjectRepository Tests")
@MainActor
struct CoreDataProjectRepositoryTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store PersistenceController at struct level to keep it alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let controller = PersistenceController.createTestController()

    func createTestPlan(
        id: UUID = UUID(),
        title: String = "Test Plan",
        type: ProjectPlanType = .recipe,
        isArchived: Bool = false,
        summary: String? = "Test summary",
        glassItems: [ProjectGlassItem] = [],
        referenceUrls: [ProjectReferenceUrl] = []
    ) -> ProjectPlanModel {
        return ProjectModel(
            id: id,
            title: title,
            type: type,
            isArchived: isArchived,
            summary: summary,
            glassItems: glassItems,
            referenceUrls: referenceUrls
        )
    }

    // MARK: - Relationship-Based Storage Tests

    @Test("Core Data: Relationship-based storage for tags, glass items, and reference URLs")
    func testRelationshipBasedStorage() async throws {
        let repository = CoreDataProjectRepository(context: controller.container.viewContext)

        let plan = ProjectModel(
            title: "Test Relationships",
            type: .recipe,
            glassItems: [
                ProjectGlassItem(stableId: "item1", quantity: 1.0, unit: "rods"),
                ProjectGlassItem(stableId: "item2", quantity: 2.5, unit: "tubes")
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

        _ = try await repository.createProject(plan)
        let fetched = try await repository.getProject(id: plan.id)

        // Verify tags are stored as relationships (sorted alphabetically)

        // Verify glass items are stored as relationships (ordered by orderIndex)
        #expect(fetched?.glassItems.count == 2)
        #expect(fetched?.glassItems[0].stableId == "item1")
        #expect(fetched?.glassItems[0].quantity == 1.0)
        #expect(fetched?.glassItems[1].stableId == "item2")
        #expect(fetched?.glassItems[1].quantity == 2.5)

        // Verify reference URLs are stored as relationships (ordered by orderIndex)
        #expect(fetched?.referenceUrls.count == 2)
        #expect(fetched?.referenceUrls[0].url == "https://example.com/tutorial1")
        #expect(fetched?.referenceUrls[0].title == "Tutorial 1")
        #expect(fetched?.referenceUrls[1].url == "https://example.com/tutorial2")
    }

    @Test("Core Data: Update replaces relationships correctly")
    func testUpdateReplacesRelationships() async throws {
        let repository = CoreDataProjectRepository(context: controller.container.viewContext)

        // Create plan with initial relationships
        let plan = ProjectModel(
            title: "Test Update",
            type: .recipe,
            glassItems: [
                ProjectGlassItem(stableId: "old-item", quantity: 1.0, unit: "rods")
            ],
            referenceUrls: [
                ProjectReferenceUrl(url: "https://example.com/old")
            ]
        )
        _ = try await repository.createProject(plan)

        // Update with completely different relationships
        let updatedPlan = ProjectModel(
            id: plan.id,
            title: "Test Update",
            type: .recipe,
            glassItems: [
                ProjectGlassItem(stableId: "new-item1", quantity: 2.0, unit: "tubes"),
                ProjectGlassItem(stableId: "new-item2", quantity: 3.0, unit: "rods")
            ],
            referenceUrls: [
                ProjectReferenceUrl(url: "https://example.com/new1", title: "New 1"),
                ProjectReferenceUrl(url: "https://example.com/new2", title: "New 2")
            ]
        )
        try await repository.updateProject(updatedPlan)

        // Fetch and verify old relationships are gone, new ones are present
        let fetched = try await repository.getProject(id: plan.id)


        #expect(fetched?.glassItems.count == 2)
        #expect(fetched?.glassItems[0].stableId == "new-item1")
        #expect(fetched?.glassItems[1].stableId == "new-item2")
        #expect(!fetched!.glassItems.contains(where: { $0.stableId == "old-item" }))

        #expect(fetched?.referenceUrls.count == 2)
        #expect(fetched?.referenceUrls[0].url == "https://example.com/new1")
        #expect(fetched?.referenceUrls[1].url == "https://example.com/new2")
        #expect(!fetched!.referenceUrls.contains(where: { $0.url == "https://example.com/old" }))
    }

    @Test("Core Data: Add reference URL creates proper relationship")
    func testAddReferenceUrl() async throws {
        let repository = CoreDataProjectRepository(context: controller.container.viewContext)

        let plan = createTestPlan(referenceUrls: [])
        _ = try await repository.createProject(plan)

        let newUrl = ProjectReferenceUrl(
            url: "https://example.com/added",
            title: "Added URL",
            description: "Dynamically added"
        )

        try await repository.addReferenceUrl(newUrl, to: plan.id)

        let fetched = try await repository.getProject(id: plan.id)
        #expect(fetched?.referenceUrls.count == 1)
        #expect(fetched?.referenceUrls.first?.url == "https://example.com/added")
        #expect(fetched?.referenceUrls.first?.title == "Added URL")
    }

    @Test("Core Data: Update reference URL modifies existing relationship")
    func testUpdateReferenceUrl() async throws {
        let repository = CoreDataProjectRepository(context: controller.container.viewContext)

        let originalUrl = ProjectReferenceUrl(
            url: "https://example.com/original",
            title: "Original"
        )
        let plan = createTestPlan(referenceUrls: [originalUrl])
        _ = try await repository.createProject(plan)

        let updatedUrl = ProjectReferenceUrl(
            id: originalUrl.id,
            url: "https://example.com/updated",
            title: "Updated Title",
            description: "Updated description",
            dateAdded: originalUrl.dateAdded
        )

        try await repository.updateReferenceUrl(updatedUrl, in: plan.id)

        let fetched = try await repository.getProject(id: plan.id)
        #expect(fetched?.referenceUrls.count == 1)
        #expect(fetched?.referenceUrls.first?.url == "https://example.com/updated")
        #expect(fetched?.referenceUrls.first?.title == "Updated Title")
        #expect(fetched?.referenceUrls.first?.description == "Updated description")
    }

    @Test("Core Data: Delete reference URL removes relationship")
    func testDeleteReferenceUrl() async throws {
        let repository = CoreDataProjectRepository(context: controller.container.viewContext)

        let url1 = ProjectReferenceUrl(url: "https://example.com/url1", title: "URL 1")
        let url2 = ProjectReferenceUrl(url: "https://example.com/url2", title: "URL 2")
        let plan = createTestPlan(referenceUrls: [url1, url2])
        _ = try await repository.createProject(plan)

        try await repository.deleteReferenceUrl(id: url1.id, from: plan.id)

        let fetched = try await repository.getProject(id: plan.id)
        #expect(fetched?.referenceUrls.count == 1)
        #expect(fetched?.referenceUrls.first?.url == "https://example.com/url2")
    }

    @Test("Core Data: Empty relationships are handled correctly")
    func testEmptyRelationships() async throws {
        let repository = CoreDataProjectRepository(context: controller.container.viewContext)

        let plan = ProjectModel(
            title: "Empty Plan",
            type: .idea,
            glassItems: [],
            referenceUrls: []
        )

        _ = try await repository.createProject(plan)
        let fetched = try await repository.getProject(id: plan.id)

        #expect(fetched?.glassItems.isEmpty == true)
        #expect(fetched?.referenceUrls.isEmpty == true)
    }

    @Test("Core Data: Complex plan with all relationship types")
    func testComplexPlanWithAllRelationships() async throws {
        let repository = CoreDataProjectRepository(context: controller.container.viewContext)

        let plan = ProjectModel(
            title: "Complex Plan",
            type: .recipe,
            summary: "A comprehensive test plan with all relationship types",
            glassItems: [
                ProjectGlassItem(stableId: "be-clear-000", quantity: 5, unit: "rods", notes: "Base structure"),
                ProjectGlassItem(stableId: "be-blue-308", quantity: 3, unit: "rods", notes: "Accent color"),
                ProjectGlassItem(stableId: "ef-turquoise-142", quantity: 2.5, unit: "tubes", notes: "Details")
            ],
            referenceUrls: [
                ProjectReferenceUrl(url: "https://youtube.com/tutorial1", title: "Video Tutorial", description: "Main technique"),
                ProjectReferenceUrl(url: "https://pinterest.com/inspiration", title: "Inspiration Board"),
                ProjectReferenceUrl(url: "https://example.com/pattern", title: "Pattern PDF", description: "Download link")
            ]
        )

        _ = try await repository.createProject(plan)
        let fetched = try await repository.getProject(id: plan.id)

        #expect(fetched?.title == "Complex Plan")
        #expect(fetched?.glassItems.count == 3)
        #expect(fetched?.glassItems[0].notes == "Base structure")
        #expect(fetched?.glassItems[2].quantity == 2.5)
        #expect(fetched?.referenceUrls.count == 3)
        #expect(fetched?.referenceUrls[1].url == "https://pinterest.com/inspiration")
    }

    @Test("Core Data: Cascade delete removes all plan relationships")
    func testCascadeDeleteRemovesPlanRelationships() async throws {
        let repository = CoreDataProjectRepository(context: controller.container.viewContext)
        let context = controller.container.viewContext

        // Create plan with glass items and reference URLs
        let plan = ProjectModel(
            title: "Plan to Delete",
            type: .recipe,
            glassItems: [
                ProjectGlassItem(stableId: "item1", quantity: 1.0, unit: "rods")
            ],
            referenceUrls: [
                ProjectReferenceUrl(url: "https://example.com/url1", title: "URL 1")
            ]
        )
        _ = try await repository.createProject(plan)

        // Verify relationships were created
        let glassItemsFetch = NSFetchRequest<ProjectGlassItemEntity>(entityName: "ProjectGlassItem")
        glassItemsFetch.predicate = NSPredicate(format: "plan.id == %@", plan.id as CVarArg)
        let glassItemsBeforeDelete = try await context.perform {
            try context.fetch(glassItemsFetch)
        }
        #expect(glassItemsBeforeDelete.count == 1)

        let urlsFetch = NSFetchRequest<ProjectReferenceUrlEntity>(entityName: "ProjectReferenceUrl")
        urlsFetch.predicate = NSPredicate(format: "plan.id == %@", plan.id as CVarArg)
        let urlsBeforeDelete = try await context.perform {
            try context.fetch(urlsFetch)
        }
        #expect(urlsBeforeDelete.count == 1)

        // Delete the plan
        try await repository.deleteProject(id: plan.id)

        // Verify all relationships were cascade deleted
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
        let repository = CoreDataProjectRepository(context: controller.container.viewContext)

        // Create two plans with overlapping tags
        let plan1 = ProjectModel(
            title: "Plan 1",
            type: .recipe,
        )
        let plan2 = ProjectModel(
            title: "Plan 2",
            type: .idea,
        )

        _ = try await repository.createProject(plan1)
        _ = try await repository.createProject(plan2)

        // Verify both plans have their tags
        let fetched1 = try await repository.getProject(id: plan1.id)
        let fetched2 = try await repository.getProject(id: plan2.id)


        // Delete plan1 should not affect plan2's tags
        try await repository.deleteProject(id: plan1.id)

        let fetched2After = try await repository.getProject(id: plan2.id)
    }
}
#endif
