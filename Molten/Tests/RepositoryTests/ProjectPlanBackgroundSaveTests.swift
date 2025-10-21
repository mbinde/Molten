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
struct ProjectPlanBackgroundSaveTests {

    // MARK: - Test Helpers

    func createTestController() -> PersistenceController {
        return PersistenceController.createTestController()
    }

    func createTestRepository() -> CoreDataProjectPlanRepository {
        let controller = createTestController()
        return CoreDataProjectPlanRepository(persistenceController: controller)
    }

    // MARK: - Background Save Tests

    @Test("Background save creates plan with 'Untitled' when title is empty")
    func testBackgroundSaveWithEmptyTitle() async throws {
        let repository = createTestRepository()

        // Create a new plan with empty title (simulating user clicking "+" button)
        let newPlan = ProjectPlanModel(
            title: "",
            planType: .idea,
            tags: [],
            coe: "any",
            summary: nil
        )

        // Simulate background save when user clicks "Add Glass" without entering title
        // The plan should be saved with "Untitled" as the title
        let savedPlan = ProjectPlanModel(
            id: newPlan.id,
            title: "Untitled",  // Background save uses "Untitled" as fallback
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        _ = try await repository.createPlan(savedPlan)

        // Verify the plan was saved with "Untitled"
        let fetched = try await repository.getPlan(id: newPlan.id)
        #expect(fetched != nil)
        #expect(fetched?.title == "Untitled")
    }

    @Test("Background save preserves user-entered title")
    func testBackgroundSaveWithUserTitle() async throws {
        let repository = createTestRepository()

        // Create a new plan where user has entered a title
        let newPlan = ProjectPlanModel(
            title: "",
            planType: .recipe,
            tags: [],
            coe: "96",
            summary: nil
        )

        // User enters title but doesn't click "Done" yet
        let userTitle = "My Glass Bowl"

        // Simulate background save with user's partial input
        let savedPlan = ProjectPlanModel(
            id: newPlan.id,
            title: userTitle,  // Use user's title if they entered one
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        _ = try await repository.createPlan(savedPlan)

        // Verify the plan was saved with user's title
        let fetched = try await repository.getPlan(id: newPlan.id)
        #expect(fetched != nil)
        #expect(fetched?.title == "My Glass Bowl")
    }

    @Test("Background save then add glass item works correctly")
    func testBackgroundSaveThenAddGlass() async throws {
        let repository = createTestRepository()

        // Step 1: Create new plan with empty title
        let newPlan = ProjectPlanModel(
            title: "",
            planType: .recipe,
            tags: [],
            coe: "96",
            summary: nil
        )

        // Step 2: Background save with "Untitled" (user clicked "Add Glass")
        let backgroundSavedPlan = ProjectPlanModel(
            id: newPlan.id,
            title: "Untitled",
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,
            coe: newPlan.coe,
            summary: newPlan.summary,
            glassItems: []
        )

        _ = try await repository.createPlan(backgroundSavedPlan)

        // Step 3: Now add glass item (this requires plan to exist in repository)
        let glassItem = ProjectGlassItem(
            naturalKey: "bullseye-clear-001",
            quantity: 5,
            unit: "rods",
            notes: "For base"
        )

        let updatedPlan = ProjectPlanModel(
            id: newPlan.id,
            title: backgroundSavedPlan.title,
            planType: backgroundSavedPlan.planType,
            dateCreated: backgroundSavedPlan.dateCreated,
            dateModified: Date(),
            isArchived: backgroundSavedPlan.isArchived,
            tags: backgroundSavedPlan.tags,
            coe: backgroundSavedPlan.coe,
            summary: backgroundSavedPlan.summary,
            glassItems: [glassItem]
        )

        try await repository.updatePlan(updatedPlan)

        // Verify glass item was added successfully
        let fetched = try await repository.getPlan(id: newPlan.id)
        #expect(fetched?.glassItems.count == 1)
        #expect(fetched?.glassItems.first?.naturalKey == "bullseye-clear-001")
        #expect(fetched?.glassItems.first?.quantity == 5)
    }

    @Test("Background save then add reference URL works correctly")
    func testBackgroundSaveThenAddURL() async throws {
        let repository = createTestRepository()

        // Step 1: Create new plan with empty title
        let newPlan = ProjectPlanModel(
            title: "",
            planType: .tutorial,
            tags: [],
            coe: "any",
            summary: nil
        )

        // Step 2: Background save with "Untitled" (user clicked "Add URL")
        let backgroundSavedPlan = ProjectPlanModel(
            id: newPlan.id,
            title: "Untitled",
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,
            coe: newPlan.coe,
            summary: newPlan.summary,
            referenceUrls: []
        )

        _ = try await repository.createPlan(backgroundSavedPlan)

        // Step 3: Now add reference URL (this requires plan to exist in repository)
        let refUrl = ProjectReferenceUrl(
            url: "https://youtube.com/tutorial",
            title: "Glassblowing Tutorial",
            description: "How to make a bowl"
        )

        let updatedPlan = ProjectPlanModel(
            id: newPlan.id,
            title: backgroundSavedPlan.title,
            planType: backgroundSavedPlan.planType,
            dateCreated: backgroundSavedPlan.dateCreated,
            dateModified: Date(),
            isArchived: backgroundSavedPlan.isArchived,
            tags: backgroundSavedPlan.tags,
            coe: backgroundSavedPlan.coe,
            summary: backgroundSavedPlan.summary,
            referenceUrls: [refUrl]
        )

        try await repository.updatePlan(updatedPlan)

        // Verify URL was added successfully
        let fetched = try await repository.getPlan(id: newPlan.id)
        #expect(fetched?.referenceUrls.count == 1)
        #expect(fetched?.referenceUrls.first?.url == "https://youtube.com/tutorial")
        #expect(fetched?.referenceUrls.first?.title == "Glassblowing Tutorial")
    }

    @Test("Background save preserves partial user input")
    func testBackgroundSavePreservesPartialInput() async throws {
        let repository = createTestRepository()

        // Create a new plan where user has filled in some fields
        let newPlan = ProjectPlanModel(
            title: "",  // Empty title
            planType: .recipe,
            tags: ["bowl", "sculpture"],  // User added tags
            coe: "96",  // User selected COE
            summary: "Making a decorative bowl"  // User entered summary
        )

        // Background save should preserve all the user's input
        let savedPlan = ProjectPlanModel(
            id: newPlan.id,
            title: "Untitled",  // Only title gets default value
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,  // Preserve user's tags
            coe: newPlan.coe,  // Preserve user's COE
            summary: newPlan.summary  // Preserve user's summary
        )

        _ = try await repository.createPlan(savedPlan)

        // Verify all user input was preserved
        let fetched = try await repository.getPlan(id: newPlan.id)
        #expect(fetched?.title == "Untitled")
        #expect(fetched?.tags.sorted() == ["bowl", "sculpture"])
        #expect(fetched?.coe == "96")
        #expect(fetched?.summary == "Making a decorative bowl")
    }

    @Test("Multiple background saves don't create duplicates")
    func testMultipleBackgroundSavesNoDuplicates() async throws {
        let repository = createTestRepository()

        // Create a new plan
        let newPlan = ProjectPlanModel(
            title: "",
            planType: .idea,
            tags: [],
            coe: "any",
            summary: nil
        )

        // First background save (user clicks "Add Glass")
        let firstSave = ProjectPlanModel(
            id: newPlan.id,
            title: "Untitled",
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        _ = try await repository.createPlan(firstSave)

        // Second "background save" should be an update, not a create
        // (user clicks "Add URL" after adding glass)
        let refUrl = ProjectReferenceUrl(
            url: "https://example.com",
            title: "Example"
        )

        let secondSave = ProjectPlanModel(
            id: newPlan.id,
            title: "Untitled",
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,
            coe: newPlan.coe,
            summary: newPlan.summary,
            referenceUrls: [refUrl]
        )

        try await repository.updatePlan(secondSave)

        // Verify only one plan exists with this ID
        let fetched = try await repository.getPlan(id: newPlan.id)
        #expect(fetched != nil)
        #expect(fetched?.referenceUrls.count == 1)

        // Verify no duplicates in database
        let allPlans = try await repository.getActivePlans()
        let matchingPlans = allPlans.filter { $0.id == newPlan.id }
        #expect(matchingPlans.count == 1)
    }

    @Test("Final save with user title overwrites 'Untitled'")
    func testFinalSaveOverwritesUntitled() async throws {
        let repository = createTestRepository()

        // Create a new plan
        let newPlan = ProjectPlanModel(
            title: "",
            planType: .recipe,
            tags: [],
            coe: "96",
            summary: nil
        )

        // Background save with "Untitled"
        let backgroundSave = ProjectPlanModel(
            id: newPlan.id,
            title: "Untitled",
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        _ = try await repository.createPlan(backgroundSave)

        // User finally enters a title and clicks "Done"
        let finalSave = ProjectPlanModel(
            id: newPlan.id,
            title: "Beautiful Glass Vase",
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        try await repository.updatePlan(finalSave)

        // Verify "Untitled" was replaced with user's title
        let fetched = try await repository.getPlan(id: newPlan.id)
        #expect(fetched?.title == "Beautiful Glass Vase")
    }

    @Test("Background save with glass, URL, and tags all together")
    func testComplexBackgroundSaveScenario() async throws {
        let repository = createTestRepository()

        // User creates new plan and immediately starts adding stuff
        let newPlan = ProjectPlanModel(
            title: "",
            planType: .recipe,
            tags: ["bowl"],  // User added one tag
            coe: "96",
            summary: nil
        )

        // Background save triggered by "Add Glass"
        let backgroundSave = ProjectPlanModel(
            id: newPlan.id,
            title: "Untitled",
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        _ = try await repository.createPlan(backgroundSave)

        // User adds glass
        let glassItem = ProjectGlassItem(
            naturalKey: "bullseye-clear-001",
            quantity: 3,
            unit: "rods"
        )

        let withGlass = ProjectPlanModel(
            id: newPlan.id,
            title: "Untitled",
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,
            coe: newPlan.coe,
            summary: newPlan.summary,
            glassItems: [glassItem]
        )

        try await repository.updatePlan(withGlass)

        // User adds URL
        let refUrl = ProjectReferenceUrl(
            url: "https://youtube.com/tutorial",
            title: "Tutorial"
        )

        let withURL = ProjectPlanModel(
            id: newPlan.id,
            title: "Untitled",
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,
            coe: newPlan.coe,
            summary: newPlan.summary,
            glassItems: [glassItem],
            referenceUrls: [refUrl]
        )

        try await repository.updatePlan(withURL)

        // User finally enters title and more tags, then clicks "Done"
        let finalPlan = ProjectPlanModel(
            id: newPlan.id,
            title: "My First Bowl",
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: ["bowl", "beginner", "tutorial"],
            coe: newPlan.coe,
            summary: newPlan.summary,
            glassItems: [glassItem],
            referenceUrls: [refUrl]
        )

        try await repository.updatePlan(finalPlan)

        // Verify everything was saved correctly
        let fetched = try await repository.getPlan(id: newPlan.id)
        #expect(fetched?.title == "My First Bowl")
        #expect(fetched?.tags.sorted() == ["beginner", "bowl", "tutorial"])
        #expect(fetched?.glassItems.count == 1)
        #expect(fetched?.referenceUrls.count == 1)
    }

    @Test("Cancel after background save deletes the plan")
    func testCancelAfterBackgroundSave() async throws {
        let repository = createTestRepository()

        // Create a new plan
        let newPlan = ProjectPlanModel(
            title: "",
            planType: .idea,
            tags: [],
            coe: "any",
            summary: nil
        )

        // Background save (user clicked "Add Glass")
        let backgroundSave = ProjectPlanModel(
            id: newPlan.id,
            title: "Untitled",
            planType: newPlan.planType,
            dateCreated: newPlan.dateCreated,
            dateModified: Date(),
            isArchived: newPlan.isArchived,
            tags: newPlan.tags,
            coe: newPlan.coe,
            summary: newPlan.summary
        )

        _ = try await repository.createPlan(backgroundSave)

        // User clicks "Cancel" - plan should be deleted
        try await repository.deletePlan(id: newPlan.id)

        // Verify plan was deleted
        let fetched = try await repository.getPlan(id: newPlan.id)
        #expect(fetched == nil)
    }
}
#endif
