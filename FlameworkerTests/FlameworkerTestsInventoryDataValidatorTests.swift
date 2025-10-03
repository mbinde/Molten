//
//  InventoryDataValidatorTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
import CoreData
import SwiftUI
@testable import Flameworker

@Suite("InventoryDataValidator Tests")
struct InventoryDataValidatorTests {
    
    // MARK: - Test Protocol for Inventory Items
    
    /// Protocol defining the interface needed for inventory validation
    protocol InventoryDataProvider {
        var count: Double { get }
        var notes: String? { get }
    }
    
    // MARK: - Mock Inventory Item for Testing
    
    struct MockInventoryItem: InventoryDataProvider {
        var count: Double
        var notes: String?
        
        init(count: Double = 0.0, notes: String? = nil) {
            self.count = count
            self.notes = notes
        }
    }
    
    // MARK: - Inventory Data Detection Tests
    
    @Test("Item with count has inventory data")
    func itemWithCountHasData() {
        let item = MockInventoryItem(count: 5.0, notes: nil)
        
        #expect(InventoryDataValidator.hasInventoryData(item) == true)
    }
    
    @Test("Item with notes has inventory data")
    func itemWithNotesHasData() {
        let item = MockInventoryItem(count: 0.0, notes: "Some notes")
        
        #expect(InventoryDataValidator.hasInventoryData(item) == true)
    }
    
    @Test("Item with both count and notes has inventory data")
    func itemWithBothHasData() {
        let item = MockInventoryItem(count: 3.0, notes: "Some notes")
        
        #expect(InventoryDataValidator.hasInventoryData(item) == true)
    }
    
    @Test("Item with no count or notes has no inventory data")
    func itemWithNeitherHasNoData() {
        let item = MockInventoryItem(count: 0.0, notes: nil)
        
        #expect(InventoryDataValidator.hasInventoryData(item) == false)
    }
    
    @Test("Item with empty notes string has no inventory data")
    func itemWithEmptyNotesHasNoData() {
        let item = MockInventoryItem(count: 0.0, notes: "")
        
        #expect(InventoryDataValidator.hasInventoryData(item) == false)
    }
    
    @Test("Item with whitespace-only notes has no inventory data")
    func itemWithWhitespaceNotesHasNoData() {
        let item = MockInventoryItem(count: 0.0, notes: "   \t\n  ")
        
        #expect(InventoryDataValidator.hasInventoryData(item) == false)
    }
    
    // MARK: - Format Display Tests
    
    @Test("Format display with count only")
    func formatDisplayCountOnly() {
        let result = InventoryDataValidator.formatInventoryDisplay(
            count: 5.5,
            units: .shorts, 
            type: .inventory,
            notes: nil
        )
        
        #expect(result != nil)
        #expect(result?.contains("5.5") == true)
    }
    
    @Test("Format display with notes only")
    func formatDisplayNotesOnly() {
        let result = InventoryDataValidator.formatInventoryDisplay(
            count: 0.0,
            units: .shorts,
            type: .inventory,
            notes: "Test notes"
        )
        
        #expect(result == "Test notes")
    }
    
    @Test("Format display with count and notes")
    func formatDisplayCountAndNotes() {
        let result = InventoryDataValidator.formatInventoryDisplay(
            count: 2.0,
            units: .shorts,
            type: .inventory,
            notes: "Test notes"
        )
        
        #expect(result != nil)
        #expect(result?.contains("2.0") == true)
        #expect(result?.contains("Test notes") == true)
        #expect(result?.contains(" • ") == true) // Separator
    }
    
    @Test("Format display with no data returns nil")
    func formatDisplayNoDataReturnsNil() {
        let result = InventoryDataValidator.formatInventoryDisplay(
            count: 0.0,
            units: .shorts,
            type: .inventory,
            notes: nil
        )
        
        #expect(result == nil)
    }
    
    @Test("Format display with empty notes returns nil when no count")
    func formatDisplayEmptyNotesNoCount() {
        let result = InventoryDataValidator.formatInventoryDisplay(
            count: 0.0,
            units: .shorts,
            type: .inventory,
            notes: ""
        )
        
        #expect(result == nil)
    }
    
    @Test("Format display with whitespace notes returns nil when no count")
    func formatDisplayWhitespaceNotesNoCount() {
        let result = InventoryDataValidator.formatInventoryDisplay(
            count: 0.0,
            units: .shorts,
            type: .inventory,
            notes: "   \t  "
        )
        
        #expect(result == nil)
    }
}

// MARK: - InventoryDataValidator Implementation

/// Validator for inventory data operations
struct InventoryDataValidator {
    
    /// Checks if an inventory item has meaningful data (non-zero count or meaningful notes)
    static func hasInventoryData<T: InventoryDataValidatorTests.InventoryDataProvider>(_ item: T) -> Bool {
        // Check if count is meaningful (greater than 0)
        if item.count > 0 {
            return true
        }
        
        // Check if notes are meaningful (not nil, empty, or whitespace)
        if let notes = item.notes,
           !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        
        return false
    }
    
    /// Formats inventory display string combining count, units, type, and notes
    static func formatInventoryDisplay(
        count: Double,
        units: InventoryUnits,
        type: InventoryItemType,
        notes: String?
    ) -> String? {
        var components: [String] = []
        
        // Add count if meaningful
        if count > 0 {
            let formattedCount = count.truncatingRemainder(dividingBy: 1) == 0 
                ? String(format: "%.0f", count)
                : String(format: "%.1f", count)
            components.append("\(formattedCount) \(units.displayName)")
        }
        
        // Add notes if meaningful
        if let notes = notes,
           !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            components.append(notes.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        // Return formatted string or nil if no meaningful data
        return components.isEmpty ? nil : components.joined(separator: " • ")
    }
}
