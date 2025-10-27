//
//  ProjectPlanRepositoryTests.swift
//  Flameworker
//
//  Tests for ProjectPlanRepository implementations (Mock and Core Data)
//

#if canImport(Testing)
import Testing
import Foundation
@testable import Molten

@Suite("ProjectPlanRepository Tests")
@MainActor
struct ProjectPlanRepositoryTests {

    // MARK: - Test Helpers

    func createTestPlan(
        id: UUID = UUID(),
        title: String = "Test Plan",
        type: ProjectPlanType = .recipe,
        isArchived: Bool = false,
        summary: String? = "Test summary",
        estimatedTime: Double? = 120.0,
        difficultyLevel: DifficultyLevel? = .intermediate,
        timesUsed: Int = 0,
        lastUsedDate: Date? = nil
    ) -> ProjectPlanModel {
        return ProjectModel(
            id: id,
            title: title,
            type: planType,
            dateCreated: Date(),
            dateModified: Date(),
            isArchived: isArchived,
            summary: summary,
            steps: [],
            estimatedTime: estimatedTime,
            difficultyLevel: difficultyLevel,
            proposedPriceRange: nil,
            images: [],
            heroImageId: nil,
            glassItems: [],
            referenceUrls: [],
            timesUsed: timesUsed,
            lastUsedDate: lastUsedDate
        )
    }

    // MARK: - CRUD Operations Tests

    @Test("Create plan successfully")
    func testCreatePlan() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan(title: "New Project")

        let created = try await repository.createProject(plan)

        #expect(created.id == plan.id)
        #expect(created.title == "New Project")
        #expect(await repository.getPlanCount() == 1)
    }

    @Test("Get plan by ID")
    func testGetPlanById() async throws {
        let repository = MockProjectPlanRepository()
        let plan1 = createTestPlan(title: "Plan 1")
        let plan2 = createTestPlan(title: "Plan 2")

        _ = try await repository.createProject(plan1)
        _ = try await repository.createProject(plan2)

        let fetched = try await repository.getProject(id: plan1.id)

        #expect(fetched?.id == plan1.id)
        #expect(fetched?.title == "Plan 1")
    }

    @Test("Get non-existent plan returns nil")
    func testGetNonExistentPlan() async throws {
        let repository = MockProjectPlanRepository()

        let fetched = try await repository.getProject(id: UUID())

        #expect(fetched == nil)
    }

    @Test("Get all plans including archived")
    func testGetAllPlansIncludingArchived() async throws {
        let repository = MockProjectPlanRepository()

        let active = createTestPlan(title: "Active", isArchived: false)
        let archived = createTestPlan(title: "Archived", isArchived: true)

        _ = try await repository.createProject(active)
        _ = try await repository.createProject(archived)

        let allPlans = try await repository.getAllPlans(includeArchived: true)

        #expect(allPlans.count == 2)
        #expect(allPlans.contains { $0.title == "Active" })
        #expect(allPlans.contains { $0.title == "Archived" })
    }

    @Test("Get all plans excluding archived")
    func testGetAllPlansExcludingArchived() async throws {
        let repository = MockProjectPlanRepository()

        let active1 = createTestPlan(title: "Active 1", isArchived: false)
        let active2 = createTestPlan(title: "Active 2", isArchived: false)
        let archived = createTestPlan(title: "Archived", isArchived: true)

        _ = try await repository.createProject(active1)
        _ = try await repository.createProject(active2)
        _ = try await repository.createProject(archived)

        let activePlans = try await repository.getAllPlans(includeArchived: false)

        #expect(activePlans.count == 2)
        #expect(activePlans.allSatisfy { !$0.isArchived })
    }

    @Test("Get active plans")
    func testGetActivePlans() async throws {
        let repository = MockProjectPlanRepository()

        let active1 = createTestPlan(title: "Active 1", isArchived: false)
        let active2 = createTestPlan(title: "Active 2", isArchived: false)
        let archived = createTestPlan(title: "Archived", isArchived: true)

        _ = try await repository.createProject(active1)
        _ = try await repository.createProject(active2)
        _ = try await repository.createProject(archived)

        let activePlans = try await repository.getActiveProjects()

        #expect(activePlans.count == 2)
        #expect(activePlans.allSatisfy { !$0.isArchived })
    }

    @Test("Get archived plans")
    func testGetArchivedPlans() async throws {
        let repository = MockProjectPlanRepository()

        let active = createTestPlan(title: "Active", isArchived: false)
        let archived1 = createTestPlan(title: "Archived 1", isArchived: true)
        let archived2 = createTestPlan(title: "Archived 2", isArchived: true)

        _ = try await repository.createProject(active)
        _ = try await repository.createProject(archived1)
        _ = try await repository.createProject(archived2)

        let archivedPlans = try await repository.getArchivedProjects()

        #expect(archivedPlans.count == 2)
        #expect(archivedPlans.allSatisfy { $0.isArchived })
    }

    @Test("Get plans by type")
    func testGetPlansByType() async throws {
        let repository = MockProjectPlanRepository()

        let recipe = createTestPlan(title: "Recipe", type: .recipe)
        let idea = createTestPlan(title: "Idea", type: .idea)
        let technique = createTestPlan(title: "Technique", type: .technique)

        _ = try await repository.createProject(recipe)
        _ = try await repository.createProject(idea)
        _ = try await repository.createProject(technique)

        let recipePlans = try await repository.getProjects(type: .recipe, includeArchived: true)
        let ideaPlans = try await repository.getProjects(type: .idea, includeArchived: true)

        #expect(recipePlans.count == 1)
        #expect(recipePlans.first?.title == "Recipe")
        #expect(ideaPlans.count == 1)
        #expect(ideaPlans.first?.title == "Idea")
    }

    @Test("Get plans by type excluding archived")
    func testGetPlansByTypeExcludingArchived() async throws {
        let repository = MockProjectPlanRepository()

        let activeRecipe = createTestPlan(title: "Active Recipe", type: .recipe, isArchived: false)
        let archivedRecipe = createTestPlan(title: "Archived Recipe", type: .recipe, isArchived: true)

        _ = try await repository.createProject(activeRecipe)
        _ = try await repository.createProject(archivedRecipe)

        let activePlans = try await repository.getProjects(type: .recipe, includeArchived: false)

        #expect(activePlans.count == 1)
        #expect(activePlans.first?.title == "Active Recipe")
    }

    @Test("Get plans with nil type returns all")
    func testGetPlansNilType() async throws {
        let repository = MockProjectPlanRepository()

        let recipe = createTestPlan(title: "Recipe", type: .recipe)
        let idea = createTestPlan(title: "Idea", type: .idea)

        _ = try await repository.createProject(recipe)
        _ = try await repository.createProject(idea)

        let allPlans = try await repository.getProjects(type: nil, includeArchived: true)

        #expect(allPlans.count == 2)
    }

    @Test("Update plan")
    func testUpdatePlan() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan(title: "Original Title")
        _ = try await repository.createProject(plan)

        let updatedPlan = ProjectModel(
            id: plan.id,
            title: "Updated Title",
            type: plan.type,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: plan.isArchived,
            summary: "Updated summary",
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: plan.images,
            heroImageId: plan.heroImageId,
            glassItems: plan.glassItems,
            referenceUrls: plan.referenceUrls,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        try await repository.updateProject(updatedPlan)

        let fetched = try await repository.getProject(id: plan.id)
        #expect(fetched?.title == "Updated Title")
        #expect(fetched?.summary == "Updated summary")
    }

    @Test("Update non-existent plan throws error")
    func testUpdateNonExistentPlan() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan()

        await #expect(throws: ProjectRepositoryError.planNotFound) {
            try await repository.updateProject(plan)
        }
    }

    @Test("Delete plan successfully")
    func testDeletePlan() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan()
        _ = try await repository.createProject(plan)

        #expect(await repository.getPlanCount() == 1)

        try await repository.deleteProject(id: plan.id)

        #expect(await repository.getPlanCount() == 0)
        let fetched = try await repository.getProject(id: plan.id)
        #expect(fetched == nil)
    }

    @Test("Delete non-existent plan throws error")
    func testDeleteNonExistentPlan() async throws {
        let repository = MockProjectPlanRepository()

        await #expect(throws: ProjectRepositoryError.planNotFound) {
            try await repository.deleteProject(id: UUID())
        }
    }

    @Test("Archive plan")
    func testArchivePlan() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan(isArchived: false)
        _ = try await repository.createProject(plan)

        try await repository.archiveProject(id: plan.id, isArchived: true)

        let fetched = try await repository.getProject(id: plan.id)
        #expect(fetched?.isArchived == true)
    }

    @Test("Unarchive plan using archivePlan")
    func testUnarchivePlanUsingArchive() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan(isArchived: true)
        _ = try await repository.createProject(plan)

        try await repository.archiveProject(id: plan.id, isArchived: false)

        let fetched = try await repository.getProject(id: plan.id)
        #expect(fetched?.isArchived == false)
    }

    @Test("Unarchive plan using convenience method")
    func testUnarchiveProject() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan(isArchived: true)
        _ = try await repository.createProject(plan)

        try await repository.unarchiveProject(id: plan.id)

        let fetched = try await repository.getProject(id: plan.id)
        #expect(fetched?.isArchived == false)
    }

    @Test("Archive non-existent plan throws error")
    func testArchiveNonExistentPlan() async throws {
        let repository = MockProjectPlanRepository()

        await #expect(throws: ProjectRepositoryError.planNotFound) {
            try await repository.archiveProject(id: UUID(), isArchived: true)
        }
    }

    // MARK: - Steps Management Tests

    @Test("Add step to plan")
    func testAddStep() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan()
        _ = try await repository.createProject(plan)

        let step = ProjectStepModel(
            planId: plan.id,
            order: 0,
            title: "Step 1",
            description: "First step",
            estimatedMinutes: 30
        )

        let added = try await repository.addStep(step)

        #expect(added.id == step.id)
        #expect(added.title == "Step 1")
    }

    @Test("Update step")
    func testUpdateStep() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan()
        _ = try await repository.createProject(plan)

        let step = ProjectStepModel(
            planId: plan.id,
            order: 0,
            title: "Original Step",
            estimatedMinutes: 30
        )
        _ = try await repository.addStep(step)

        let updatedStep = ProjectStepModel(
            id: step.id,
            planId: step.planId,
            order: 0,
            title: "Updated Step",
            estimatedMinutes: 45
        )

        try await repository.updateStep(updatedStep)
        // Note: Mock doesn't have a getStep method, so we can't verify directly
    }

    @Test("Update non-existent step throws error")
    func testUpdateNonExistentStep() async throws {
        let repository = MockProjectPlanRepository()

        let step = ProjectStepModel(
            planId: UUID(),
            order: 0,
            title: "Step"
        )

        await #expect(throws: ProjectRepositoryError.stepNotFound) {
            try await repository.updateStep(step)
        }
    }

    @Test("Delete step")
    func testDeleteStep() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan()
        _ = try await repository.createProject(plan)

        let step = ProjectStepModel(
            planId: plan.id,
            order: 0,
            title: "Step to delete"
        )
        _ = try await repository.addStep(step)

        try await repository.deleteStep(id: step.id)
        // Note: Mock doesn't have a getStep method, so we can't verify directly
    }

    @Test("Delete non-existent step throws error")
    func testDeleteNonExistentStep() async throws {
        let repository = MockProjectPlanRepository()

        await #expect(throws: ProjectRepositoryError.stepNotFound) {
            try await repository.deleteStep(id: UUID())
        }
    }

    @Test("Reorder steps")
    func testReorderSteps() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan()
        _ = try await repository.createProject(plan)

        let step1 = ProjectStepModel(planId: plan.id, order: 0, title: "Step 1")
        let step2 = ProjectStepModel(planId: plan.id, order: 1, title: "Step 2")
        let step3 = ProjectStepModel(planId: plan.id, order: 2, title: "Step 3")

        _ = try await repository.addStep(step1)
        _ = try await repository.addStep(step2)
        _ = try await repository.addStep(step3)

        // Reorder: step3, step1, step2
        try await repository.reorderSteps(planId: plan.id, stepIds: [step3.id, step1.id, step2.id])
        // Note: Mock implementation is a no-op, but this tests the interface
    }

    // MARK: - Reference URLs Management Tests

    @Test("Add reference URL")
    func testAddReferenceUrl() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan()
        _ = try await repository.createProject(plan)

        let url = ProjectReferenceUrl(
            url: "https://example.com/tutorial",
            title: "Tutorial",
            description: "Helpful tutorial"
        )

        try await repository.addReferenceUrl(url, to: plan.id)

        let fetched = try await repository.getProject(id: plan.id)
        #expect(fetched?.referenceUrls.count == 1)
        #expect(fetched?.referenceUrls.first?.url == "https://example.com/tutorial")
    }

    @Test("Add reference URL to non-existent plan throws error")
    func testAddReferenceUrlNonExistentPlan() async throws {
        let repository = MockProjectPlanRepository()

        let url = ProjectReferenceUrl(url: "https://example.com")

        await #expect(throws: ProjectRepositoryError.planNotFound) {
            try await repository.addReferenceUrl(url, to: UUID())
        }
    }

    @Test("Update reference URL")
    func testUpdateReferenceUrl() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan()
        _ = try await repository.createProject(plan)

        let url = ProjectReferenceUrl(
            url: "https://example.com/original",
            title: "Original"
        )
        try await repository.addReferenceUrl(url, to: plan.id)

        let updatedUrl = ProjectReferenceUrl(
            id: url.id,
            url: "https://example.com/updated",
            title: "Updated",
            dateAdded: url.dateAdded
        )

        try await repository.updateReferenceUrl(updatedUrl, in: plan.id)

        let fetched = try await repository.getProject(id: plan.id)
        #expect(fetched?.referenceUrls.first?.url == "https://example.com/updated")
        #expect(fetched?.referenceUrls.first?.title == "Updated")
    }

    @Test("Delete reference URL")
    func testDeleteReferenceUrl() async throws {
        let repository = MockProjectPlanRepository()
        let plan = createTestPlan()
        _ = try await repository.createProject(plan)

        let url = ProjectReferenceUrl(url: "https://example.com")
        try await repository.addReferenceUrl(url, to: plan.id)

        try await repository.deleteReferenceUrl(id: url.id, from: plan.id)

        let fetched = try await repository.getProject(id: plan.id)
        #expect(fetched?.referenceUrls.isEmpty == true)
    }

    // MARK: - Complex Scenarios

    @Test("Plan with all fields populated")
    func testPlanWithAllFields() async throws {
        let repository = MockProjectPlanRepository()

        let plan = ProjectModel(
            title: "Complete Plan",
            type: .recipe,
            summary: "A comprehensive test plan",
            estimatedTime: 240.0,
            difficultyLevel: .advanced,
            proposedPriceRange: PriceRange(min: 100.00, max: 250.00, currency: "USD"),
            glassItems: [
                ProjectGlassItem(
                    stableId: "be-clear-000",
                    quantity: 3,
                    unit: "rods",
                    notes: "Main structure"
                )
            ],
            referenceUrls: [
                ProjectReferenceUrl(
                    url: "https://example.com/tutorial",
                    title: "Tutorial Video",
                    description: "Step-by-step guide"
                )
            ]
        )

        _ = try await repository.createProject(plan)
        let fetched = try await repository.getProject(id: plan.id)

        #expect(fetched?.title == "Complete Plan")
        #expect(fetched?.estimatedTime == 240.0)
        #expect(fetched?.difficultyLevel == .advanced)
        #expect(fetched?.proposedPriceRange?.min == 100.00)
        #expect(fetched?.glassItems.count == 1)
        #expect(fetched?.referenceUrls.count == 1)
    }

    @Test("Reset clears all plans")
    func testReset() async throws {
        let repository = MockProjectPlanRepository()

        _ = try await repository.createProject(createTestPlan(title: "Plan 1"))
        _ = try await repository.createProject(createTestPlan(title: "Plan 2"))
        _ = try await repository.createProject(createTestPlan(title: "Plan 3"))

        #expect(await repository.getPlanCount() == 3)

        await repository.reset()

        #expect(await repository.getPlanCount() == 0)
        let allPlans = try await repository.getAllPlans(includeArchived: true)
        #expect(allPlans.isEmpty)
    }
}
#endif
