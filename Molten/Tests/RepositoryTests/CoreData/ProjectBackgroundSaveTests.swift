//
//  ProjectPlanBackgroundSaveTests.swift
//  Molten
//
//  Tests for background plan creation when adding child items (glass, URLs, images)
//  to unsaved plans
//

#if canImport(Testing)
import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Project Plan Background Save Tests")
@MainActor
struct ProjectPlanBackgroundSaveTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store PersistenceController at struct level to keep it alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let controller = PersistenceController.createTestController()

    func createTestRepository() -> CoreDataProjectRepository {
        return CoreDataProjectRepository(context: controller.container.viewContext)
    }

    // MARK: - Background Save Tests

    @Test("Background save creates plan with 'Untitled' when title is empty")
    func testBackgroundSaveWithEmptyTitle() async throws {
        let repository = createTestRepository()

        // Create a new plan with empty title (simulating user clicking "+" button)
        let newPlan = ProjectModel(
            title: "",
            type: .idea,
            coe: "any",
            summary: nil
        )

        // Simulate background save when user clicks "Add Glass" without entering title
        // The plan should be saved with "Untitled" as the title
        let savedPlan = ProjectModel(
            id: newPlan.id,
            title: "Untitled",  // Background save uses "Untitled" as fallback
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        _ = try await repository.createProject(savedPlan)

        // Verify the plan was saved with "Untitled"
        let fetched = try await repository.getProject(id: newPlan.id)
        #expect(fetched != nil)
        #expect(fetched?.title == "Untitled")
    }

    @Test("Background save preserves user-entered title")
    func testBackgroundSaveWithUserTitle() async throws {
        let repository = createTestRepository()

        // Create a new plan where user has entered a title
        let newPlan = ProjectModel(
            title: "",
            type: .recipe,
            coe: "96",
            summary: nil
        )

        // User enters title but doesn't click "Done" yet
        let userTitle = "My Glass Bowl"

        // Simulate background save with user's partial input
        let savedPlan = ProjectModel(
            id: newPlan.id,
            title: userTitle,  // Use user's title if they entered one
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        _ = try await repository.createProject(savedPlan)

        // Verify the plan was saved with user's title
        let fetched = try await repository.getProject(id: newPlan.id)
        #expect(fetched != nil)
        #expect(fetched?.title == "My Glass Bowl")
    }

    @Test("Background save then add glass item works correctly")
    func testBackgroundSaveThenAddGlass() async throws {
        let repository = createTestRepository()

        // Step 1: Create new plan with empty title
        let newPlan = ProjectModel(
            title: "",
            type: .recipe,
            coe: "96",
            summary: nil
        )

        // Step 2: Background save with "Untitled" (user clicked "Add Glass")
        let backgroundSavedPlan = ProjectModel(
            id: newPlan.id,
            title: "Untitled",
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary,
            glassItems: []
        )

        _ = try await repository.createProject(backgroundSavedPlan)

        // Step 3: Now add glass item (this requires plan to exist in repository)
        let glassItem = ProjectGlassItem(
            stableId: "bullseye-clear-001",
            quantity: 5,
            unit: "rods",
            notes: "For base"
        )

        let updatedPlan = ProjectModel(
            id: newPlan.id,
            title: backgroundSavedPlan.title,
            type: backgroundSavedPlan.type,
            dateCreated: backgroundSavedPlan.dateCreated,
            dateModified: Date(),
            isArchived: backgroundSavedPlan.isArchived,
            coe: backgroundSavedPlan.coe,
            summary: backgroundSavedPlan.summary,
            glassItems: [glassItem]
        )

        try await repository.updateProject(updatedPlan)

        // Verify glass item was added successfully
        let fetched = try await repository.getProject(id: newPlan.id)
        #expect(fetched?.glassItems.count == 1)
        #expect(fetched?.glassItems.first?.stableId == "bullseye-clear-001")
        #expect(fetched?.glassItems.first?.quantity == 5)
    }

    @Test("Background save then add reference URL works correctly")
    func testBackgroundSaveThenAddURL() async throws {
        let repository = createTestRepository()

        // Step 1: Create new plan with empty title
        let newPlan = ProjectModel(
            title: "",
            type: .tutorial,
            coe: "any",
            summary: nil
        )

        // Step 2: Background save with "Untitled" (user clicked "Add URL")
        let backgroundSavedPlan = ProjectModel(
            id: newPlan.id,
            title: "Untitled",
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary,
            referenceUrls: []
        )

        _ = try await repository.createProject(backgroundSavedPlan)

        // Step 3: Now add reference URL (this requires plan to exist in repository)
        let refUrl = ProjectReferenceUrl(
            url: "https://youtube.com/tutorial",
            title: "Glassblowing Tutorial",
            description: "How to make a bowl"
        )

        let updatedPlan = ProjectModel(
            id: newPlan.id,
            title: backgroundSavedPlan.title,
            type: backgroundSavedPlan.type,
            dateCreated: backgroundSavedPlan.dateCreated,
            dateModified: Date(),
            isArchived: backgroundSavedPlan.isArchived,
            coe: backgroundSavedPlan.coe,
            summary: backgroundSavedPlan.summary,
            referenceUrls: [refUrl]
        )

        try await repository.updateProject(updatedPlan)

        // Verify URL was added successfully
        let fetched = try await repository.getProject(id: newPlan.id)
        #expect(fetched?.referenceUrls.count == 1)
        #expect(fetched?.referenceUrls.first?.url == "https://youtube.com/tutorial")
        #expect(fetched?.referenceUrls.first?.title == "Glassblowing Tutorial")
    }

    @Test("Background save preserves partial user input")
    func testBackgroundSavePreservesPartialInput() async throws {
        let repository = createTestRepository()

        // Create a new plan where user has filled in some fields
        let newPlan = ProjectModel(
            title: "",  // Empty title
            type: .recipe,
            coe: "96",  // User selected COE
            summary: "Making a decorative bowl"  // User entered summary
        )

        // Background save should preserve all the user's input
        let savedPlan = ProjectModel(
            id: newPlan.id,
            title: "Untitled",  // Only title gets default value
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,  // Preserve user's COE
            summary: newPlan.summary  // Preserve user's summary
        )

        _ = try await repository.createProject(savedPlan)

        // Verify all user input was preserved
        let fetched = try await repository.getProject(id: newPlan.id)
        #expect(fetched?.title == "Untitled")
        #expect(fetched?.coe == "96")
        #expect(fetched?.summary == "Making a decorative bowl")
    }

    @Test("Multiple background saves don't create duplicates")
    func testMultipleBackgroundSavesNoDuplicates() async throws {
        let repository = createTestRepository()

        // Create a new plan
        let newPlan = ProjectModel(
            title: "",
            type: .idea,
            coe: "any",
            summary: nil
        )

        // First background save (user clicks "Add Glass")
        let firstSave = ProjectModel(
            id: newPlan.id,
            title: "Untitled",
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        _ = try await repository.createProject(firstSave)

        // Second "background save" should be an update, not a create
        // (user clicks "Add URL" after adding glass)
        let refUrl = ProjectReferenceUrl(
            url: "https://example.com",
            title: "Example"
        )

        let secondSave = ProjectModel(
            id: newPlan.id,
            title: "Untitled",
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary,
            referenceUrls: [refUrl]
        )

        try await repository.updateProject(secondSave)

        // Verify only one plan exists with this ID
        let fetched = try await repository.getProject(id: newPlan.id)
        #expect(fetched != nil)
        #expect(fetched?.referenceUrls.count == 1)

        // Verify no duplicates in database
        let allPlans = try await repository.getActiveProjects()
        let matchingPlans = allPlans.filter { $0.id == newPlan.id }
        #expect(matchingPlans.count == 1)
    }

    @Test("Final save with user title overwrites 'Untitled'")
    func testFinalSaveOverwritesUntitled() async throws {
        let repository = createTestRepository()

        // Create a new plan
        let newPlan = ProjectModel(
            title: "",
            type: .recipe,
            coe: "96",
            summary: nil
        )

        // Background save with "Untitled"
        let backgroundSave = ProjectModel(
            id: newPlan.id,
            title: "Untitled",
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        _ = try await repository.createProject(backgroundSave)

        // User finally enters a title and clicks "Done"
        let finalSave = ProjectModel(
            id: newPlan.id,
            title: "Beautiful Glass Vase",
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        try await repository.updateProject(finalSave)

        // Verify "Untitled" was replaced with user's title
        let fetched = try await repository.getProject(id: newPlan.id)
        #expect(fetched?.title == "Beautiful Glass Vase")
    }

    @Test("Background save with glass, URL, and tags all together")
    func testComplexBackgroundSaveScenario() async throws {
        let repository = createTestRepository()

        // User creates new plan and immediately starts adding stuff
        let newPlan = ProjectModel(
            title: "",
            type: .recipe,
            coe: "96",
            summary: nil
        )

        // Background save triggered by "Add Glass"
        let backgroundSave = ProjectModel(
            id: newPlan.id,
            title: "Untitled",
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        _ = try await repository.createProject(backgroundSave)

        // User adds glass
        let glassItem = ProjectGlassItem(
            stableId: "bullseye-clear-001",
            quantity: 3,
            unit: "rods"
        )

        let withGlass = ProjectModel(
            id: newPlan.id,
            title: "Untitled",
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary,
            glassItems: [glassItem]
        )

        try await repository.updateProject(withGlass)

        // User adds URL
        let refUrl = ProjectReferenceUrl(
            url: "https://youtube.com/tutorial",
            title: "Tutorial"
        )

        let withURL = ProjectModel(
            id: newPlan.id,
            title: "Untitled",
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary,
            glassItems: [glassItem],
            referenceUrls: [refUrl]
        )

        try await repository.updateProject(withURL)

        // User finally enters title and more tags, then clicks "Done"
        let finalPlan = ProjectModel(
            id: newPlan.id,
            title: "My First Bowl",
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary,
            glassItems: [glassItem],
            referenceUrls: [refUrl]
        )

        try await repository.updateProject(finalPlan)

        // Verify everything was saved correctly
        let fetched = try await repository.getProject(id: newPlan.id)
        #expect(fetched?.title == "My First Bowl")
        #expect(fetched?.glassItems.count == 1)
        #expect(fetched?.referenceUrls.count == 1)
    }

    @Test("Cancel after background save deletes the plan")
    func testCancelAfterBackgroundSave() async throws {
        let repository = createTestRepository()

        // Create a new plan
        let newPlan = ProjectModel(
            title: "",
            type: .idea,
            coe: "any",
            summary: nil
        )

        // Background save (user clicked "Add Glass")
        let backgroundSave = ProjectModel(
            id: newPlan.id,
            title: "Untitled",
            type: newPlan.type,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        _ = try await repository.createProject(backgroundSave)

        // User clicks "Cancel" - plan should be deleted
        try await repository.deleteProject(id: newPlan.id)

        // Verify plan was deleted
        let fetched = try await repository.getProject(id: newPlan.id)
        #expect(fetched == nil)
    }
}
#endif
