//
//  ProjectModelTests.swift
//  FlameworkerTests
//
//  Tests for ProjectModel and LogbookModel
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

@Suite("ProjectModel Tests")
struct ProjectModelTests {

    @Test("Initialize with minimal properties")
    func testMinimalInitialization() {
        let plan = ProjectModel(
            title: "Test Plan",
            type: .recipe
        )

        #expect(plan.title == "Test Plan")
        #expect(plan.type == .recipe)
        #expect(plan.isArchived == false)
        #expect(plan.steps.isEmpty)
        #expect(plan.glassItems.isEmpty)
        #expect(plan.referenceUrls.isEmpty)
        #expect(plan.timesUsed == 0)
        #expect(plan.lastUsedDate == nil)
    }

    @Test("Initialize with full properties")
    func testFullInitialization() {
        let glassItem = ProjectGlassItem(stableId: "clear-0", quantity: 0.5)
        let refUrl = ProjectReferenceUrl(url: "https://example.com")
        let step = ProjectStepModel(projectId: UUID(), order: 0, title: "Step 1")
        let priceRange = PriceRange(min: 50, max: 100)

        let plan = ProjectModel(
            title: "Full Plan",
            type: .recipe,
            isArchived: true,
            summary: "A comprehensive plan",
            steps: [step],
            estimatedTime: 7200,
            difficultyLevel: .intermediate,
            proposedPriceRange: priceRange,
            glassItems: [glassItem],
            referenceUrls: [refUrl],
            timesUsed: 5,
            lastUsedDate: Date()
        )

        #expect(plan.title == "Full Plan")
        #expect(plan.isArchived == true)
        #expect(plan.summary == "A comprehensive plan")
        #expect(plan.steps.count == 1)
        #expect(plan.estimatedTime == 7200)
        #expect(plan.difficultyLevel == .intermediate)
        #expect(plan.glassItems.count == 1)
        #expect(plan.referenceUrls.count == 1)
        #expect(plan.timesUsed == 5)
    }

    @Test("Plan types are distinct")
    func testPlanTypes() {
        let recipe = ProjectModel(title: "Recipe", type: .recipe)
        let idea = ProjectModel(title: "Idea", type: .idea)
        let technique = ProjectModel(title: "Technique", type: .technique)
        let commission = ProjectModel(title: "Commission", type: .commission)

        #expect(recipe.type == .recipe)
        #expect(idea.type == .idea)
        #expect(technique.type == .technique)
        #expect(commission.type == .commission)
    }

    @Test("Difficulty levels are distinct")
    func testDifficultyLevels() {
        let beginner = ProjectModel(title: "Easy", type: .recipe, difficultyLevel: .beginner)
        let intermediate = ProjectModel(title: "Medium", type: .recipe, difficultyLevel: .intermediate)
        let advanced = ProjectModel(title: "Hard", type: .recipe, difficultyLevel: .advanced)
        let expert = ProjectModel(title: "Expert", type: .recipe, difficultyLevel: .expert)

        #expect(beginner.difficultyLevel == .beginner)
        #expect(intermediate.difficultyLevel == .intermediate)
        #expect(advanced.difficultyLevel == .advanced)
        #expect(expert.difficultyLevel == .expert)
    }

    @Test("Each plan has unique ID")
    func testUniqueIds() {
        let plan1 = ProjectModel(title: "Plan 1", type: .recipe)
        let plan2 = ProjectModel(title: "Plan 2", type: .recipe)

        #expect(plan1.id != plan2.id)
    }

    @Test("Archive defaults to false")
    func testArchiveDefault() {
        let plan = ProjectModel(title: "Test", type: .recipe)
        #expect(plan.isArchived == false)
    }

    @Test("Times used defaults to zero")
    func testTimesUsedDefault() {
        let plan = ProjectModel(title: "Test", type: .recipe)
        #expect(plan.timesUsed == 0)
    }

    @Test("Can have multiple glass items")
    func testMultipleGlassItems() {
        let glassItems = [
            ProjectGlassItem(stableId: "clear-0", quantity: 0.5),
            ProjectGlassItem(stableId: "blue-1", quantity: 0.25),
            ProjectGlassItem(stableId: "red-2", quantity: 1.0)
        ]

        let plan = ProjectModel(
            title: "Multi-color Plan",
            type: .recipe,
            glassItems: glassItems
        )

        #expect(plan.glassItems.count == 3)
        #expect(plan.glassItems[0].stableId == "clear-0")
        #expect(plan.glassItems[1].quantity == 0.25)
    }

    @Test("Can have multiple reference URLs")
    func testMultipleReferenceUrls() {
        let urls = [
            ProjectReferenceUrl(url: "https://tutorial1.com", title: "Tutorial 1"),
            ProjectReferenceUrl(url: "https://tutorial2.com", title: "Tutorial 2")
        ]

        let plan = ProjectModel(
            title: "Plan with refs",
            type: .recipe,
            referenceUrls: urls
        )

        #expect(plan.referenceUrls.count == 2)
        #expect(plan.referenceUrls[0].title == "Tutorial 1")
    }

    @Test("Price range is optional")
    func testOptionalPriceRange() {
        let planWithPrice = ProjectModel(
            title: "With Price",
            type: .recipe,
            proposedPriceRange: PriceRange(min: 50, max: 100)
        )

        let planWithoutPrice = ProjectModel(
            title: "Without Price",
            type: .recipe
        )

        #expect(planWithPrice.proposedPriceRange != nil)
        #expect(planWithoutPrice.proposedPriceRange == nil)
    }
}

@Suite("ProjectStepModel Tests")
struct ProjectStepModelTests {

    @Test("Initialize with minimal properties")
    func testMinimalInitialization() {
        let planId = UUID()
        let step = ProjectStepModel(
            projectId: planId,
            order: 0,
            title: "Gather materials"
        )

        #expect(step.projectId == planId)
        #expect(step.order == 0)
        #expect(step.title == "Gather materials")
        #expect(step.description == nil)
        #expect(step.estimatedMinutes == nil)
        #expect(step.glassItemsNeeded == nil)
    }

    @Test("Initialize with full properties")
    func testFullInitialization() {
        let planId = UUID()
        let glassItem = ProjectGlassItem(stableId: "clear-0", quantity: 0.5)

        let step = ProjectStepModel(
            projectId: planId,
            order: 1,
            title: "Shape the body",
            description: "Use clear glass to form the main body",
            estimatedMinutes: 20,
            glassItemsNeeded: [glassItem]
        )

        #expect(step.order == 1)
        #expect(step.title == "Shape the body")
        #expect(step.description == "Use clear glass to form the main body")
        #expect(step.estimatedMinutes == 20)
        #expect(step.glassItemsNeeded?.count == 1)
    }

    @Test("Each step has unique ID")
    func testUniqueIds() {
        let planId = UUID()
        let step1 = ProjectStepModel(projectId: planId, order: 0, title: "Step 1")
        let step2 = ProjectStepModel(projectId: planId, order: 1, title: "Step 2")

        #expect(step1.id != step2.id)
    }

    @Test("Steps can be ordered")
    func testStepOrdering() {
        let planId = UUID()
        let steps = [
            ProjectStepModel(projectId: planId, order: 0, title: "First"),
            ProjectStepModel(projectId: planId, order: 1, title: "Second"),
            ProjectStepModel(projectId: planId, order: 2, title: "Third")
        ]

        #expect(steps[0].order == 0)
        #expect(steps[1].order == 1)
        #expect(steps[2].order == 2)
    }

    @Test("Glass items needed is optional")
    func testOptionalGlassItems() {
        let planId = UUID()
        let stepWithGlass = ProjectStepModel(
            projectId: planId,
            order: 0,
            title: "Add color",
            glassItemsNeeded: [ProjectGlassItem(stableId: "blue-1", quantity: 0.25)]
        )

        let stepWithoutGlass = ProjectStepModel(
            projectId: planId,
            order: 1,
            title: "Polish"
        )

        #expect(stepWithGlass.glassItemsNeeded != nil)
        #expect(stepWithoutGlass.glassItemsNeeded == nil)
    }
}

@Suite("PriceRange Tests")
struct PriceRangeTests {

    @Test("Initialize with min and max")
    func testInitialization() {
        let range = PriceRange(min: 50, max: 100, currency: "USD")

        #expect(range.min == 50)
        #expect(range.max == 100)
        #expect(range.currency == "USD")
    }

    @Test("Initialize with defaults")
    func testDefaultInitialization() {
        let range = PriceRange()

        #expect(range.min == nil)
        #expect(range.max == nil)
        #expect(range.currency == "USD")
    }

    @Test("Codable encode and decode")
    func testCodable() throws {
        let original = PriceRange(min: 50, max: 100)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PriceRange.self, from: data)

        #expect(decoded.min == 50)
        #expect(decoded.max == 100)
        #expect(decoded.currency == "USD")
    }

    @Test("Min and max are optional")
    func testOptionalFields() {
        let onlyMin = PriceRange(min: 50)
        let onlyMax = PriceRange(max: 100)
        let neither = PriceRange()

        #expect(onlyMin.min == 50)
        #expect(onlyMin.max == nil)

        #expect(onlyMax.min == nil)
        #expect(onlyMax.max == 100)

        #expect(neither.min == nil)
        #expect(neither.max == nil)
    }
}
