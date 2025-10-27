//
//  LogbookViewModelProtocol.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Protocol defining the Logbook view's presentation logic for testability
//

import Foundation
import SwiftUI

/// Protocol defining the logbook view's presentation logic
///
/// This protocol enables:
/// - Unit testing of presentation logic with mocks
/// - Dependency injection for views
/// - Easy creation of previews with different states
@MainActor
protocol LogbookViewModelProtocol {

    // MARK: - Data State

    /// All logbook entries (unfiltered)
    var logEntries: [LogbookModel] { get }

    /// Entries after applying search filter
    var filteredEntries: [LogbookModel] { get }

    // MARK: - Loading State

    /// Whether data is currently being loaded
    var isLoading: Bool { get }

    /// Error message if operation failed
    var errorMessage: String? { get }

    // MARK: - Search State

    /// Current search text
    var searchText: String { get set }

    /// Whether to search only titles (vs all fields)
    var searchTitlesOnly: Bool { get set }

    // MARK: - Computed Properties

    /// Whether any entries have been loaded
    var hasData: Bool { get }

    /// Whether an error occurred
    var hasError: Bool { get }

    /// Number of entries after filtering
    var filteredEntriesCount: Int { get }

    // MARK: - Data Loading

    /// Load all logbook entries
    func loadLogEntries() async

    /// Refresh logbook entries
    func refreshLogEntries() async

    // MARK: - Search

    /// Update search text and apply filter
    func searchEntries(text: String)

    /// Clear search filter
    func clearSearch()
}
