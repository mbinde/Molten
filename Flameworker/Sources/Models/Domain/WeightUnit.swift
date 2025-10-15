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
    private static var _userDefaults: UserDefaults? = nil
    private static let lock = NSLock()
    
    private static var userDefaults: UserDefaults {
        lock.lock()
        defer { lock.unlock() }
        
        // If a custom UserDefaults has been set (for testing), use it
        if let customDefaults = _userDefaults {
            return customDefaults
        }
        
        // Use isolated UserDefaults during testing to prevent Core Data conflicts
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let testSuiteName = "Test_WeightUnitPreference_\(storageKey)"
            return UserDefaults(suiteName: testSuiteName) ?? UserDefaults.standard
        } else {
            return UserDefaults.standard
        }
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
        _userDefaults = nil  // Reset to nil so userDefaults computed property determines the appropriate defaults
    }
}

/// Helper for rendering unit names in UI
struct UnitsDisplayHelper {
    static func displayName(for units: CatalogUnits) -> String {
        switch units {
        case .pounds:
            return "lb"
        case .kilograms:
            return "kg"
        case .shorts:
            return "Shorts"
        case .rods:
            return units.displayName
        }
    }
    
    /// Get the CatalogUnits case that matches the current weight unit preference
    static func preferredWeightUnit() -> CatalogUnits {
        switch WeightUnitPreference.current {
        case .pounds:
            return .pounds
        case .kilograms:
            return .kilograms
        }
    }
    
    /// Convert count and unit directly without needing an InventoryItem
    static func convertCount(_ count: Double, from sourceUnits: CatalogUnits) -> (count: Double, unit: String) {
        // Only convert weight units, leave others as-is
        switch sourceUnits {
        case .pounds, .kilograms:
            // Stage 1: Get the normalized weight unit (no small units to convert from)
            let normalizedCount = count
            let normalizedWeightUnit: WeightUnit
            
            switch sourceUnits {
            case .pounds:
                normalizedWeightUnit = .pounds
            case .kilograms:
                normalizedWeightUnit = .kilograms
            default:
                normalizedWeightUnit = .pounds // fallback
            }
            
            // Stage 2: Convert to user's preferred weight system (pounds ↔ kilograms)
            let preferredWeightUnit = WeightUnitPreference.current
            let convertedCount = normalizedWeightUnit.convert(normalizedCount, to: preferredWeightUnit)
            let displayUnit = preferredWeightUnit.symbol
            
            return (count: convertedCount, unit: displayUnit)
            
        case .shorts, .rods:
            return (count: count, unit: sourceUnits.displayName)
        }
    }
    
    /// Convert count and get display info for a repository pattern inventory item
    static func displayInfo(for inventoryModel: InventoryModel, units: CatalogUnits = .rods) -> (count: Double, unit: String) {
        return convertCount(inventoryModel.quantity, from: units)
    }
    
    /// Legacy method for backward compatibility during migration
    /// TODO: Remove this once all Core Data entity usage is eliminated
    static func displayInfoLegacy(count: Double, units: CatalogUnits) -> (count: Double, unit: String) {
        return convertCount(count, from: units)
    }
}
