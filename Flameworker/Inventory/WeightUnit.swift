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
    nonisolated static let storageKey = "defaultUnits"
    
    // Private storage for dependency injection during testing - using a lock for thread safety
    private static var _userDefaults: UserDefaults = .standard
    private static let lock = NSLock()
    
    private static var userDefaults: UserDefaults {
        lock.lock()
        defer { lock.unlock() }
        return _userDefaults
    }
    
    nonisolated static var current: WeightUnit {
        let defaults = userDefaults
        guard let raw = defaults.string(forKey: storageKey), !raw.isEmpty else {
            // No preference set - default to pounds
            return .pounds
        }
        
        // Convert from DefaultUnits to WeightUnit
        switch raw {
        case "Pounds":
            return .pounds
        case "Kilograms":
            return .kilograms
        default:
            // Invalid preference - default to pounds
            return .pounds
        }
    }
    
    // MARK: - Testing Support
    
    /// Set a custom UserDefaults instance for testing
    nonisolated static func setUserDefaults(_ userDefaults: UserDefaults) {
        lock.lock()
        defer { lock.unlock() }
        _userDefaults = userDefaults
    }
    
    /// Reset to using the standard UserDefaults
    nonisolated static func resetToStandard() {
        lock.lock()
        defer { lock.unlock() }
        _userDefaults = .standard
    }
}

/// Helper for rendering unit names in UI
struct UnitsDisplayHelper {
    static func displayName(for units: InventoryUnits) -> String {
        switch units {
        case .ounces:
            return "oz"
        case .pounds:
            return "lb"
        case .grams:
            return "g"
        case .kilograms:
            return "kg"
        case .rods:
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
    
    /// Convert count and unit directly without needing an InventoryItem
    static func convertCount(_ count: Double, from sourceUnits: InventoryUnits) -> (count: Double, unit: String) {
        // Only convert weight units, leave others as-is
        switch sourceUnits {
        case .pounds, .kilograms, .ounces, .grams:
            // Stage 1: Normalize small units to large units
            let normalizedCount: Double
            let normalizedWeightUnit: WeightUnit
            
            switch sourceUnits {
            case .ounces:
                // Convert ounces to pounds (1 lb = 16 oz)
                normalizedCount = count / 16.0
                normalizedWeightUnit = .pounds
            case .grams:
                // Convert grams to kilograms (1 kg = 1000 g)
                normalizedCount = count / 1000.0
                normalizedWeightUnit = .kilograms
            case .pounds:
                normalizedCount = count
                normalizedWeightUnit = .pounds
            case .kilograms:
                normalizedCount = count
                normalizedWeightUnit = .kilograms
            default:
                normalizedCount = count
                normalizedWeightUnit = .pounds // fallback
            }
            
            // Stage 2: Convert to user's preferred weight system (pounds ↔ kilograms)
            let preferredWeightUnit = WeightUnitPreference.current
            let convertedCount = normalizedWeightUnit.convert(normalizedCount, to: preferredWeightUnit)
            let displayUnit = preferredWeightUnit.symbol
            
            return (count: convertedCount, unit: displayUnit)
            
        case .rods:
            return (count: count, unit: sourceUnits.displayName)
        }
    }
    
    /// Convert count and get display info for an inventory item
    static func displayInfo(for item: InventoryItem) -> (count: Double, unit: String) {
        return convertCount(item.count, from: item.unitsKind)
    }
}
