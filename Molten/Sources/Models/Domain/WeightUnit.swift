import Foundation

// MARK: - Container Input Mode

/// Input mode for weight-based inventory types (frit, powder, enamel)
/// Controls whether the user primarily enters quantity by jars or by weight
enum ContainerInputMode: String, CaseIterable, Identifiable {
    case jars
    case weight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .jars: return "Jars"
        case .weight: return "Weight"
        }
    }
}

/// Centralized access to the stored container input mode preference
struct ContainerInputModePreference {
    nonisolated static let storageKey = "defaultContainerInputMode"

    // Private storage for dependency injection during testing - using a lock for thread safety
    private nonisolated(unsafe) static var _userDefaults: UserDefaults? = nil
    private nonisolated static let lock = NSLock()

    private nonisolated static var userDefaults: UserDefaults {
        lock.lock()
        defer { lock.unlock() }

        // If a custom UserDefaults has been set (for testing), use it
        if let customDefaults = _userDefaults {
            return customDefaults
        }

        // Use isolated UserDefaults during testing to prevent Core Data conflicts
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let testSuiteName = "Test_ContainerInputModePreference_\(storageKey)"
            return UserDefaults(suiteName: testSuiteName) ?? UserDefaults.standard
        } else {
            return UserDefaults.standard
        }
    }

    /// Get the current container input mode preference (default: jars)
    nonisolated static var current: ContainerInputMode {
        let defaults = userDefaults
        guard let raw = defaults.string(forKey: storageKey), !raw.isEmpty else {
            // No preference set - default to jars (per user request)
            return .jars
        }

        return ContainerInputMode(rawValue: raw) ?? .jars
    }

    /// Set the container input mode preference
    nonisolated static func setCurrent(_ mode: ContainerInputMode) {
        let defaults = userDefaults
        defaults.set(mode.rawValue, forKey: storageKey)
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
        _userDefaults = nil
    }
}

// MARK: - Weight Unit

/// Units for weight measurements
enum WeightUnit: String, CaseIterable, Identifiable {
    case ounces
    case grams

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ounces: return "Ounces"
        case .grams: return "Grams"
        }
    }

    /// Short symbol for display alongside numeric values
    var symbol: String {
        switch self {
        case .ounces: return "oz"
        case .grams: return "g"
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
        case (.ounces, .grams):
            return value * 28.3495 // 1 oz = 28.3495 g
        case (.grams, .ounces):
            return value / 28.3495 // 1 g = 0.03527 oz
        default:
            return value
        }
    }
}

/// Centralized access to the stored weight unit preference
struct WeightUnitPreference {
    nonisolated static let storageKey = "defaultUnits"
    
    // Private storage for dependency injection during testing - using a lock for thread safety
    private nonisolated(unsafe) static var _userDefaults: UserDefaults? = nil
    private nonisolated static let lock = NSLock()
    
    private nonisolated static var userDefaults: UserDefaults {
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
            // No preference set - default to grams
            return .grams
        }

        // Convert from DefaultUnits to WeightUnit
        switch raw {
        case "Ounces":
            return .ounces
        case "Grams":
            return .grams
        default:
            // Invalid preference - default to grams
            return .grams
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
        case .ounces:
            return "oz"
        case .grams:
            return "g"
        case .shorts:
            return "Shorts"
        case .rods:
            return units.displayName
        }
    }

    /// Get the CatalogUnits case that matches the current weight unit preference
    static func preferredWeightUnit() -> CatalogUnits {
        switch WeightUnitPreference.current {
        case .ounces:
            return .ounces
        case .grams:
            return .grams
        }
    }

    /// Convert count and unit directly without needing an InventoryItem
    static func convertCount(_ count: Double, from sourceUnits: CatalogUnits) -> (count: Double, unit: String) {
        // Only convert weight units, leave others as-is
        switch sourceUnits {
        case .ounces, .grams:
            // Stage 1: Get the normalized weight unit (no small units to convert from)
            let normalizedCount = count
            let normalizedWeightUnit: WeightUnit

            switch sourceUnits {
            case .ounces:
                normalizedWeightUnit = .ounces
            case .grams:
                normalizedWeightUnit = .grams
            default:
                normalizedWeightUnit = .grams // fallback
            }

            // Stage 2: Convert to user's preferred weight system (ounces ↔ grams)
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
