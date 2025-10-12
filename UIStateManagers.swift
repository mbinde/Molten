//  UIStateManagers.swift
//  UIStateManagers.swift
//  Flameworker
//
//  Created by Assistant on 10/11/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Loading State Manager

/// Manages loading state for UI operations with duplicate prevention
class LoadingStateManager: ObservableObject {
    
    @Published var isLoading: Bool = false
    @Published var operationName: String? = nil
    
    /// Start a loading operation
    /// - Parameter operationName: Name of the operation for tracking
    /// - Returns: True if operation was started, false if already loading
    func startLoading(operationName: String) -> Bool {
        guard !isLoading else {
            return false // Operation already in progress
        }
        
        isLoading = true
        self.operationName = operationName
        return true
    }
    
    /// Complete the loading operation successfully
    func completeLoading() {
        isLoading = false
        operationName = nil
    }
    
    /// Complete the loading operation with an error
    /// - Parameter error: Error description (optional)
    func completeLoading(withError error: String?) {
        isLoading = false
        operationName = nil
        // Could add error tracking here if needed
    }
}

// MARK: - Selection State Manager

/// Generic selection state manager for managing sets of selected items
class SelectionStateManager<T: Hashable>: ObservableObject {
    
    @Published var selectedItems: Set<T> = []
    
    /// Check if an item is selected
    /// - Parameter item: The item to check
    /// - Returns: True if the item is selected
    func isSelected(_ item: T) -> Bool {
        return selectedItems.contains(item)
    }
    
    /// Toggle selection state of an item
    /// - Parameter item: The item to toggle
    func toggle(_ item: T) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
    
    /// Select all items from the provided list
    /// - Parameter items: Items to select
    func selectAll(_ items: [T]) {
        selectedItems = Set(items)
    }
    
    /// Clear all selections
    func clearAll() {
        selectedItems.removeAll()
    }
}

// MARK: - Filter State Manager

/// Manages various filter states and active filter detection
class FilterStateManager: ObservableObject {
    
    @Published var textFilter: String = ""
    @Published var categoryFilters: [String] = []
    @Published var manufacturerFilter: String = ""
    
    /// Check if any filters are currently active
    var hasActiveFilters: Bool {
        return !textFilter.isEmpty || !categoryFilters.isEmpty || !manufacturerFilter.isEmpty
    }
    
    /// Count of active filters
    var activeFilterCount: Int {
        var count = 0
        if !textFilter.isEmpty { count += 1 }
        if !categoryFilters.isEmpty { count += 1 }
        if !manufacturerFilter.isEmpty { count += 1 }
        return count
    }
    
    /// Set text filter
    /// - Parameter text: Filter text
    func setTextFilter(_ text: String) {
        textFilter = text
    }
    
    /// Clear text filter
    func clearTextFilter() {
        textFilter = ""
    }
    
    /// Set category filters
    /// - Parameter categories: Array of category names
    func setCategoryFilters(_ categories: [String]) {
        categoryFilters = categories
    }
    
    /// Set manufacturer filter
    /// - Parameter manufacturer: Manufacturer name
    func setManufacturerFilter(_ manufacturer: String) {
        manufacturerFilter = manufacturer
    }
    
    /// Clear all filters
    func clearAllFilters() {
        textFilter = ""
        categoryFilters.removeAll()
        manufacturerFilter = ""
    }
}