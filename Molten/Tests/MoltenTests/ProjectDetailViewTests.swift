//
//  ProjectDetailViewTests.swift
//  MoltenTests
//
//  Tests for ProjectDetailView field reorganization and technique type support
//

import Testing
import Foundation
@testable import Molten

@Suite("Project Detail View - Technique Type Support")
@MainActor
struct ProjectDetailViewTechniqueTypeTests {

    @Test("ProjectModel includes techniqueType field")
    func projectModelIncludesTechniqueType() async throws {
        // Test that ProjectModel can be created with a techniqueType
        let project = ProjectModel(
            title: "Test Project",
            type: .recipe,
            coe: "96",
            techniqueType: TechniqueType.flameworkinghard,
            summary: "Test summary"
        )

        #expect(project.techniqueType == TechniqueType.flameworkinghard)
    }

    @Test("ProjectModel supports nil techniqueType")
    func projectModelSupportsNilTechniqueType() async throws {
        // Test that ProjectModel can be created without a techniqueType
        let project = ProjectModel(
            title: "Test Project",
            type: .recipe,
            coe: "96",
            techniqueType: nil,
            summary: "Test summary"
        )

        #expect(project.techniqueType == nil)
    }

    @Test("TechniqueType enum has all expected cases")
    func techniqueTypeEnumCases() async throws {
        let allCases = TechniqueType.allCases

        #expect(allCases.count == 5)
        #expect(allCases.contains(TechniqueType.glassBlowing))
        #expect(allCases.contains(TechniqueType.flameworkinghard))
        #expect(allCases.contains(TechniqueType.fusing))
        #expect(allCases.contains(TechniqueType.casting))
        #expect(allCases.contains(TechniqueType.other))
    }

    @Test("TechniqueType has correct display names")
    func techniqueTypeDisplayNames() async throws {
        #expect(TechniqueType.glassBlowing.displayName == "Glass Blowing")
        #expect(TechniqueType.flameworkinghard.displayName == "Flameworking - Hard")
        #expect(TechniqueType.fusing.displayName == "Fusing")
        #expect(TechniqueType.casting.displayName == "Casting")
        #expect(TechniqueType.other.displayName == "Other")
    }

    @Test("TechniqueType has correct raw values")
    func techniqueTypeRawValues() async throws {
        #expect(TechniqueType.glassBlowing.rawValue == "glass_blowing")
        #expect(TechniqueType.flameworkinghard.rawValue == "flameworkinghard")
        #expect(TechniqueType.fusing.rawValue == "fusing")
        #expect(TechniqueType.casting.rawValue == "casting")
        #expect(TechniqueType.other.rawValue == "other")
    }

    @Test("ProjectModel preserves techniqueType when creating updated version")
    func projectModelPreservesTechniqueType() async throws {
        let original = ProjectModel(
            title: "Original Project",
            type: .recipe,
            coe: "96",
            techniqueType: TechniqueType.fusing,
            summary: "Original summary"
        )

        // Create an updated version with different title but same techniqueType
        let updated = ProjectModel(
            id: original.id,
            title: "Updated Project",
            type: original.type,
            dateCreated: original.dateCreated,
            dateModified: Date(),
            isArchived: original.isArchived,
            coe: original.coe,
            techniqueType: original.techniqueType,
            summary: original.summary,
            steps: original.steps,
            estimatedTime: original.estimatedTime,
            difficultyLevel: original.difficultyLevel,
            proposedPriceRange: original.proposedPriceRange,
            images: original.images,
            heroImageId: original.heroImageId,
            glassItems: original.glassItems,
            referenceUrls: original.referenceUrls,
            author: original.author,
            timesUsed: original.timesUsed,
            lastUsedDate: original.lastUsedDate
        )

        #expect(updated.techniqueType == TechniqueType.fusing)
        #expect(updated.title == "Updated Project")
    }

    @Test("ProjectModel can update techniqueType")
    func projectModelCanUpdateTechniqueType() async throws {
        let original = ProjectModel(
            title: "Test Project",
            type: .recipe,
            coe: "96",
            techniqueType: TechniqueType.flameworkinghard,
            summary: "Test summary"
        )

        // Create an updated version with different techniqueType
        let updated = ProjectModel(
            id: original.id,
            title: original.title,
            type: original.type,
            dateCreated: original.dateCreated,
            dateModified: Date(),
            isArchived: original.isArchived,
            coe: original.coe,
            techniqueType: TechniqueType.glassBlowing,  // Changed
            summary: original.summary,
            steps: original.steps,
            estimatedTime: original.estimatedTime,
            difficultyLevel: original.difficultyLevel,
            proposedPriceRange: original.proposedPriceRange,
            images: original.images,
            heroImageId: original.heroImageId,
            glassItems: original.glassItems,
            referenceUrls: original.referenceUrls,
            author: original.author,
            timesUsed: original.timesUsed,
            lastUsedDate: original.lastUsedDate
        )

        #expect(updated.techniqueType == TechniqueType.glassBlowing)
        #expect(original.techniqueType == TechniqueType.flameworkinghard)
    }

    @Test("ProjectModel can clear techniqueType")
    func projectModelCanClearTechniqueType() async throws {
        let original = ProjectModel(
            title: "Test Project",
            type: .recipe,
            coe: "96",
            techniqueType: TechniqueType.fusing,
            summary: "Test summary"
        )

        // Create an updated version with techniqueType set to nil
        let updated = ProjectModel(
            id: original.id,
            title: original.title,
            type: original.type,
            dateCreated: original.dateCreated,
            dateModified: Date(),
            isArchived: original.isArchived,
            coe: original.coe,
            techniqueType: nil,  // Cleared
            summary: original.summary,
            steps: original.steps,
            estimatedTime: original.estimatedTime,
            difficultyLevel: original.difficultyLevel,
            proposedPriceRange: original.proposedPriceRange,
            images: original.images,
            heroImageId: original.heroImageId,
            glassItems: original.glassItems,
            referenceUrls: original.referenceUrls,
            author: original.author,
            timesUsed: original.timesUsed,
            lastUsedDate: original.lastUsedDate
        )

        #expect(updated.techniqueType == nil)
        #expect(original.techniqueType == TechniqueType.fusing)
    }
}

@Suite("Project Detail View - Field Reorganization")
@MainActor
struct ProjectDetailViewFieldReorganizationTests {

    @Test("Project has all required fields for reorganized view")
    func projectHasRequiredFields() async throws {
        let project = ProjectModel(
            title: "Test Project",
            type: .recipe,
            coe: "96",
            techniqueType: TechniqueType.flameworkinghard,
            summary: "Test summary",
            difficultyLevel: DifficultyLevel.intermediate,
            proposedPriceRange: PriceRange(min: 50, max: 100, currency: "USD")
        )

        // Main details section fields
        #expect(project.title == "Test Project")
        #expect(project.type == .recipe)
        #expect(project.techniqueType == TechniqueType.flameworkinghard)
        #expect(project.summary == "Test summary")

        // Optional fields section
        #expect(project.coe == "96")
        #expect(project.difficultyLevel == DifficultyLevel.intermediate)
        #expect(project.proposedPriceRange != nil)
        #expect(project.proposedPriceRange?.min == 50)
        #expect(project.proposedPriceRange?.max == 100)
    }

    @Test("COE is optional and can be 'any'")
    func coeCanBeAny() async throws {
        let project = ProjectModel(
            title: "Test Project",
            type: .recipe,
            coe: "any",
            summary: nil
        )

        #expect(project.coe == "any")
    }

    @Test("COE supports standard values")
    func coeSupportsStandardValues() async throws {
        let coeValues = ["any", "33", "90", "96", "104"]

        for coe in coeValues {
            let project = ProjectModel(
                title: "Test Project",
                type: .recipe,
                coe: coe,
                summary: nil
            )

            #expect(project.coe == coe)
        }
    }
}
