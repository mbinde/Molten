import Foundation
import CoreData

/// Enumeration representing the units for an InventoryItem
enum InventoryUnits: Int16, CaseIterable, Identifiable {
    case rods = 1
    case ounces = 2
    case pounds = 3
    case grams = 4
    case kilograms = 5
    
    var id: Int16 { rawValue }
    
    /// Human-readable display name for the units
    var displayName: String {
        switch self {
        case .rods:
            return "Rods"
        case .ounces:
            return "oz"
        case .pounds:
            return "lb"
        case .grams:
            return "g"
        case .kilograms:
            return "kg"
        }
    }
    
}

// MARK: - InventoryItem Convenience

extension InventoryItem {
    /// Strongly-typed accessor for the units property
    var unitsKind: InventoryUnits {
        get { 
            guard !self.isDeleted else { return .rods }
            return InventoryUnits(rawValue: units) ?? .rods
        }
        set { 
            guard !self.isDeleted else { return }
            units = newValue.rawValue 
        }
    }
    
    /// Display string for units
    var unitsDisplayName: String { 
        guard !self.isDeleted else { return "Unknown" }
        return unitsKind.displayName 
    }
    
    /// Get converted count and unit display info based on user preferences
    var displayInfo: (count: Double, unit: String) {
        // Safely access Core Data properties to prevent EXC_BAD_ACCESS
        guard !self.isDeleted else {
            return (count: 0.0, unit: "Unknown")
        }
        return UnitsDisplayHelper.displayInfo(for: self)
    }
    
    /// Formatted display string for count with units
    var formattedCountWithUnits: String {
        // Safely access Core Data properties to prevent EXC_BAD_ACCESS
        guard !self.isDeleted else {
            return "0 Unknown"
        }
        
        let info = displayInfo
        
        // Format number without unnecessary decimal places
        let formattedCount: String
        if info.count.truncatingRemainder(dividingBy: 1) == 0 {
            // Whole number - show without decimal
            formattedCount = String(format: "%.0f", info.count)
        } else {
            // Has decimal part - show one decimal place
            formattedCount = String(format: "%.1f", info.count)
        }
        
        return formattedCount + " " + info.unit
    }
}
