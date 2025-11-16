//
//  ProjectRepositoryTechniqueTypeTests.swift
//  RepositoryTests
//
//  Tests for Project repository technique type persistence
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Project Repository - Technique Type Persistence")
@MainActor
struct ProjectRepositoryTechniqueTypeTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store PersistenceController at struct level to keep it alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let controller = PersistenceController.createTestController()

    func createTestRepository() -> CoreDataProjectRepository {
        return CoreDataProjectRepository(context: controller.container.viewContext)
    }

    @Test("Create project with techniqueType saves to Core Data")
    func createProjectWithTechniqueType() async throws {
        let repository = createTestRepository()

        let project = ProjectModel(
            title: "Flameworking Project",
            type: .technique,
            coe: "96",
            techniqueType: TechniqueType.flameworkinghard,
            summary: "Test flameworking technique"
        )

        let created = try await repository.createProject(project)

        // Verify the project was created with techniqueType
        #expect(created.techniqueType == .flameworkinghard)
        #expect(created.title == "Flameworking Project")

        // Verify it persisted by fetching it again
        let fetched = try await repository.getProject(id: created.id)
        #expect(fetched != nil)
        #expect(fetched?.techniqueType == .flameworkinghard)
    }

    @Test("Create project without techniqueType saves as nil")
    func createProjectWithoutTechniqueType() async throws {
        let repository = createTestRepository()

        let project = ProjectModel(
            title: "Project Without Technique",
            type: .idea,
            coe: "any",
            techniqueType: nil,
            summary: nil
        )

        let created = try await repository.createProject(project)

        #expect(created.techniqueType == nil)

        // Verify it persisted
        let fetched = try await repository.getProject(id: created.id)
        #expect(fetched != nil)
        #expect(fetched?.techniqueType == nil)
    }

    @Test("Update project techniqueType")
    func updateProjectTechniqueType() async throws {
        let repository = createTestRepository()

        // Create project with one techniqueType
        let original = ProjectModel(
            title: "Test Project",
            type: .recipe,
            coe: "96",
            techniqueType: TechniqueType.fusing,
            summary: "Original"
        )

        let created = try await repository.createProject(original)
        #expect(created.techniqueType == .fusing)

        // Update to different techniqueType
        let updated = ProjectModel(
            id: created.id,
            title: created.title,
            type: created.type,
            dateCreated: created.dateCreated,
            dateModified: Date(),
            isArchived: created.isArchived,
            coe: created.coe,
            techniqueType: .glassBlowing,  // Changed
            summary: created.summary,
            steps: created.steps,
            estimatedTime: created.estimatedTime,
            difficultyLevel: created.difficultyLevel,
            proposedPriceRange: created.proposedPriceRange,
            images: created.images,
            heroImageId: created.heroImageId,
            glassItems: created.glassItems,
            referenceUrls: created.referenceUrls,
            author: created.author,
            timesUsed: created.timesUsed,
            lastUsedDate: created.lastUsedDate
        )

        try await repository.updateProject(updated)

        // Verify the update persisted
        let fetched = try await repository.getProject(id: created.id)
        #expect(fetched != nil)
        #expect(fetched?.techniqueType == .glassBlowing)
    }

    @Test("Clear project techniqueType")
    func clearProjectTechniqueType() async throws {
        let repository = createTestRepository()

        // Create project with techniqueType
        let original = ProjectModel(
            title: "Test Project",
            type: .recipe,
            coe: "96",
            techniqueType: TechniqueType.casting,
            summary: "Original"
        )

        let created = try await repository.createProject(original)
        #expect(created.techniqueType == .casting)

        // Update to clear techniqueType
        let updated = ProjectModel(
            id: created.id,
            title: created.title,
            type: created.type,
            dateCreated: created.dateCreated,
            dateModified: Date(),
            isArchived: created.isArchived,
            coe: created.coe,
            techniqueType: nil,  // Cleared
            summary: created.summary,
            steps: created.steps,
            estimatedTime: created.estimatedTime,
            difficultyLevel: created.difficultyLevel,
            proposedPriceRange: created.proposedPriceRange,
            images: created.images,
            heroImageId: created.heroImageId,
            glassItems: created.glassItems,
            referenceUrls: created.referenceUrls,
            author: created.author,
            timesUsed: created.timesUsed,
            lastUsedDate: created.lastUsedDate
        )

        try await repository.updateProject(updated)

        // Verify the techniqueType was cleared
        let fetched = try await repository.getProject(id: created.id)
        #expect(fetched != nil)
        #expect(fetched?.techniqueType == nil)
    }

    @Test("All techniqueType values persist correctly")
    func allTechniqueTypesPerist() async throws {
        let repository = createTestRepository()

        let allTypes: [TechniqueType] = [.glassBlowing, .flameworkinghard, .flameworkingsoft, .fusing, .casting, .other]

        for (index, techniqueType) in allTypes.enumerated() {
            let project = ProjectModel(
                title: "Project \(index)",
                type: .technique,
                coe: "96",
                techniqueType: techniqueType,
                summary: "Testing \(techniqueType.displayName)"
            )

            let created = try await repository.createProject(project)
            #expect(created.techniqueType == techniqueType)

            // Verify it persisted
            let fetched = try await repository.getProject(id: created.id)
            #expect(fetched != nil)
            #expect(fetched?.techniqueType == techniqueType)
        }
    }

    @Test("Query projects by techniqueType")
    func queryProjectsByTechniqueType() async throws {
        let repository = createTestRepository()

        // Create projects with different technique types
        let flameworkingProject = ProjectModel(
            title: "Flameworking Project",
            type: .technique,
            coe: "96",
            techniqueType: TechniqueType.flameworkinghard,
            summary: "Flameworking test"
        )

        let fusingProject = ProjectModel(
            title: "Fusing Project",
            type: .technique,
            coe: "96",
            techniqueType: TechniqueType.fusing,
            summary: "Fusing test"
        )

        let noTechniqueProject = ProjectModel(
            title: "No Technique Project",
            type: .idea,
            coe: "any",
            techniqueType: nil,
            summary: "No technique"
        )

        _ = try await repository.createProject(flameworkingProject)
        _ = try await repository.createProject(fusingProject)
        _ = try await repository.createProject(noTechniqueProject)

        // Get all active projects
        let allProjects = try await repository.getActiveProjects()
        #expect(allProjects.count == 3)

        // Count projects by technique type
        let flameworkingCount = allProjects.filter { $0.techniqueType == .flameworkinghard }.count
        let fusingCount = allProjects.filter { $0.techniqueType == .fusing }.count
        let noTechniqueCount = allProjects.filter { $0.techniqueType == nil }.count

        #expect(flameworkingCount == 1)
        #expect(fusingCount == 1)
        #expect(noTechniqueCount == 1)
    }
}
