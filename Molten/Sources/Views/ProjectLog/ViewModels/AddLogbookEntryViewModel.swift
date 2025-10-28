//
//  AddLogbookEntryViewModel.swift
//  Molten
//
//  Created by Assistant on 10/28/25.
//  ViewModel for AddLogbookEntryView
//

import Foundation
import SwiftUI

/// ViewModel for creating new logbook entries
///
/// Manages form state, validation, project search, and save operations
@MainActor
@Observable
class AddLogbookEntryViewModel {

    // MARK: - Dependencies

    private let logbookRepository: LogbookRepository
    private let projectRepository: ProjectRepository

    // MARK: - Form State

    var title: String = ""
    var selectedProjectIds: Set<UUID> = []
    var projectSearchText: String = ""
    var startDate: Date? = Date()
    var completionDate: Date? = Date()
    var notes: String = ""
    var status: ProjectStatus = .completed
    var tags: [String] = []
    var coe: String = "96"
    var techniquesUsed: [String] = []
    var hoursSpent: String = ""
    var pricePoint: String = ""
    var saleDate: Date?
    var buyerInfo: String = ""

    // MARK: - Image State (placeholders for now)

    var images: [ProjectImageModel] = []
    var heroImageId: UUID?

    // MARK: - UI State

    var availableProjects: [ProjectModel] = []
    var isLoadingProjects: Bool = false
    var isSaving: Bool = false
    var errorMessage: String?

    // MARK: - Initialization

    init(
        logbookRepository: LogbookRepository,
        projectRepository: ProjectRepository
    ) {
        self.logbookRepository = logbookRepository
        self.projectRepository = projectRepository
    }

    // MARK: - Validation

    /// Check if the form is valid (title is required)
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Parse hours spent as Decimal
    var parsedHours: Decimal? {
        guard !hoursSpent.isEmpty,
              let value = Decimal(string: hoursSpent),
              value > 0 else {
            return nil
        }
        return value
    }

    /// Parse price point as Decimal
    var parsedPrice: Decimal? {
        guard !pricePoint.isEmpty,
              let value = Decimal(string: pricePoint),
              value > 0 else {
            return nil
        }
        return value
    }

    // MARK: - Computed Properties

    /// Determine if business section should be shown
    var showBusinessSection: Bool {
        status == .sold || status == .gifted
    }

    /// Filter projects by search text
    var filteredProjects: [ProjectModel] {
        guard !projectSearchText.isEmpty else {
            return availableProjects
        }

        return availableProjects.filter { project in
            project.title.localizedCaseInsensitiveContains(projectSearchText) ||
            (project.summary?.localizedCaseInsensitiveContains(projectSearchText) ?? false)
        }
    }

    // MARK: - Project Management

    /// Load available projects from repository
    func loadProjects() async {
        isLoadingProjects = true
        defer { isLoadingProjects = false }

        do {
            availableProjects = try await projectRepository.getActiveProjects()
        } catch {
            print("Error loading projects: \(error)")
            errorMessage = "Failed to load projects: \(error.localizedDescription)"
        }
    }

    /// Toggle project selection (add if not selected, remove if selected)
    func toggleProjectSelection(_ projectId: UUID) {
        if selectedProjectIds.contains(projectId) {
            selectedProjectIds.remove(projectId)
        } else {
            selectedProjectIds.insert(projectId)
        }
    }

    // MARK: - Date Management

    /// Clear start date
    func clearStartDate() {
        startDate = nil
    }

    /// Set start date to current date
    func setStartDateToNow() {
        startDate = Date()
    }

    /// Clear completion date
    func clearCompletionDate() {
        completionDate = nil
    }

    /// Set completion date to current date
    func setCompletionDateToNow() {
        completionDate = Date()
    }

    /// Clear sale date
    func clearSaleDate() {
        saleDate = nil
    }

    /// Set sale date to current date
    func setSaleDateToNow() {
        saleDate = Date()
    }

    // MARK: - Save Operation

    /// Save the logbook entry
    /// - Returns: true if save succeeded, false otherwise
    func save() async -> Bool {
        guard isValid else {
            errorMessage = "Title is required"
            return false
        }

        isSaving = true
        defer { isSaving = false }

        // Create logbook model
        let log = LogbookModel(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            completionDate: completionDate,
            basedOnProjectIds: Array(selectedProjectIds),
            tags: tags,
            coe: coe,
            notes: notes.isEmpty ? nil : notes,
            techniquesUsed: techniquesUsed.isEmpty ? nil : techniquesUsed,
            hoursSpent: parsedHours,
            images: images,
            heroImageId: heroImageId,
            glassItems: [],
            pricePoint: parsedPrice,
            saleDate: saleDate,
            buyerInfo: buyerInfo.isEmpty ? nil : buyerInfo,
            status: status
        )

        do {
            _ = try await logbookRepository.createLog(log)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            return false
        }
    }
}
