//
//  LogbookViewModel.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Protocol-based ViewModel for LogbookView - enables testability
//

import Foundation
import SwiftUI

/// ViewModel for the Logbook view
///
/// Manages presentation logic for:
/// - Loading logbook entries
/// - Searching and filtering entries
/// - Computing UI state
@MainActor
@Observable
class LogbookViewModel: LogbookViewModelProtocol {

    // MARK: - Dependencies

    private let logbookRepository: LogbookRepository

    // MARK: - Published State

    var logEntries: [LogbookModel] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Search State

    var searchText = "" {
        didSet {
            if searchText != oldValue {
                applyFilters()
            }
        }
    }

    var searchTitlesOnly = false {
        didSet {
            if searchTitlesOnly != oldValue {
                applyFilters()
            }
        }
    }

    // MARK: - Filtered State (computed internally)

    private var _filteredEntries: [LogbookModel] = []

    var filteredEntries: [LogbookModel] {
        _filteredEntries
    }

    // MARK: - Initialization

    init(logbookRepository: LogbookRepository) {
        self.logbookRepository = logbookRepository
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        !logEntries.isEmpty
    }

    var hasError: Bool {
        errorMessage != nil
    }

    var filteredEntriesCount: Int {
        _filteredEntries.count
    }

    // MARK: - Data Loading

    func loadLogEntries() async {
        isLoading = true
        errorMessage = nil

        do {
            logEntries = try await logbookRepository.getAllLogs()
            applyFilters()
        } catch {
            errorMessage = "Failed to load logbook entries: \(error.localizedDescription)"
            logEntries = []
            _filteredEntries = []
        }

        isLoading = false
    }

    func refreshLogEntries() async {
        await loadLogEntries()
    }

    // MARK: - Search

    func searchEntries(text: String) {
        searchText = text
    }

    func clearSearch() {
        searchText = ""
        searchTitlesOnly = false
    }

    // MARK: - Private Helpers

    private func applyFilters() {
        var filtered = logEntries

        // Apply search filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { entry in
                if searchTitlesOnly {
                    // Search titles only
                    return entry.title.lowercased().contains(searchLower)
                } else {
                    // Search all fields
                    let title = entry.title.lowercased()
                    let notes = entry.notes?.lowercased() ?? ""
                    let tags = entry.tags.joined(separator: " ").lowercased()

                    return title.contains(searchLower) ||
                           notes.contains(searchLower) ||
                           tags.contains(searchLower)
                }
            }
        }

        _filteredEntries = filtered
    }
}
