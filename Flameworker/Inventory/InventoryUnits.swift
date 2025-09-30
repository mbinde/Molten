import Foundation

/// Enumeration representing the units for an InventoryItem
enum InventoryUnits: Int16, CaseIterable, Identifiable {
    case shorts = 0
    case rods = 1
    case pounds = 2
    case kilograms = 3
    
    var id: Int16 { rawValue }
    
    /// Human-readable display name for the units
    var displayName: String {
        switch self {
        case .shorts:
            return "Shorts"
        case .rods:
            return "Rods"
        case .pounds:
            return "Pounds"
        case .kilograms:
            return "Kilograms"
        }
    }
    
    /// Initialize from Int16 value with fallback to .shorts
    init(from rawValue: Int16) {
        self = InventoryUnits(rawValue: rawValue) ?? .shorts
    }
}

// MARK: - InventoryItem Convenience

extension InventoryItem {
    /// Strongly-typed accessor for the units property
    var unitsKind: InventoryUnits {
        get { InventoryUnits(from: units) }
        set { units = newValue.rawValue }
    }
    
    /// Display string for units
    var unitsDisplayName: String { unitsKind.displayName }
    
    /// Get converted count and unit display info based on user preferences
    var displayInfo: (count: Double, unit: String) {
        return UnitsDisplayHelper.displayInfo(for: self)
    }
    
    /// Formatted display string for count with units
    var formattedCountWithUnits: String {
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
