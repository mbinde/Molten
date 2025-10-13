import Foundation

/// Enumeration representing the units for inventory items
/// Migrated to Repository Pattern on 10/12/25 - Removed Core Data dependencies
enum InventoryUnits: Int, CaseIterable, Identifiable, Codable {
    case rods = 1
    case ounces = 2
    case pounds = 3
    case grams = 4
    case kilograms = 5
    
    var id: Int { rawValue }
    
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
    
    /// Initialize from Int16 for backward compatibility with Core Data migration
    init?(fromInt16 value: Int16) {
        self.init(rawValue: Int(value))
    }
    
    /// Convert to Int16 for Core Data compatibility during transition
    var asInt16: Int16 {
        return Int16(rawValue)
    }
}

// MARK: - Repository Pattern Helpers

extension InventoryUnits {
    /// Format quantity with appropriate unit display
    static func formatQuantity(_ quantity: Double, units: InventoryUnits?) -> String {
        let unitsToUse = units ?? .rods
        let unitName = unitsToUse.displayName
        
        // Format number without unnecessary decimal places
        let formattedCount: String
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            // Whole number - show without decimal
            formattedCount = String(format: "%.0f", quantity)
        } else {
            // Has decimal part - show one decimal place
            formattedCount = String(format: "%.1f", quantity)
        }
        
        return "\(formattedCount) \(unitName)"
    }
    
    /// Convert legacy Int16 values during Core Data migration
    static func fromLegacyInt16(_ value: Int16?) -> InventoryUnits {
        guard let value = value else { return .rods }
        return InventoryUnits(fromInt16: value) ?? .rods
    }
}
