import Foundation

/// Units for weight measurements
enum WeightUnit: String, CaseIterable, Identifiable {
    case pounds
    case kilograms
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .pounds: return "Pounds"
        case .kilograms: return "Kilograms"
        }
    }
    
    /// Short symbol for display alongside numeric values
    var symbol: String {
        switch self {
        case .pounds: return "lb"
        case .kilograms: return "kg"
        }
    }
    
    /// System image to use in UI where appropriate
    var systemImage: String { "scalemass" }
    
    /// Convert weight from one unit to another
    func convert(_ value: Double, to targetUnit: WeightUnit) -> Double {
        if self == targetUnit {
            return value
        }
        
        switch (self, targetUnit) {
        case (.pounds, .kilograms):
            return value * 0.453592 // 1 lb = 0.453592 kg
        case (.kilograms, .pounds):
            return value / 0.453592 // 1 kg = 2.20462 lb
        default:
            return value
        }
    }
}

/// Centralized access to the stored weight unit preference
struct WeightUnitPreference {
    static let storageKey = "defaultUnits"
    
    static var current: WeightUnit {
        if let raw = UserDefaults.standard.string(forKey: storageKey) {
            // Convert from DefaultUnits to WeightUnit
            switch raw {
            case "Pounds":
                return .pounds
            case "Kilograms":
                return .kilograms
            default:
                return .pounds
            }
        }
        return .pounds
    }
}

/// Helper for rendering unit names in UI
struct UnitsDisplayHelper {
    static func displayName(for units: InventoryUnits) -> String {
        switch units {
        case .pounds:
            return "lb"
        case .kilograms:
            return "kg"
        case .shorts, .rods:
            return units.displayName
        }
    }
    
    /// Get the InventoryUnits case that matches the current weight unit preference
    static func preferredWeightUnit() -> InventoryUnits {
        switch WeightUnitPreference.current {
        case .pounds:
            return .pounds
        case .kilograms:
            return .kilograms
        }
    }
    
    /// Convert count and get display info for an inventory item
    static func displayInfo(for item: InventoryItem) -> (count: Double, unit: String) {
        let itemUnits = item.unitsKind
        
        // Only convert weight units, leave others as-is
        switch itemUnits {
        case .pounds, .kilograms:
            let sourceWeightUnit: WeightUnit = (itemUnits == .pounds) ? .pounds : .kilograms
            let preferredWeightUnit = WeightUnitPreference.current
            
            let convertedCount = sourceWeightUnit.convert(item.count, to: preferredWeightUnit)
            let displayUnit = preferredWeightUnit.symbol
            
            return (count: convertedCount, unit: displayUnit)
            
        case .shorts, .rods:
            return (count: item.count, unit: itemUnits.displayName)
        }
    }
}
