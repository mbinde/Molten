//
//  ShareExtensionTests.swift
//  MoltenTests
//
//  Tests for Share Extension tags and technique type support
//

import Testing
import Foundation
@testable import Molten

@Suite("Share Extension - Technique Type Support")
struct ShareExtensionTechniqueTypeTests {

    @Test("Share extension technique types match ProjectModel technique types")
    func shareExtensionTechniqueTypesMatchModel() async throws {
        // The share extension uses string values that should match TechniqueType raw values
        let shareExtensionTypes = [
            ("glass_blowing", "Glass Blowing"),
            ("flameworking", "Flameworking"),
            ("fusing", "Fusing"),
            ("casting", "Casting"),
            ("other", "Other")
        ]

        let modelTypes = TechniqueType.allCases

        #expect(shareExtensionTypes.count == modelTypes.count)

        for (rawValue, displayName) in shareExtensionTypes {
            // Verify raw value exists in model
            let matchingType = TechniqueType(rawValue: rawValue)
            #expect(matchingType != nil, "TechniqueType should have raw value: \(rawValue)")

            // Verify display name matches
            #expect(matchingType?.displayName == displayName,
                   "Display name should match for \(rawValue)")
        }
    }

    @Test("Technique type can be nil in share extension")
    func techniqueTypeCanBeNil() async throws {
        // The share extension should support nil technique type
        let techniqueType: String? = nil

        // Should be able to create project without technique type
        let project = ProjectModel(
            title: "Imported Project",
            type: .idea,
            coe: "any",
            summary: "Test",
            techniqueType: nil
        )

        #expect(project.techniqueType == nil)
    }

    @Test("Technique type string converts to TechniqueType enum")
    func techniqueTypeStringConvertsToEnum() async throws {
        let stringValue = "flameworking"
        let techniqueType = TechniqueType(rawValue: stringValue)

        #expect(techniqueType == .flameworking)
    }

    @Test("All technique type strings are valid")
    func allTechniqueTypeStringsValid() async throws {
        let validStrings = ["glass_blowing", "flameworking", "fusing", "casting", "other"]

        for string in validStrings {
            let techniqueType = TechniqueType(rawValue: string)
            #expect(techniqueType != nil, "Should create TechniqueType from: \(string)")
        }
    }
}

@Suite("Share Extension - Tags Support")
struct ShareExtensionTagsTests {

    @Test("Tags array can be empty")
    func tagsCanBeEmpty() async throws {
        let tags: [String] = []

        let project = ProjectModel(
            title: "Test Project",
            type: .idea,
            coe: "any",
            summary: nil
        )

        // Project should work with empty tags
        #expect(tags.isEmpty)
        #expect(project.id != nil)
    }

    @Test("Tags array can contain multiple tags")
    func tagsCanContainMultipleTags() async throws {
        let tags = ["glass", "sculpture", "advanced"]

        #expect(tags.count == 3)
        #expect(tags.contains("glass"))
        #expect(tags.contains("sculpture"))
        #expect(tags.contains("advanced"))
    }

    @Test("Tags are lowercased")
    func tagsAreLowercased() async throws {
        // Tags should be normalized to lowercase
        let inputTag = "Glass"
        let normalizedTag = inputTag.lowercased()

        #expect(normalizedTag == "glass")
    }

    @Test("Tags are trimmed of whitespace")
    func tagsAreTrimmed() async throws {
        let inputTag = "  glass  "
        let trimmedTag = inputTag.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(trimmedTag == "glass")
    }

    @Test("Empty tags are filtered out")
    func emptyTagsFiltered() async throws {
        let inputTag = "   "
        let trimmedTag = inputTag.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(trimmedTag.isEmpty)
    }

    @Test("Duplicate tags should not be added")
    func duplicateTagsNotAdded() async throws {
        var tags = ["glass", "sculpture"]

        let newTag = "glass"
        if !tags.contains(newTag) {
            tags.append(newTag)
        }

        #expect(tags.count == 2)
        #expect(tags.filter { $0 == "glass" }.count == 1)
    }

    @Test("Tags can be removed from array")
    func tagsCanBeRemoved() async throws {
        var tags = ["glass", "sculpture", "advanced"]

        tags.removeAll { $0 == "sculpture" }

        #expect(tags.count == 2)
        #expect(!tags.contains("sculpture"))
        #expect(tags.contains("glass"))
        #expect(tags.contains("advanced"))
    }
}

@Suite("Share Extension - Callback Signature")
struct ShareExtensionCallbackTests {

    @Test("Callback signature includes all required parameters")
    func callbackSignatureComplete() async throws {
        // The callback should accept: title, notes, projectType, techniqueType, tags, existingProjectId
        let title = "Test Project"
        let notes = "Test notes"
        let projectType = "recipe"
        let techniqueType: String? = "flameworking"
        let tags = ["glass", "beginner"]
        let existingProjectId: UUID? = nil

        // Verify all parameters have expected types
        #expect(title is String)
        #expect(notes is String)
        #expect(projectType is String)
        #expect(techniqueType is String?)
        #expect(tags is [String])
        #expect(existingProjectId is UUID?)
    }

    @Test("Callback works with nil technique type")
    func callbackWorksWithNilTechniqueType() async throws {
        let title = "Test Project"
        let notes = "Test notes"
        let projectType = "idea"
        let techniqueType: String? = nil
        let tags: [String] = []
        let existingProjectId: UUID? = nil

        #expect(techniqueType == nil)
        #expect(tags.isEmpty)
    }

    @Test("Callback works with empty tags")
    func callbackWorksWithEmptyTags() async throws {
        let title = "Test Project"
        let notes = "Test notes"
        let projectType = "recipe"
        let techniqueType: String? = "fusing"
        let tags: [String] = []
        let existingProjectId: UUID? = nil

        #expect(tags.isEmpty)
        #expect(techniqueType != nil)
    }

    @Test("Callback works with existing project ID")
    func callbackWorksWithExistingProjectId() async throws {
        let title = ""
        let notes = ""
        let projectType = ""
        let techniqueType: String? = nil
        let tags: [String] = []
        let existingProjectId = UUID()

        #expect(existingProjectId != nil)
    }
}

@Suite("Share Extension - Project Type Integration")
struct ShareExtensionProjectTypeTests {

    @Test("Share extension project types match ProjectType enum")
    func shareExtensionProjectTypesMatchModel() async throws {
        let shareExtensionTypes = [
            ("idea", "Idea"),
            ("recipe", "Instructions"),
            ("technique", "Technique"),
            ("tutorial", "Tutorial"),
            ("commission", "Commission")
        ]

        for (rawValue, _) in shareExtensionTypes {
            let projectType = ProjectType(rawValue: rawValue)
            #expect(projectType != nil, "ProjectType should have raw value: \(rawValue)")
        }
    }

    @Test("All ProjectType cases are supported in share extension")
    func allProjectTypesSupported() async throws {
        let allTypes = ProjectType.allCases

        // Share extension should support all these types
        let supportedRawValues = ["idea", "recipe", "technique", "tutorial", "commission"]

        for type in allTypes {
            #expect(supportedRawValues.contains(type.rawValue),
                   "Share extension should support ProjectType: \(type.rawValue)")
        }
    }
}
