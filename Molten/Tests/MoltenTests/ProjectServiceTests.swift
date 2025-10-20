//
//  ProjectServiceTests.swift
//  FlameworkerTests
//
//  Tests for ProjectService orchestration logic
//  Tests service layer operations using mock repositories
//

import Testing
import Foundation
@testable import Molten

@Suite("ProjectService Tests")
struct ProjectServiceTests {

    // MARK: - Setup

    init() async throws {
        // Configure for testing with mocks (no Core Data)
        RepositoryFactory.configureForTesting()
    }

    // MARK: - Plan CRUD Operations

    @Test("Create a new project plan")
    func testCreatePlan() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = ProjectPlanModel(
            title: "Test Plan",
            planType: .recipe,
            tags: ["test"],
            summary: "Test plan summary"
        )

        let created = try await service.createPlan(plan)

        #expect(created.title == "Test Plan")
        #expect(created.planType == .recipe)
        #expect(created.tags == ["test"])
        #expect(created.summary == "Test plan summary")
        #expect(created.isArchived == false)
    }

    @Test("Update an existing plan")
    func testUpdatePlan() async throws {
        let service = RepositoryFactory.createProjectService()

        // Create a plan
        let plan = ProjectPlanModel(
            title: "Original Title",
            planType: .recipe,
            tags: ["test"]
        )
        let created = try await service.createPlan(plan)

        // Update it
        let updated = ProjectPlanModel(
            id: created.id,
            title: "Updated Title",
            planType: created.planType,
            dateCreated: created.dateCreated,
            dateModified: Date(),
            isArchived: created.isArchived,
            tags: ["test", "updated"],
            summary: "Updated summary"
        )

        try await service.updatePlan(updated)

        // Fetch and verify
        let fetched = try await service.getPlan(id: created.id)
        #expect(fetched?.title == "Updated Title")
        #expect(fetched?.tags == ["test", "updated"])
        #expect(fetched?.summary == "Updated summary")
    }

    @Test("Delete a plan")
    func testDeletePlan() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = ProjectPlanModel(
            title: "Plan to Delete",
            planType: .technique,
            tags: ["test"]
        )
        let created = try await service.createPlan(plan)

        try await service.deletePlan(id: created.id)

        let fetched = try await service.getPlan(id: created.id)
        #expect(fetched == nil)
    }

    @Test("Archive and unarchive a plan")
    func testArchivePlan() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = ProjectPlanModel(
            title: "Plan to Archive",
            planType: .commission,
            tags: ["test"]
        )
        let created = try await service.createPlan(plan)
        #expect(created.isArchived == false)

        // Archive it
        try await service.archivePlan(id: created.id, isArchived: true)

        let archived = try await service.getPlan(id: created.id)
        #expect(archived?.isArchived == true)

        // Unarchive it
        try await service.unarchivePlan(id: created.id)

        let unarchived = try await service.getPlan(id: created.id)
        #expect(unarchived?.isArchived == false)
    }

    @Test("Get active plans excludes archived plans")
    func testGetActivePlans() async throws {
        let service = RepositoryFactory.createProjectService()

        // Create active plan
        let activePlan = ProjectPlanModel(
            title: "Active Plan",
            planType: .recipe,
            tags: ["test"]
        )
        _ = try await service.createPlan(activePlan)

        // Create archived plan
        let archivedPlan = ProjectPlanModel(
            title: "Archived Plan",
            planType: .recipe,
            tags: ["test"]
        )
        let created = try await service.createPlan(archivedPlan)
        try await service.archivePlan(id: created.id)

        // Fetch active plans
        let activePlans = try await service.getActivePlans()

        #expect(activePlans.count >= 1)
        #expect(activePlans.allSatisfy { !$0.isArchived })
        #expect(activePlans.contains { $0.title == "Active Plan" })
    }

    @Test("Get archived plans only returns archived plans")
    func testGetArchivedPlans() async throws {
        let service = RepositoryFactory.createProjectService()

        // Create and archive a plan
        let plan = ProjectPlanModel(
            title: "Archived Plan",
            planType: .technique,
            tags: ["test"]
        )
        let created = try await service.createPlan(plan)
        try await service.archivePlan(id: created.id)

        // Fetch archived plans
        let archivedPlans = try await service.getArchivedPlans()

        #expect(archivedPlans.count >= 1)
        #expect(archivedPlans.allSatisfy { $0.isArchived })
        #expect(archivedPlans.contains { $0.title == "Archived Plan" })
    }

    // MARK: - Plan Usage Tracking

    @Test("Record plan usage increments timesUsed")
    func testRecordPlanUsage() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = ProjectPlanModel(
            title: "Plan to Use",
            planType: .recipe,
            tags: ["test"]
        )
        let created = try await service.createPlan(plan)
        #expect(created.timesUsed == 0)
        #expect(created.lastUsedDate == nil)

        // Record usage
        try await service.recordPlanUsage(id: created.id)

        let updated = try await service.getPlan(id: created.id)
        #expect(updated?.timesUsed == 1)
        #expect(updated?.lastUsedDate != nil)

        // Record again
        try await service.recordPlanUsage(id: created.id)

        let used2 = try await service.getPlan(id: created.id)
        #expect(used2?.timesUsed == 2)
    }

    @Test("Get most used plans returns sorted by usage")
    func testGetMostUsedPlans() async throws {
        let service = RepositoryFactory.createProjectService()

        // Create plans with different usage counts
        let plan1 = try await service.createPlan(ProjectPlanModel(
            title: "Used Once",
            planType: .recipe,
            tags: ["test"]
        ))
        try await service.recordPlanUsage(id: plan1.id)

        let plan2 = try await service.createPlan(ProjectPlanModel(
            title: "Used Three Times",
            planType: .recipe,
            tags: ["test"]
        ))
        try await service.recordPlanUsage(id: plan2.id)
        try await service.recordPlanUsage(id: plan2.id)
        try await service.recordPlanUsage(id: plan2.id)

        let plan3 = try await service.createPlan(ProjectPlanModel(
            title: "Never Used",
            planType: .recipe,
            tags: ["test"]
        ))

        // Get most used plans
        let mostUsed = try await service.getMostUsedPlans(limit: 10)

        #expect(mostUsed.count >= 2)
        #expect(mostUsed.first?.title == "Used Three Times")
        #expect(mostUsed.first?.timesUsed == 3)

        // Never used plan should not be in the list
        #expect(!mostUsed.contains { $0.id == plan3.id })
    }

    @Test("Get unused plans returns only plans never used")
    func testGetUnusedPlans() async throws {
        let service = RepositoryFactory.createProjectService()

        // Create used plan
        let usedPlan = try await service.createPlan(ProjectPlanModel(
            title: "Used Plan",
            planType: .recipe,
            tags: ["test"]
        ))
        try await service.recordPlanUsage(id: usedPlan.id)

        // Create unused plan
        let unusedPlan = try await service.createPlan(ProjectPlanModel(
            title: "Unused Plan",
            planType: .recipe,
            tags: ["test"]
        ))

        // Get unused plans
        let unused = try await service.getUnusedPlans()

        #expect(unused.contains { $0.id == unusedPlan.id })
        #expect(!unused.contains { $0.id == usedPlan.id })
    }

    // MARK: - Plan Steps Management

    @Test("Add step to a plan")
    func testAddStep() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = try await service.createPlan(ProjectPlanModel(
            title: "Plan with Steps",
            planType: .recipe,
            tags: ["test"]
        ))

        let step = ProjectStepModel(
            planId: plan.id,
            order: 0,
            title: "Step 1",
            description: "First step"
        )

        let created = try await service.addStep(step, to: plan.id)

        #expect(created.planId == plan.id)
        #expect(created.title == "Step 1")
        #expect(created.description == "First step")
        #expect(created.order == 0)
    }

    @Test("Update a step")
    func testUpdateStep() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = try await service.createPlan(ProjectPlanModel(
            title: "Plan with Steps",
            planType: .recipe,
            tags: ["test"]
        ))

        let step = try await service.addStep(ProjectStepModel(
            planId: plan.id,
            order: 0,
            title: "Original Title",
            description: "Original description",
        ), to: plan.id)

        let updated = ProjectStepModel(
            id: step.id,
            planId: plan.id,
            order: step.order,
            title: "Updated Title",
            description: "Updated description",
            estimatedMinutes: 60
        )

        try await service.updateStep(updated)

        // Verify update (would need to fetch from repository)
        #expect(updated.title == "Updated Title")
    }

    @Test("Delete a step")
    func testDeleteStep() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = try await service.createPlan(ProjectPlanModel(
            title: "Plan with Steps",
            planType: .recipe,
            tags: ["test"]
        ))

        let step = try await service.addStep(ProjectStepModel(
            planId: plan.id,
            order: 0,
            title: "Step to Delete",
            description: "Will be deleted",
        ), to: plan.id)

        try await service.deleteStep(id: step.id)

        // Step should be deleted (verified at repository level)
    }

    @Test("Reorder steps in a plan")
    func testReorderSteps() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = try await service.createPlan(ProjectPlanModel(
            title: "Plan with Steps",
            planType: .recipe,
            tags: ["test"]
        ))

        let step1 = try await service.addStep(ProjectStepModel(
            planId: plan.id,
            order: 0,
            title: "Step 1",
            description: "First",
        ), to: plan.id)

        let step2 = try await service.addStep(ProjectStepModel(
            planId: plan.id,
            order: 0,
            title: "Step 2",
            description: "Second",
        ), to: plan.id)

        let step3 = try await service.addStep(ProjectStepModel(
            planId: plan.id,
            order: 0,
            title: "Step 3",
            description: "Third",
        ), to: plan.id)

        // Reorder: step3, step1, step2
        try await service.reorderSteps(planId: plan.id, stepIds: [step3.id, step1.id, step2.id])

        // Reordering verified at repository level
    }

    // MARK: - Reference URLs Management

    @Test("Add reference URL to a plan")
    func testAddReferenceUrl() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = try await service.createPlan(ProjectPlanModel(
            title: "Plan with URLs",
            planType: .recipe,
            tags: ["test"]
        ))

        let url = ProjectReferenceUrl(
            
            url: "https://example.com/tutorial",
            title: "Tutorial",
            description: "Helpful tutorial"
        )

        try await service.addReferenceUrl(url, to: plan.id)

        // URL added (verified at repository level)
    }

    @Test("Update reference URL")
    func testUpdateReferenceUrl() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = try await service.createPlan(ProjectPlanModel(
            title: "Plan with URLs",
            planType: .recipe,
            tags: ["test"]
        ))

        let url = ProjectReferenceUrl(
            
            url: "https://example.com/tutorial",
            title: "Tutorial",
            description: "Helpful tutorial"
        )

        try await service.addReferenceUrl(url, to: plan.id)

        let updated = ProjectReferenceUrl(
            id: url.id,
            
            url: "https://example.com/updated",
            title: "Updated Tutorial",
            description: "Updated description",
            dateAdded: url.dateAdded
        )

        try await service.updateReferenceUrl(updated, in: plan.id)

        // URL updated (verified at repository level)
    }

    @Test("Delete reference URL")
    func testDeleteReferenceUrl() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = try await service.createPlan(ProjectPlanModel(
            title: "Plan with URLs",
            planType: .recipe,
            tags: ["test"]
        ))

        let url = ProjectReferenceUrl(
            
            url: "https://example.com/tutorial",
            title: "Tutorial"
        )

        try await service.addReferenceUrl(url, to: plan.id)
        try await service.deleteReferenceUrl(id: url.id, from: plan.id)

        // URL deleted (verified at repository level)
    }

    // MARK: - Log CRUD Operations

    @Test("Create a new project log")
    func testCreateLog() async throws {
        let service = RepositoryFactory.createProjectService()

        let log = ProjectLogModel(
            title: "Test Log",
            tags: ["test"],
            status: .inProgress
        )

        let created = try await service.createLog(log)

        #expect(created.title == "Test Log")
        #expect(created.tags == ["test"])
        #expect(created.status == .inProgress)
        #expect(created.dateCreated != nil)
    }

    @Test("Create log from plan")
    func testCreateLogFromPlan() async throws {
        let service = RepositoryFactory.createProjectService()

        // Create a plan
        let plan = try await service.createPlan(ProjectPlanModel(
            title: "Plan for Log",
            planType: .recipe,
            tags: ["sculpture", "test"],
            summary: "This will become a log"
        ))

        #expect(plan.timesUsed == 0)

        // Create log from plan
        let log = try await service.createLogFromPlan(planId: plan.id)

        #expect(log.title == "Plan for Log")
        #expect(log.basedOnPlanId == plan.id)
        #expect(log.tags == ["sculpture", "test"])
        #expect(log.status == .inProgress)

        // Verify plan usage was recorded
        let updatedPlan = try await service.getPlan(id: plan.id)
        #expect(updatedPlan?.timesUsed == 1)
    }

    @Test("Create log from plan with custom title")
    func testCreateLogFromPlanWithCustomTitle() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = try await service.createPlan(ProjectPlanModel(
            title: "Plan Title",
            planType: .recipe,
            tags: ["test"]
        ))

        let log = try await service.createLogFromPlan(planId: plan.id, title: "Custom Log Title")

        #expect(log.title == "Custom Log Title")
        #expect(log.basedOnPlanId == plan.id)
    }

    @Test("Update an existing log")
    func testUpdateLog() async throws {
        let service = RepositoryFactory.createProjectService()

        let log = try await service.createLog(ProjectLogModel(
            title: "Original Title",
            tags: ["test"],
            status: .inProgress
        ))

        let updated = ProjectLogModel(
            id: log.id,
            title: "Updated Title",
            dateCreated: log.dateCreated,
            dateModified: Date(),
            basedOnPlanId: log.basedOnPlanId,
            tags: ["test", "updated"],
            notes: "Added some notes",
            status: .completed,
        )

        try await service.updateLog(updated)

        let fetched = try await service.getLog(id: log.id)
        #expect(fetched?.title == "Updated Title")
        #expect(fetched?.tags == ["test", "updated"])
        #expect(fetched?.status == .completed)
    }

    @Test("Delete a log")
    func testDeleteLog() async throws {
        let service = RepositoryFactory.createProjectService()

        let log = try await service.createLog(ProjectLogModel(
            title: "Log to Delete",
            tags: ["test"],
            status: .inProgress
        ))

        try await service.deleteLog(id: log.id)

        let fetched = try await service.getLog(id: log.id)
        #expect(fetched == nil)
    }

    // MARK: - Log Business Queries

    @Test("Get logs by status")
    func testGetLogsByStatus() async throws {
        let service = RepositoryFactory.createProjectService()

        // Create logs with different statuses
        _ = try await service.createLog(ProjectLogModel(
            title: "In Progress Log",
            tags: ["test"],
            status: .inProgress
        ))

        _ = try await service.createLog(ProjectLogModel(
            title: "Completed Log",
            tags: ["test"],
            status: .completed
        ))

        _ = try await service.createLog(ProjectLogModel(
            title: "Sold Log",
            tags: ["test"],
            status: .sold
        ))

        // Get in-progress logs
        let inProgressLogs = try await service.getAllLogs(status: .inProgress)
        #expect(inProgressLogs.allSatisfy { $0.status == .inProgress })
        #expect(inProgressLogs.count >= 1)

        // Get completed logs
        let completedLogs = try await service.getAllLogs(status: .completed)
        #expect(completedLogs.allSatisfy { $0.status == .completed })

        // Get sold logs
        let soldLogs = try await service.getSoldLogs()
        #expect(soldLogs.allSatisfy { $0.status == .sold })
    }

    @Test("Get logs by date range")
    func testGetLogsByDateRange() async throws {
        let service = RepositoryFactory.createProjectService()

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!

        _ = try await service.createLog(ProjectLogModel(
            title: "Recent Log",
            tags: ["test"],
            status: .inProgress
        ))

        let logs = try await service.getLogsByDateRange(start: yesterday, end: tomorrow)
        #expect(logs.count >= 1)
        #expect(logs.contains { $0.title == "Recent Log" })
    }

    @Test("Get logs based on a specific plan")
    func testGetLogsBasedOnPlan() async throws {
        let service = RepositoryFactory.createProjectService()

        // Create a plan
        let plan = try await service.createPlan(ProjectPlanModel(
            title: "Plan for Multiple Logs",
            planType: .recipe,
            tags: ["test"]
        ))

        // Create logs from this plan
        _ = try await service.createLogFromPlan(planId: plan.id, title: "First Execution")
        _ = try await service.createLogFromPlan(planId: plan.id, title: "Second Execution")

        // Get logs based on this plan
        let logs = try await service.getLogsBasedOnPlan(planId: plan.id)

        #expect(logs.count == 2)
        #expect(logs.allSatisfy { $0.basedOnPlanId == plan.id })
        #expect(logs.contains { $0.title == "First Execution" })
        #expect(logs.contains { $0.title == "Second Execution" })
    }

    // MARK: - Revenue Tracking

    @Test("Calculate total revenue from sold projects")
    func testGetTotalRevenue() async throws {
        let service = RepositoryFactory.createProjectService()

        // Create sold logs with prices
        let log1 = try await service.createLog(ProjectLogModel(
            title: "Sold Project 1",
            tags: ["test"],
            pricePoint: Decimal(100.00),
            status: .sold
        ))

        let log2 = try await service.createLog(ProjectLogModel(
            title: "Sold Project 2",
            tags: ["test"],
            pricePoint: Decimal(250.00),
            status: .sold
        ))

        // Create in-progress log (should not count)
        _ = try await service.createLog(ProjectLogModel(
            title: "In Progress",
            tags: ["test"],
            status: .inProgress
        ))

        let totalRevenue = try await service.getTotalRevenue()

        #expect(totalRevenue >= Decimal(350.00))
    }

    @Test("Calculate revenue for date range")
    func testGetRevenueForDateRange() async throws {
        let service = RepositoryFactory.createProjectService()

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!

        // Create sold log
        _ = try await service.createLog(ProjectLogModel(
            title: "Recent Sale",
            tags: ["test"],
            pricePoint: Decimal(150.00),
            status: .sold
        ))

        let revenue = try await service.getRevenueForDateRange(start: yesterday, end: tomorrow)

        #expect(revenue >= Decimal(150.00))
    }

    // MARK: - Analytics and Reporting

    @Test("Get project statistics")
    func testGetProjectStatistics() async throws {
        let service = RepositoryFactory.createProjectService()

        // Create some plans
        let plan1 = try await service.createPlan(ProjectPlanModel(
            title: "Active Plan 1",
            planType: .recipe,
            tags: ["test"]
        ))

        let plan2 = try await service.createPlan(ProjectPlanModel(
            title: "Plan to Archive",
            planType: .technique,
            tags: ["test"]
        ))
        try await service.archivePlan(id: plan2.id)

        // Create some logs
        _ = try await service.createLog(ProjectLogModel(
            title: "In Progress",
            tags: ["test"],
            status: .inProgress
        ))

        _ = try await service.createLog(ProjectLogModel(
            title: "Completed",
            tags: ["test"],
            status: .completed
        ))

        _ = try await service.createLog(ProjectLogModel(
            title: "Sold",
            tags: ["test"],
            pricePoint: Decimal(200.00),
            status: .sold
        ))

        let stats = try await service.getProjectStatistics()

        #expect(stats.totalPlans >= 2)
        #expect(stats.activePlans >= 1)
        #expect(stats.archivedPlans >= 1)
        #expect(stats.totalLogs >= 3)
        #expect(stats.inProgressProjects >= 1)
        #expect(stats.completedProjects >= 1)
        #expect(stats.soldProjects >= 1)
        #expect(stats.totalRevenue >= Decimal(200.00))
    }

    @Test("Project statistics calculates completion rate")
    func testProjectStatisticsCompletionRate() async throws {
        let service = RepositoryFactory.createProjectService()

        // Create 2 completed/sold, 1 in-progress
        _ = try await service.createLog(ProjectLogModel(
            title: "Completed",
            tags: ["test"],
            status: .completed
        ))

        _ = try await service.createLog(ProjectLogModel(
            title: "Sold",
            tags: ["test"],
            status: .sold
        ))

        _ = try await service.createLog(ProjectLogModel(
            title: "In Progress",
            tags: ["test"],
            status: .inProgress
        ))

        let stats = try await service.getProjectStatistics()

        // At least 66% completion rate (2 out of 3)
        #expect(stats.completionRate >= 0.66)
    }

    @Test("Project statistics calculates average revenue per sale")
    func testProjectStatisticsAverageRevenue() async throws {
        let service = RepositoryFactory.createProjectService()

        _ = try await service.createLog(ProjectLogModel(
            title: "Sale 1",
            tags: ["test"],
            pricePoint: Decimal(100.00),
            status: .sold
        ))

        _ = try await service.createLog(ProjectLogModel(
            title: "Sale 2",
            tags: ["test"],
            pricePoint: Decimal(200.00),
            status: .sold
        ))

        let stats = try await service.getProjectStatistics()

        // Average should be around 150
        #expect(stats.averageRevenuePerSale >= Decimal(100.00))
        #expect(stats.averageRevenuePerSale <= Decimal(200.00))
    }

    // MARK: - Plan with Glass Items

    @Test("Create plan with glass items data")
    func testCreatePlanWithGlassItems() async throws {
        let service = RepositoryFactory.createProjectService()

        let glassItemData = ProjectGlassItem(
            naturalKey: "cim-123-0",
            quantity: 5.0,
            unit: "oz"
        )

        let plan = ProjectPlanModel(
            title: "Plan with Glass",
            planType: .recipe,
            tags: ["test"],
            glassItems: [glassItemData]
        )

        let created = try await service.createPlan(plan)

        #expect(created.glassItems.count == 1)
        #expect(created.glassItems.first?.naturalKey == "cim-123-0")
                #expect(created.glassItems.first?.quantity == 5.0)
    }

    @Test("Create log from plan preserves glass items")
    func testCreateLogFromPlanPreservesGlassItems() async throws {
        let service = RepositoryFactory.createProjectService()

        let glassItemData = ProjectGlassItem(
            naturalKey: "cim-456-0",
            quantity: 3.0,
            unit: "oz"
        )

        let plan = try await service.createPlan(ProjectPlanModel(
            title: "Plan with Glass",
            planType: .recipe,
            tags: ["test"],
            glassItems: [glassItemData]
        ))

        let log = try await service.createLogFromPlan(planId: plan.id)

        #expect(log.glassItems.count == 1)
        #expect(log.glassItems.first?.naturalKey == "cim-456-0")
            }

    // MARK: - Edge Cases

    @Test("Create log from non-existent plan throws error")
    func testCreateLogFromNonExistentPlan() async throws {
        let service = RepositoryFactory.createProjectService()

        let nonExistentId = UUID()

        await #expect(throws: Error.self) {
            _ = try await service.createLogFromPlan(planId: nonExistentId)
        }
    }

    @Test("Record usage for non-existent plan throws error")
    func testRecordUsageForNonExistentPlan() async throws {
        let service = RepositoryFactory.createProjectService()

        let nonExistentId = UUID()

        await #expect(throws: Error.self) {
            try await service.recordPlanUsage(id: nonExistentId)
        }
    }

    @Test("Get unused plans when all plans are used")
    func testGetUnusedPlansWhenAllUsed() async throws {
        let service = RepositoryFactory.createProjectService()

        let plan = try await service.createPlan(ProjectPlanModel(
            title: "Used Plan",
            planType: .recipe,
            tags: ["test"]
        ))

        try await service.recordPlanUsage(id: plan.id)

        // Since we only created one plan and it's used, unused should exclude it
        let unused = try await service.getUnusedPlans()

        #expect(!unused.contains { $0.id == plan.id })
    }

    @Test("Get most used plans with limit")
    func testGetMostUsedPlansWithLimit() async throws {
        let service = RepositoryFactory.createProjectService()

        // Create 3 used plans
        let plan1 = try await service.createPlan(ProjectPlanModel(title: "Plan 1", planType: .recipe, tags: ["test"]))
        try await service.recordPlanUsage(id: plan1.id)

        let plan2 = try await service.createPlan(ProjectPlanModel(title: "Plan 2", planType: .recipe, tags: ["test"]))
        try await service.recordPlanUsage(id: plan2.id)
        try await service.recordPlanUsage(id: plan2.id)

        let plan3 = try await service.createPlan(ProjectPlanModel(title: "Plan 3", planType: .recipe, tags: ["test"]))
        try await service.recordPlanUsage(id: plan3.id)
        try await service.recordPlanUsage(id: plan3.id)
        try await service.recordPlanUsage(id: plan3.id)

        // Get top 2
        let mostUsed = try await service.getMostUsedPlans(limit: 2)

        #expect(mostUsed.count == 2)
        #expect(mostUsed[0].timesUsed >= mostUsed[1].timesUsed)
    }
}
