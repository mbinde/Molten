//
//  ProjectModelTests.swift
//  FlameworkerTests
//
//  Tests for ProjectPlanModel and ProjectLogModel
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("ProjectPlanModel Tests")
struct ProjectPlanModelTests {

    @Test("Initialize with minimal properties")
    func testMinimalInitialization() {
        let plan = ProjectPlanModel(
            title: "Test Plan",
            planType: .recipe
        )

        #expect(plan.title == "Test Plan")
        #expect(plan.planType == .recipe)
        #expect(plan.isArchived == false)
        #expect(plan.tags.isEmpty)
        #expect(plan.steps.isEmpty)
        #expect(plan.glassItems.isEmpty)
        #expect(plan.referenceUrls.isEmpty)
        #expect(plan.timesUsed == 0)
        #expect(plan.lastUsedDate == nil)
    }

    @Test("Initialize with full properties")
    func testFullInitialization() {
        let glassItem = ProjectGlassItem(naturalKey: "clear-0", quantity: 0.5)
        let refUrl = ProjectReferenceUrl(url: "https://example.com")
        let step = ProjectStepModel(planId: UUID(), order: 0, title: "Step 1")
        let priceRange = PriceRange(min: 50, max: 100)

        let plan = ProjectPlanModel(
            title: "Full Plan",
            planType: .recipe,
            isArchived: true,
            tags: ["boro", "beginner"],
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
        #expect(plan.tags.count == 2)
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
        let recipe = ProjectPlanModel(title: "Recipe", planType: .recipe)
        let idea = ProjectPlanModel(title: "Idea", planType: .idea)
        let technique = ProjectPlanModel(title: "Technique", planType: .technique)
        let commission = ProjectPlanModel(title: "Commission", planType: .commission)

        #expect(recipe.planType == .recipe)
        #expect(idea.planType == .idea)
        #expect(technique.planType == .technique)
        #expect(commission.planType == .commission)
    }

    @Test("Difficulty levels are distinct")
    func testDifficultyLevels() {
        let beginner = ProjectPlanModel(title: "Easy", planType: .recipe, difficultyLevel: .beginner)
        let intermediate = ProjectPlanModel(title: "Medium", planType: .recipe, difficultyLevel: .intermediate)
        let advanced = ProjectPlanModel(title: "Hard", planType: .recipe, difficultyLevel: .advanced)
        let expert = ProjectPlanModel(title: "Expert", planType: .recipe, difficultyLevel: .expert)

        #expect(beginner.difficultyLevel == .beginner)
        #expect(intermediate.difficultyLevel == .intermediate)
        #expect(advanced.difficultyLevel == .advanced)
        #expect(expert.difficultyLevel == .expert)
    }

    @Test("Each plan has unique ID")
    func testUniqueIds() {
        let plan1 = ProjectPlanModel(title: "Plan 1", planType: .recipe)
        let plan2 = ProjectPlanModel(title: "Plan 2", planType: .recipe)

        #expect(plan1.id != plan2.id)
    }

    @Test("Archive defaults to false")
    func testArchiveDefault() {
        let plan = ProjectPlanModel(title: "Test", planType: .recipe)
        #expect(plan.isArchived == false)
    }

    @Test("Times used defaults to zero")
    func testTimesUsedDefault() {
        let plan = ProjectPlanModel(title: "Test", planType: .recipe)
        #expect(plan.timesUsed == 0)
    }

    @Test("Can have multiple glass items")
    func testMultipleGlassItems() {
        let glassItems = [
            ProjectGlassItem(naturalKey: "clear-0", quantity: 0.5),
            ProjectGlassItem(naturalKey: "blue-1", quantity: 0.25),
            ProjectGlassItem(naturalKey: "red-2", quantity: 1.0)
        ]

        let plan = ProjectPlanModel(
            title: "Multi-color Plan",
            planType: .recipe,
            glassItems: glassItems
        )

        #expect(plan.glassItems.count == 3)
        #expect(plan.glassItems[0].naturalKey == "clear-0")
        #expect(plan.glassItems[1].quantity == 0.25)
    }

    @Test("Can have multiple reference URLs")
    func testMultipleReferenceUrls() {
        let urls = [
            ProjectReferenceUrl(url: "https://tutorial1.com", title: "Tutorial 1"),
            ProjectReferenceUrl(url: "https://tutorial2.com", title: "Tutorial 2")
        ]

        let plan = ProjectPlanModel(
            title: "Plan with refs",
            planType: .recipe,
            referenceUrls: urls
        )

        #expect(plan.referenceUrls.count == 2)
        #expect(plan.referenceUrls[0].title == "Tutorial 1")
    }

    @Test("Price range is optional")
    func testOptionalPriceRange() {
        let planWithPrice = ProjectPlanModel(
            title: "With Price",
            planType: .recipe,
            proposedPriceRange: PriceRange(min: 50, max: 100)
        )

        let planWithoutPrice = ProjectPlanModel(
            title: "Without Price",
            planType: .recipe
        )

        #expect(planWithPrice.proposedPriceRange != nil)
        #expect(planWithoutPrice.proposedPriceRange == nil)
    }
}

@Suite("ProjectLogModel Tests")
struct ProjectLogModelTests {

    @Test("Initialize with minimal properties")
    func testMinimalInitialization() {
        let log = ProjectLogModel(title: "Test Log")

        #expect(log.title == "Test Log")
        #expect(log.status == .inProgress)
        #expect(log.tags.isEmpty)
        #expect(log.glassItems.isEmpty)
        #expect(log.inventoryDeductionRecorded == false)
        #expect(log.basedOnPlanId == nil)
    }

    @Test("Initialize with full properties")
    func testFullInitialization() {
        let planId = UUID()
        let glassItem = ProjectGlassItem(naturalKey: "clear-0", quantity: 0.5)

        let log = ProjectLogModel(
            title: "Completed Fish",
            basedOnPlanId: planId,
            tags: ["boro", "sold"],
            notes: "Turned out great!",
            techniquesUsed: ["flamework", "fuming"],
            hoursSpent: 2.5,
            glassItems: [glassItem],
            pricePoint: 75.00,
            saleDate: Date(),
            buyerInfo: "John Doe",
            status: .sold,
            inventoryDeductionRecorded: true
        )

        #expect(log.title == "Completed Fish")
        #expect(log.basedOnPlanId == planId)
        #expect(log.tags.count == 2)
        #expect(log.notes == "Turned out great!")
        #expect(log.techniquesUsed?.count == 2)
        #expect(log.hoursSpent == 2.5)
        #expect(log.glassItems.count == 1)
        #expect(log.pricePoint == 75.00)
        #expect(log.buyerInfo == "John Doe")
        #expect(log.status == .sold)
        #expect(log.inventoryDeductionRecorded == true)
    }

    @Test("Project statuses are distinct")
    func testProjectStatuses() {
        let inProgress = ProjectLogModel(title: "In Progress", status: .inProgress)
        let completed = ProjectLogModel(title: "Completed", status: .completed)
        let sold = ProjectLogModel(title: "Sold", status: .sold)
        let gifted = ProjectLogModel(title: "Gifted", status: .gifted)
        let kept = ProjectLogModel(title: "Kept", status: .kept)
        let broken = ProjectLogModel(title: "Broken", status: .broken)

        #expect(inProgress.status == .inProgress)
        #expect(completed.status == .completed)
        #expect(sold.status == .sold)
        #expect(gifted.status == .gifted)
        #expect(kept.status == .kept)
        #expect(broken.status == .broken)
    }

    @Test("Each log has unique ID")
    func testUniqueIds() {
        let log1 = ProjectLogModel(title: "Log 1")
        let log2 = ProjectLogModel(title: "Log 2")

        #expect(log1.id != log2.id)
    }

    @Test("Status defaults to in progress")
    func testStatusDefault() {
        let log = ProjectLogModel(title: "Test")
        #expect(log.status == .inProgress)
    }

    @Test("Inventory deduction defaults to false")
    func testInventoryDeductionDefault() {
        let log = ProjectLogModel(title: "Test")
        #expect(log.inventoryDeductionRecorded == false)
    }

    @Test("Based on plan ID is optional")
    func testOptionalPlanId() {
        let logWithPlan = ProjectLogModel(title: "From Plan", basedOnPlanId: UUID())
        let logWithoutPlan = ProjectLogModel(title: "Manual")

        #expect(logWithPlan.basedOnPlanId != nil)
        #expect(logWithoutPlan.basedOnPlanId == nil)
    }

    @Test("Can track multiple techniques")
    func testMultipleTechniques() {
        let log = ProjectLogModel(
            title: "Complex Piece",
            techniquesUsed: ["flamework", "cold-working", "fuming", "encasing"]
        )

        #expect(log.techniquesUsed?.count == 4)
        #expect(log.techniquesUsed?.contains("fuming") == true)
    }

    @Test("Business fields are optional")
    func testOptionalBusinessFields() {
        let soldLog = ProjectLogModel(
            title: "Sold Piece",
            pricePoint: 100.00,
            saleDate: Date(),
            buyerInfo: "Buyer Name",
            status: .sold
        )

        let keptLog = ProjectLogModel(
            title: "Kept Piece",
            status: .kept
        )

        #expect(soldLog.pricePoint == 100.00)
        #expect(soldLog.saleDate != nil)
        #expect(soldLog.buyerInfo == "Buyer Name")

        #expect(keptLog.pricePoint == nil)
        #expect(keptLog.saleDate == nil)
        #expect(keptLog.buyerInfo == nil)
    }
}

@Suite("ProjectStepModel Tests")
struct ProjectStepModelTests {

    @Test("Initialize with minimal properties")
    func testMinimalInitialization() {
        let planId = UUID()
        let step = ProjectStepModel(
            planId: planId,
            order: 0,
            title: "Gather materials"
        )

        #expect(step.planId == planId)
        #expect(step.order == 0)
        #expect(step.title == "Gather materials")
        #expect(step.description == nil)
        #expect(step.estimatedMinutes == nil)
        #expect(step.glassItemsNeeded == nil)
    }

    @Test("Initialize with full properties")
    func testFullInitialization() {
        let planId = UUID()
        let glassItem = ProjectGlassItem(naturalKey: "clear-0", quantity: 0.5)

        let step = ProjectStepModel(
            planId: planId,
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
        let step1 = ProjectStepModel(planId: planId, order: 0, title: "Step 1")
        let step2 = ProjectStepModel(planId: planId, order: 1, title: "Step 2")

        #expect(step1.id != step2.id)
    }

    @Test("Steps can be ordered")
    func testStepOrdering() {
        let planId = UUID()
        let steps = [
            ProjectStepModel(planId: planId, order: 0, title: "First"),
            ProjectStepModel(planId: planId, order: 1, title: "Second"),
            ProjectStepModel(planId: planId, order: 2, title: "Third")
        ]

        #expect(steps[0].order == 0)
        #expect(steps[1].order == 1)
        #expect(steps[2].order == 2)
    }

    @Test("Glass items needed is optional")
    func testOptionalGlassItems() {
        let planId = UUID()
        let stepWithGlass = ProjectStepModel(
            planId: planId,
            order: 0,
            title: "Add color",
            glassItemsNeeded: [ProjectGlassItem(naturalKey: "blue-1", quantity: 0.25)]
        )

        let stepWithoutGlass = ProjectStepModel(
            planId: planId,
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
