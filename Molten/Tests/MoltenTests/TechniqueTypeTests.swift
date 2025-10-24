//
//  TechniqueTypeTests.swift
//  MoltenTests
//
//  Tests for techniqueType field in Project and Logbook models
//

import Foundation
import Testing
@testable import Molten

@Suite("Technique Type Tests")
@MainActor
struct TechniqueTypeTests {

    // MARK: - Enum Tests

    @Test("TechniqueType enum has all expected cases")
    func testTechniqueTypeCases() {
        let allCases = TechniqueType.allCases

        #expect(allCases.count == 5)
        #expect(allCases.contains(.glassBlowing))
        #expect(allCases.contains(.flameworking))
        #expect(allCases.contains(.fusing))
        #expect(allCases.contains(.casting))
        #expect(allCases.contains(.other))
    }

    @Test("TechniqueType display names are correct")
    func testTechniqueTypeDisplayNames() {
        #expect(TechniqueType.glassBlowing.displayName == "Glass Blowing")
        #expect(TechniqueType.flameworking.displayName == "Flameworking")
        #expect(TechniqueType.fusing.displayName == "Fusing")
        #expect(TechniqueType.casting.displayName == "Casting")
        #expect(TechniqueType.other.displayName == "Other")
    }

    @Test("TechniqueType raw values are correct")
    func testTechniqueTypeRawValues() {
        #expect(TechniqueType.glassBlowing.rawValue == "glass_blowing")
        #expect(TechniqueType.flameworking.rawValue == "flameworking")
        #expect(TechniqueType.fusing.rawValue == "fusing")
        #expect(TechniqueType.casting.rawValue == "casting")
        #expect(TechniqueType.other.rawValue == "other")
    }

    @Test("TechniqueType can be initialized from raw value")
    func testTechniqueTypeFromRawValue() {
        #expect(TechniqueType(rawValue: "glass_blowing") == .glassBlowing)
        #expect(TechniqueType(rawValue: "flameworking") == .flameworking)
        #expect(TechniqueType(rawValue: "fusing") == .fusing)
        #expect(TechniqueType(rawValue: "casting") == .casting)
        #expect(TechniqueType(rawValue: "other") == .other)
        #expect(TechniqueType(rawValue: "invalid") == nil)
    }

    // MARK: - ProjectModel Tests

    @Test("ProjectModel can be created with techniqueType")
    func testProjectModelWithTechniqueType() {
        let project = ProjectModel(
            title: "Test Project",
            type: .recipe,
            techniqueType: .flameworking
        )

        #expect(project.techniqueType == .flameworking)
    }

    @Test("ProjectModel techniqueType is optional")
    func testProjectModelWithoutTechniqueType() {
        let project = ProjectModel(
            title: "Test Project",
            type: .recipe
        )

        #expect(project.techniqueType == nil)
    }

    @Test("ProjectModel with all technique types")
    func testProjectModelWithAllTechniqueTypes() {
        for techniqueType in TechniqueType.allCases {
            let project = ProjectModel(
                title: "Test \(techniqueType.displayName)",
                type: .recipe,
                techniqueType: techniqueType
            )

            #expect(project.techniqueType == techniqueType)
        }
    }

    // MARK: - LogbookModel Tests

    @Test("LogbookModel can be created with techniqueType")
    func testLogbookModelWithTechniqueType() {
        let logbook = LogbookModel(
            title: "Test Logbook",
            techniqueType: .fusing
        )

        #expect(logbook.techniqueType == .fusing)
    }

    @Test("LogbookModel techniqueType is optional")
    func testLogbookModelWithoutTechniqueType() {
        let logbook = LogbookModel(
            title: "Test Logbook"
        )

        #expect(logbook.techniqueType == nil)
    }

    @Test("LogbookModel with all technique types")
    func testLogbookModelWithAllTechniqueTypes() {
        for techniqueType in TechniqueType.allCases {
            let logbook = LogbookModel(
                title: "Test \(techniqueType.displayName)",
                techniqueType: techniqueType
            )

            #expect(logbook.techniqueType == techniqueType)
        }
    }

    // MARK: - Repository Tests (Project)

    @Test("Project repository can save and load techniqueType")
    func testProjectRepositoryWithTechniqueType() async throws {
        // Configure for testing
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createProjectRepository()

        // Create project with techniqueType
        let project = ProjectModel(
            title: "Glass Blowing Project",
            type: .recipe,
            techniqueType: .glassBlowing
        )

        // Save project
        _ = try await repository.createProject(project)

        // Load project back
        let loadedProject = try await repository.getProject(id: project.id)

        #expect(loadedProject != nil)
        #expect(loadedProject?.techniqueType == .glassBlowing)
    }

    @Test("Project repository preserves nil techniqueType")
    func testProjectRepositoryWithNilTechniqueType() async throws {
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createProjectRepository()

        let project = ProjectModel(
            title: "Project Without Technique",
            type: .recipe,
            techniqueType: nil
        )

        _ = try await repository.createProject(project)
        let loadedProject = try await repository.getProject(id: project.id)

        #expect(loadedProject != nil)
        #expect(loadedProject?.techniqueType == nil)
    }

    @Test("Project repository can update techniqueType")
    func testProjectRepositoryUpdateTechniqueType() async throws {
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createProjectRepository()

        // Create project without techniqueType
        var project = ProjectModel(
            title: "Project To Update",
            type: .recipe,
            techniqueType: nil
        )

        _ = try await repository.createProject(project)

        // Update with techniqueType
        project = ProjectModel(
            id: project.id,
            title: project.title,
            type: project.type,
            dateCreated: project.dateCreated,
            techniqueType: .casting
        )

        try await repository.updateProject(project)

        let loadedProject = try await repository.getProject(id: project.id)
        #expect(loadedProject?.techniqueType == .casting)
    }

    // MARK: - Repository Tests (Logbook)

    @Test("Logbook repository can save and load techniqueType")
    func testLogbookRepositoryWithTechniqueType() async throws {
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createLogbookRepository()

        let logbook = LogbookModel(
            title: "Fusing Session",
            techniqueType: .fusing
        )

        _ = try await repository.createLog(logbook)
        let loadedLogbook = try await repository.getLog(id: logbook.id)

        #expect(loadedLogbook != nil)
        #expect(loadedLogbook?.techniqueType == .fusing)
    }

    @Test("Logbook repository preserves nil techniqueType")
    func testLogbookRepositoryWithNilTechniqueType() async throws {
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createLogbookRepository()

        let logbook = LogbookModel(
            title: "Logbook Without Technique",
            techniqueType: nil
        )

        _ = try await repository.createLog(logbook)
        let loadedLogbook = try await repository.getLog(id: logbook.id)

        #expect(loadedLogbook != nil)
        #expect(loadedLogbook?.techniqueType == nil)
    }

    @Test("Logbook repository can update techniqueType")
    func testLogbookRepositoryUpdateTechniqueType() async throws {
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createLogbookRepository()

        // Create logbook without techniqueType
        var logbook = LogbookModel(
            title: "Logbook To Update",
            techniqueType: nil
        )

        _ = try await repository.createLog(logbook)

        // Update with techniqueType
        logbook = LogbookModel(
            id: logbook.id,
            title: logbook.title,
            dateCreated: logbook.dateCreated,
            dateModified: Date(),
            techniqueType: .flameworking
        )

        try await repository.updateLog(logbook)

        let loadedLogbook = try await repository.getLog(id: logbook.id)
        #expect(loadedLogbook?.techniqueType == .flameworking)
    }

    // MARK: - Codable Tests

    @Test("TechniqueType is Codable")
    func testTechniqueTypeCodable() throws {
        for techniqueType in TechniqueType.allCases {
            let encoded = try JSONEncoder().encode(techniqueType)
            let decoded = try JSONDecoder().decode(TechniqueType.self, from: encoded)

            #expect(decoded == techniqueType)
        }
    }

    @Test("ProjectModel with techniqueType is Codable")
    func testProjectModelCodable() throws {
        let project = ProjectModel(
            title: "Codable Project",
            type: .recipe,
            techniqueType: .glassBlowing
        )

        let encoded = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(ProjectModel.self, from: encoded)

        #expect(decoded.techniqueType == .glassBlowing)
    }

    @Test("LogbookModel with techniqueType is Codable")
    func testLogbookModelCodable() throws {
        let logbook = LogbookModel(
            title: "Codable Logbook",
            techniqueType: .casting
        )

        let encoded = try JSONEncoder().encode(logbook)
        let decoded = try JSONDecoder().decode(LogbookModel.self, from: encoded)

        #expect(decoded.techniqueType == .casting)
    }
}
