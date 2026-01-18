//
//  CatalogFlagModel.swift
//  Molten
//
//  Created on 2025-12-21.
//
//  Domain models for catalog flags - constraints and properties of glass items
//  that help users understand how to work with specific materials.
//

import Foundation

// MARK: - Flag Key Definitions

/// Predefined flag keys for glass item constraints and properties
/// New flags can be added by extending this enum
enum GlassFlagKey: String, Codable, CaseIterable, Sendable {
    // Boolean flags (flag_value = true/false, flag_numeric = nil)
    case noDeepEncase = "no_deep_encase"
    case beginnerColor = "beginner_color"
    case advancedColor = "advanced_color"
    case canDeepEncase = "can_deep_encase"
    case needsLongAnneal = "needs_long_anneal"
    case needsShortAnneal = "needs_short_anneal"
    case colorMaturesInKiln = "color_matures_in_kiln"
    case strikingColor = "striking_color"
    case mottledColor = "mottled_color"
    case reductionColor = "reduction_color"
    case reactive = "reactive"
    case reactsWithSilver = "reacts_with_silver"
    case reactsWithCopper = "reacts_with_copper"
    case shocky = "shocky"
    case boilsEasily = "boils_easily"
    case devitrifies = "devitrifies"
    case sensitiveToCoolingRate = "sensitive_to_cooling_rate"
    case containsSilver = "contains_silver"
    case goodStringers = "good_for_stringers"
    case transparent = "transparent"
    case translucent = "translucent"
    case opaque = "opaque"
    case meltsSmoothly = "melts_smoothly"
    case meltNeutralOxidizing = "melt_neutral_oxidizing"
    case neutralFlame = "neutral_flame"
    case oxidizingFlame = "oxidizing_flame"
    case heatSlowly = "heat_slowly"
    case cadmium = "cadmium"
    case etchesPoorly = "etches_poorly"
    case thinsWhenStretched = "thins_when_stretched"
    case containsSparkles = "contains_sparkles"
    case glowsInDark = "glows_in_dark"
    case experimental = "experimental"
    case discontinued = "discontinued"
    case metallicLuster = "metallic_luster"

    // Parametric flags (flag_value = true/false, flag_numeric = value)
    case customAnnealTemp = "custom_anneal_temp"
    case maxWorkingTemp = "max_working_temp"
    case holdTime = "hold_time"
    case rampDownRate = "ramp_down_rate"

    /// Whether this flag type requires a numeric value
    nonisolated var requiresNumericValue: Bool {
        switch self {
        case .customAnnealTemp, .maxWorkingTemp, .holdTime, .rampDownRate:
            return true
        default:
            return false
        }
    }

    /// Human-readable display name
    nonisolated var displayName: String {
        switch self {
        case .noDeepEncase: return "Don't deep-encase"
        case .canDeepEncase: return "Can be deep-encased"
        case .beginnerColor: return "Beginner color"
        case .advancedColor: return "Advanced color"
        case .needsLongAnneal: return "Needs long anneal"
        case .needsShortAnneal: return "Needs short anneal"
        case .colorMaturesInKiln: return "Color matures in kiln"
        case .strikingColor: return "Striking color"
        case .reductionColor: return "Reduction color"
        case .mottledColor: return "Multicolored/Mottled/Variegated"
        case .reactive: return "Reactive"
        case .reactsWithSilver: return "Reacts with silver"
        case .reactsWithCopper: return "Reacts with copper"
        case .shocky: return "Shocky (thermal shock prone)"
        case .boilsEasily: return "Boils easily"
        case .devitrifies: return "Prone to devitrification"
        case .sensitiveToCoolingRate: return "Sensitive to cooling rate"
        case .containsSilver: return "Contains silver"
        case .goodStringers: return "Good for stringers (stretches thin well)"
        case .transparent: return "Transparent"
        case .translucent: return "Translucent"
        case .opaque: return "Opaque"
        case .meltsSmoothly: return "Melts smoothly"
        case .meltNeutralOxidizing: return "Use Neutral to Oxidizing Flame"
        case .neutralFlame: return "Neutral flame"
        case .oxidizingFlame: return "Oxidizing flame"
        case .heatSlowly: return "Heat slowly"
        case .cadmium: return "Contains cadmium"
        case .etchesPoorly: return "Etches poorly"
        case .thinsWhenStretched: return "Thins when stretched"
        case .containsSparkles: return "Contains sparkles"
        case .glowsInDark: return "Glows in the dark"
        case .experimental: return "Experimental/test"
        case .discontinued: return "Discontinued/Limited"
        case .metallicLuster: return "Metallic/luster finish"

        case .customAnnealTemp: return "Custom anneal temperature"
        case .maxWorkingTemp: return "Max working temperature"
        case .holdTime: return "Hold time"
        case .rampDownRate: return "Ramp down rate"
        }
    }

    /// Unit suffix for numeric values (nil for boolean flags)
    nonisolated var valueUnit: String? {
        switch self {
        case .customAnnealTemp, .maxWorkingTemp: return "°F"
        case .holdTime: return "min"
        case .rampDownRate: return "°F/hr"
        default: return nil
        }
    }
}

// MARK: - Admin Flag Model

/// Special flag key for description replacement (hidden from flags UI)
let kDescriptionReplacementKey = "__description__"

/// Special flag key for marking an item as processed/reviewed (hidden from flags UI)
let kProcessedKey = "__processed__"

/// Admin-created catalog flag (for catalog contributions)
/// Stored in CloudKit, exported to JSON for incorporation into catalog
/// Can represent either an addition (is_removal = false) or removal (is_removal = true) of a flag
struct CatalogFlagAdminModel: Identifiable, Equatable, Hashable, Sendable {
    nonisolated let id: UUID
    nonisolated let item_stable_id: String
    nonisolated let flag_key: String
    nonisolated let flag_value: Bool
    nonisolated let flag_numeric: Double?
    nonisolated let description_replacement: String?
    nonisolated let is_removal: Bool
    nonisolated let created_at: Date
    nonisolated let updated_at: Date

    nonisolated init(
        id: UUID = UUID(),
        item_stable_id: String,
        flag_key: String,
        flag_value: Bool = true,
        flag_numeric: Double? = nil,
        description_replacement: String? = nil,
        is_removal: Bool = false,
        created_at: Date = Date(),
        updated_at: Date = Date()
    ) {
        self.id = id
        self.item_stable_id = item_stable_id
        self.flag_key = flag_key
        self.flag_value = flag_value
        self.flag_numeric = flag_numeric
        self.description_replacement = description_replacement
        self.is_removal = is_removal
        self.created_at = created_at
        self.updated_at = updated_at
    }

    /// Convenience initializer with typed flag key
    nonisolated init(
        id: UUID = UUID(),
        item_stable_id: String,
        flagKey: GlassFlagKey,
        flag_value: Bool = true,
        flag_numeric: Double? = nil,
        is_removal: Bool = false
    ) {
        self.init(
            id: id,
            item_stable_id: item_stable_id,
            flag_key: flagKey.rawValue,
            flag_value: flag_value,
            flag_numeric: flag_numeric,
            is_removal: is_removal
        )
    }

    /// Get typed flag key if it matches a known key
    nonisolated var typedFlagKey: GlassFlagKey? {
        GlassFlagKey(rawValue: flag_key)
    }

    /// Display value for the flag
    nonisolated var displayValue: String {
        guard let key = typedFlagKey else {
            return flag_key
        }

        if let numeric = flag_numeric, let unit = key.valueUnit {
            let formattedValue = numeric.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", numeric)
                : String(format: "%.1f", numeric)
            return "\(key.displayName): \(formattedValue)\(unit)"
        }

        return key.displayName
    }

    // MARK: - Validation

    nonisolated var isValid: Bool {
        guard !item_stable_id.isEmpty, !flag_key.isEmpty else {
            return false
        }

        // If it's a known parametric flag, require numeric value
        if let key = typedFlagKey, key.requiresNumericValue {
            return flag_numeric != nil
        }

        return true
    }
}

// MARK: - User Flag Model

/// User-created catalog flag (personal corrections/additions)
/// Stored in CloudKit, syncs across user's devices
struct CatalogFlagUserModel: Identifiable, Equatable, Hashable, Sendable {
    nonisolated let id: UUID
    nonisolated let item_stable_id: String
    nonisolated let flag_key: String
    nonisolated let flag_value: Bool
    nonisolated let flag_numeric: Double?
    nonisolated let created_at: Date
    nonisolated let updated_at: Date

    nonisolated init(
        id: UUID = UUID(),
        item_stable_id: String,
        flag_key: String,
        flag_value: Bool = true,
        flag_numeric: Double? = nil,
        created_at: Date = Date(),
        updated_at: Date = Date()
    ) {
        self.id = id
        self.item_stable_id = item_stable_id
        self.flag_key = flag_key
        self.flag_value = flag_value
        self.flag_numeric = flag_numeric
        self.created_at = created_at
        self.updated_at = updated_at
    }

    /// Convenience initializer with typed flag key
    nonisolated init(
        id: UUID = UUID(),
        item_stable_id: String,
        flagKey: GlassFlagKey,
        flag_value: Bool = true,
        flag_numeric: Double? = nil
    ) {
        self.init(
            id: id,
            item_stable_id: item_stable_id,
            flag_key: flagKey.rawValue,
            flag_value: flag_value,
            flag_numeric: flag_numeric
        )
    }

    /// Get typed flag key if it matches a known key
    nonisolated var typedFlagKey: GlassFlagKey? {
        GlassFlagKey(rawValue: flag_key)
    }

    /// Display value for the flag
    nonisolated var displayValue: String {
        guard let key = typedFlagKey else {
            return flag_key
        }

        if let numeric = flag_numeric, let unit = key.valueUnit {
            let formattedValue = numeric.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", numeric)
                : String(format: "%.1f", numeric)
            return "\(key.displayName): \(formattedValue)\(unit)"
        }

        return key.displayName
    }

    // MARK: - Validation

    nonisolated var isValid: Bool {
        guard !item_stable_id.isEmpty, !flag_key.isEmpty else {
            return false
        }

        // If it's a known parametric flag, require numeric value
        if let key = typedFlagKey, key.requiresNumericValue {
            return flag_numeric != nil
        }

        return true
    }
}

// MARK: - Bundled Flag Model

/// Bundled catalog flag (read-only, ships with the app)
/// These are AI-generated flags stored in catalog.sqlite
struct CatalogFlagBundledModel: Identifiable, Equatable, Hashable, Sendable {
    nonisolated let id: Int  // SQLite row ID
    nonisolated let item_stable_id: String
    nonisolated let flag_key: String
    nonisolated let flag_value: Bool
    nonisolated let flag_numeric: Double?

    nonisolated init(
        id: Int,
        item_stable_id: String,
        flag_key: String,
        flag_value: Bool = true,
        flag_numeric: Double? = nil
    ) {
        self.id = id
        self.item_stable_id = item_stable_id
        self.flag_key = flag_key
        self.flag_value = flag_value
        self.flag_numeric = flag_numeric
    }

    /// Get typed flag key if it matches a known key
    nonisolated var typedFlagKey: GlassFlagKey? {
        GlassFlagKey(rawValue: flag_key)
    }

    /// Display value for the flag
    nonisolated var displayValue: String {
        guard let key = typedFlagKey else {
            return flag_key
        }

        if let numeric = flag_numeric, let unit = key.valueUnit {
            let formattedValue = numeric.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", numeric)
                : String(format: "%.1f", numeric)
            return "\(key.displayName): \(formattedValue)\(unit)"
        }

        return key.displayName
    }
}

// MARK: - Export Models

/// Export format for admin flags (for molten-data pipeline)
struct CatalogFlagExport: Codable, Sendable {
    nonisolated let version: String
    nonisolated let exported_at: String
    nonisolated let flags: [ExportedFlag]
    nonisolated let description_replacements: [ExportedDescriptionReplacement]

    struct ExportedFlag: Codable, Sendable {
        nonisolated let item_stable_id: String
        nonisolated let flag_key: String
        nonisolated let flag_value: Bool
        nonisolated let flag_numeric: Double?
    }

    struct ExportedDescriptionReplacement: Codable, Sendable {
        nonisolated let item_stable_id: String
        nonisolated let description: String
    }

    nonisolated init(flags: [CatalogFlagAdminModel], descriptionReplacements: [CatalogFlagAdminModel] = []) {
        self.version = "1.0"
        let formatter = ISO8601DateFormatter()
        self.exported_at = formatter.string(from: Date())
        self.flags = flags.map { flag in
            ExportedFlag(
                item_stable_id: flag.item_stable_id,
                flag_key: flag.flag_key,
                flag_value: flag.flag_value,
                flag_numeric: flag.flag_numeric
            )
        }
        self.description_replacements = descriptionReplacements.compactMap { flag in
            guard let desc = flag.description_replacement else { return nil }
            return ExportedDescriptionReplacement(
                item_stable_id: flag.item_stable_id,
                description: desc
            )
        }
    }
}
