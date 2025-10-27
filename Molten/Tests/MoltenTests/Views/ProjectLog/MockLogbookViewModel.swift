//
//  MockLogbookViewModel.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Mock implementation of LogbookViewModel for testing and previews
//

import Foundation
import SwiftUI
@testable import Molten

/// Mock implementation of LogbookViewModelProtocol for testing and previews
///
/// **Usage in tests:**
/// ```swift
/// let mockVM = MockLogbookViewModel(scenario: .loaded)
/// #expect(mockVM.hasData)
/// ```
///
/// **Usage in previews:**
/// ```swift
/// #Preview("Loaded State") {
///     LogbookView(viewModel: MockLogbookViewModel(scenario: .loaded))
/// }
/// ```
@MainActor
@Observable
class MockLogbookViewModel: LogbookViewModelProtocol {

    // MARK: - Scenario

    enum Scenario {
        case empty
        case loading
        case error
        case loaded
        case filtered
    }

    // MARK: - Data State

    var logEntries: [LogbookModel]
    var filteredEntries: [LogbookModel]

    // MARK: - Loading State

    var isLoading: Bool
    var errorMessage: String?

    // MARK: - Search State

    var searchText: String = ""
    var searchTitlesOnly: Bool = false

    // MARK: - Test Tracking

    var loadLogEntriesCalled = false
    var refreshLogEntriesCalled = false
    var searchEntriesCalled = false
    var clearSearchCalled = false

    // MARK: - Initialization

    init(scenario: Scenario = .loaded) {
        switch scenario {
        case .empty:
            self.logEntries = []
            self.filteredEntries = []
            self.isLoading = false
            self.errorMessage = nil

        case .loading:
            self.logEntries = []
            self.filteredEntries = []
            self.isLoading = true
            self.errorMessage = nil

        case .error:
            self.logEntries = []
            self.filteredEntries = []
            self.isLoading = false
            self.errorMessage = "Failed to load logbook entries"

        case .loaded:
            let mockEntries = Self.createMockLogEntries()
            self.logEntries = mockEntries
            self.filteredEntries = mockEntries
            self.isLoading = false
            self.errorMessage = nil

        case .filtered:
            let mockEntries = Self.createMockLogEntries()
            self.logEntries = mockEntries
            // Only show first entry after "filtering"
            self.filteredEntries = Array(mockEntries.prefix(1))
            self.isLoading = false
            self.errorMessage = nil
            self.searchText = "Vase"
        }
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        !logEntries.isEmpty
    }

    var hasError: Bool {
        errorMessage != nil
    }

    var filteredEntriesCount: Int {
        filteredEntries.count
    }

    // MARK: - Data Loading

    func loadLogEntries() async {
        loadLogEntriesCalled = true
        // Mock implementation - data already set in init
    }

    func refreshLogEntries() async {
        refreshLogEntriesCalled = true
        // Mock implementation - data already set in init
    }

    // MARK: - Search

    func searchEntries(text: String) {
        searchEntriesCalled = true
        searchText = text

        // Mock implementation - simple filtering
        if text.isEmpty {
            filteredEntries = logEntries
        } else {
            let searchLower = text.lowercased()
            filteredEntries = logEntries.filter { entry in
                if searchTitlesOnly {
                    return entry.title.lowercased().contains(searchLower)
                } else {
                    let title = entry.title.lowercased()
                    let notes = entry.notes?.lowercased() ?? ""
                    let tags = entry.tags.joined(separator: " ").lowercased()

                    return title.contains(searchLower) ||
                           notes.contains(searchLower) ||
                           tags.contains(searchLower)
                }
            }
        }
    }

    func clearSearch() {
        clearSearchCalled = true
        searchText = ""
        searchTitlesOnly = false
        filteredEntries = logEntries
    }

    // MARK: - Mock Data Helpers

    private static func createMockLogEntries() -> [LogbookModel] {
        return [
            LogbookModel(
                title: "Glass Vase Project",
                startDate: Date().addingTimeInterval(-86400 * 10),
                completionDate: Date().addingTimeInterval(-86400 * 5),
                tags: ["vase", "blue", "frit"],
                notes: "Created a beautiful blue vase using frit and sheet glass",
                status: .completed
            ),
            LogbookModel(
                title: "Pendant Experiment",
                startDate: Date().addingTimeInterval(-86400 * 20),
                completionDate: Date().addingTimeInterval(-86400 * 12),
                tags: ["pendant", "dichroic"],
                notes: "Testing new pendant designs with dichroic glass",
                status: .completed
            ),
            LogbookModel(
                title: "Bowl Set",
                startDate: Date().addingTimeInterval(-86400 * 35),
                tags: ["bowl", "set"],
                notes: "Set of three nesting bowls in warm colors",
                status: .inProgress
            )
        ]
    }
}
