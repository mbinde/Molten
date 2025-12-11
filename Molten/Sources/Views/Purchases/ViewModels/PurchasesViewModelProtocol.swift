//
//  PurchasesViewModelProtocol.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Protocol defining the Purchases view's presentation logic for testability
//

import Foundation
import SwiftUI

/// Protocol defining the purchases view's presentation logic
///
/// This protocol enables:
/// - Unit testing of presentation logic with mocks
/// - Dependency injection for views
/// - Easy creation of previews with different states
@MainActor
protocol PurchasesViewModelProtocol {

    // MARK: - Data State

    /// All purchase records (unfiltered)
    var purchases: [PurchaseRecordModel] { get }

    /// Purchases after applying search filter
    var filteredPurchases: [PurchaseRecordModel] { get }

    // MARK: - Loading State

    /// Whether data is currently being loaded
    var isLoading: Bool { get }

    /// Error message if operation failed
    var errorMessage: String? { get }

    // MARK: - Search State

    /// Current search text
    var searchText: String { get set }

    // MARK: - Computed Properties

    /// Whether any purchases have been loaded
    var hasData: Bool { get }

    /// Whether an error occurred
    var hasError: Bool { get }

    /// Number of purchases after filtering
    var filteredPurchasesCount: Int { get }

    // MARK: - Data Loading

    /// Load all purchase records
    func loadPurchases() async

    /// Refresh purchase records
    func refreshPurchases() async

    // MARK: - Search

    /// Update search text and apply filter
    func searchPurchases(text: String)

    /// Clear search filter
    func clearSearch()

}
