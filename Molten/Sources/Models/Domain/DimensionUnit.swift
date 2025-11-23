import Foundation

/// Units for dimension measurements (length)
enum DimensionUnit: String, CaseIterable, Identifiable {
    case millimeters
    case centimeters
    case inches

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .millimeters: return "Millimeters"
        case .centimeters: return "Centimeters"
        case .inches: return "Inches"
        }
    }

    /// Short symbol for display alongside numeric values
    var symbol: String {
        switch self {
        case .millimeters: return "mm"
        case .centimeters: return "cm"
        case .inches: return "in"
        }
    }

    /// Convert dimension from one unit to another
    func convert(_ value: Double, to targetUnit: DimensionUnit) -> Double {
        if self == targetUnit {
            return value
        }

        // Convert to cm first (our base unit)
        let valueInCm: Double
        switch self {
        case .millimeters:
            valueInCm = value / 10.0 // 1 cm = 10 mm
        case .centimeters:
            valueInCm = value
        case .inches:
            valueInCm = value * 2.54 // 1 inch = 2.54 cm
        }

        // Convert from cm to target unit
        switch targetUnit {
        case .millimeters:
            return valueInCm * 10.0
        case .centimeters:
            return valueInCm
        case .inches:
            return valueInCm / 2.54
        }
    }
}

/// User-facing enum for dimension unit preference (metric vs imperial)
enum DefaultDimensionUnits: String, CaseIterable {
    case metric = "Metric"
    case imperial = "Imperial"

    var displayName: String {
        switch self {
        case .metric: return "Metric (cm/mm)"
        case .imperial: return "Imperial (inches)"
        }
    }

    /// Get the primary dimension unit for this preference
    var primaryUnit: DimensionUnit {
        switch self {
        case .metric: return .centimeters
        case .imperial: return .inches
        }
    }

    /// Get the secondary (smaller) dimension unit for this preference
    var secondaryUnit: DimensionUnit {
        switch self {
        case .metric: return .millimeters
        case .imperial: return .inches // Imperial only uses inches
        }
    }
}

/// Centralized access to the stored dimension unit preference
struct DimensionUnitPreference {
    nonisolated static let storageKey = "defaultDimensionUnits"

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

        // Otherwise use standard UserDefaults
        return UserDefaults.standard
    }

    /// Get the current dimension unit preference
    nonisolated static var current: DefaultDimensionUnits {
        let defaults = userDefaults
        guard let raw = defaults.string(forKey: storageKey), !raw.isEmpty else {
            return .metric  // Default to metric
        }

        return DefaultDimensionUnits(rawValue: raw) ?? .metric
    }

    /// Set the dimension unit preference
    nonisolated static func set(_ units: DefaultDimensionUnits) {
        userDefaults.set(units.rawValue, forKey: storageKey)
    }

    /// Set a custom UserDefaults for testing
    nonisolated static func setUserDefaults(_ defaults: UserDefaults?) {
        lock.lock()
        defer { lock.unlock() }
        _userDefaults = defaults
    }

    /// Reset to standard UserDefaults (for cleaning up after tests)
    nonisolated static func resetUserDefaults() {
        setUserDefaults(nil)
    }
}
