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
    case containsCopper = "contains_copper"
    case containsLead = "contains_lead"
    case containsSulfur = "contains_sulfur"
    case containsGold = "contains_gold"
    case copperFree = "copper_free"
    case containsChrome = "contains_chrome"
    case chromeFree = "chrome_free"
    case containsUranium = "contains_uranium"
    case goodStringers = "good_for_stringers"
    case transparent = "transparent"
    case translucent = "translucent"
    case opaque = "opaque"
    case meltsSmoothly = "melts_smoothly"
    case meltNeutralOxidizing = "melt_neutral_oxidizing"
    case neutralFlame = "neutral_flame"
    case oxidizingFlame = "oxidizing_flame"
    case bushySoftFlame = "bushy_soft_flame"
    case heatSlowly = "heat_slowly"
    case cadmium = "cadmium"
    case etchesPoorly = "etches_poorly"
    case thinsWhenStretched = "thins_when_stretched"
    case containsSparkles = "contains_sparkles"
    case containsDichro = "contains_dichro"
    case includesMicroBubbles = "includes_micro_bubbles"
    case glowsInDark = "glows_in_dark"
    case uvReactive = "uv_reactive"
    case cflColorshift = "cfl_colorshift"
    case experimental = "experimental"
    case discontinued = "discontinued"
    case metallicLuster = "metallic_luster"
    case metallicShimmer = "metallic_shimmer"
    case satinSheen = "satin_sheen"
    case patterned = "patterned"
    case speckled = "speckled"
    case textured = "textured"
    case clear = "clear"
    case blackGreyBased = "black_grey_based"
    case blackBlueBased = "black_blue_based"
    case blackPurpleBased = "black_purple_based"
    case blackGreenBased = "black_green_based"
    case blackBrownBased = "black_brown_based"
    case iridescentCoating = "iridescent_coating"
    case iridescentCoatingSilver = "iridescent_coating_silver"
    case bubbleSqueeze = "bubble_squeeze"
    case workCool = "work_cool"
    case multi = "__multi__"

    // Parametric flags (flag_value = true/false, flag_numeric = value)
    case customAnnealTemp = "custom_anneal_temp"
    case maxWorkingTemp = "max_working_temp"
    case garagingTemp = "garaging_temp"
    case holdTime = "hold_time"
    case rampDownRate = "ramp_down_rate"

    /// Whether this flag type requires a numeric value
    nonisolated var requiresNumericValue: Bool {
        switch self {
        case .customAnnealTemp, .maxWorkingTemp, .garagingTemp, .holdTime, .rampDownRate:
            return true
        default:
            return false
        }
    }

    /// Short human-readable display name (for chips/badges)
    nonisolated var displayName: String {
        switch self {
        case .noDeepEncase: return "No encasing"
        case .canDeepEncase: return "Encasable"
        case .beginnerColor: return "Beginner"
        case .advancedColor: return "Advanced"
        case .needsLongAnneal: return "Long anneal"
        case .needsShortAnneal: return "Short anneal"
        case .colorMaturesInKiln: return "Kiln-develops"
        case .strikingColor: return "Striking"
        case .reductionColor: return "Reduction"
        case .mottledColor: return "Mottled"
        case .reactive: return "Reactive"
        case .reactsWithSilver: return "Silver-reactive"
        case .reactsWithCopper: return "Copper-reactive"
        case .shocky: return "Shocky"
        case .boilsEasily: return "Boils easily"
        case .devitrifies: return "Devitrifies"
        case .sensitiveToCoolingRate: return "Cooling-sensitive"
        case .containsSilver: return "Contains silver"
        case .containsCopper: return "Contains copper"
        case .containsLead: return "Contains lead"
        case .containsSulfur: return "Contains sulfur"
        case .containsGold: return "Contains gold"
        case .copperFree: return "Copper-free"
        case .containsChrome: return "Contains chrome"
        case .chromeFree: return "Chrome-free"
        case .containsUranium: return "Uranium glass"
        case .goodStringers: return "Thins well"
        case .transparent: return "Transparent"
        case .translucent: return "Translucent"
        case .opaque: return "Opaque"
        case .meltsSmoothly: return "Smooth melt"
        case .meltNeutralOxidizing: return "Neutral/oxidizing"
        case .neutralFlame: return "Neutral flame"
        case .oxidizingFlame: return "Oxidizing flame"
        case .bushySoftFlame: return "Soft flame"
        case .heatSlowly: return "Heat slowly"
        case .cadmium: return "Contains cadmium"
        case .etchesPoorly: return "Poor etching"
        case .thinsWhenStretched: return "Dilutes"
        case .containsSparkles: return "Sparkles"
        case .containsDichro: return "Dichroic"
        case .includesMicroBubbles: return "Seeded"
        case .glowsInDark: return "Glow-in-dark"
        case .uvReactive: return "UV reactive"
        case .cflColorshift: return "CFL shift"
        case .experimental: return "Experimental"
        case .discontinued: return "Discontinued"
        case .metallicLuster: return "Metallic luster"
        case .metallicShimmer: return "Shimmer"
        case .satinSheen: return "Satin"
        case .patterned: return "Patterned"
        case .speckled: return "Speckled"
        case .textured: return "Textured"
        case .clear: return "Clear"
        case .blackGreyBased: return "Black (grey)"
        case .blackBlueBased: return "Black (blue)"
        case .blackPurpleBased: return "Black (purple)"
        case .blackGreenBased: return "Black (green)"
        case .blackBrownBased: return "Black (brown)"
        case .iridescentCoating: return "Iridescent"
        case .iridescentCoatingSilver: return "Silver iridescent"
        case .bubbleSqueeze: return "Bubble squeeze"
        case .workCool: return "Work cool"
        case .multi: return "Multi-color"

        case .customAnnealTemp: return "Custom anneal"
        case .maxWorkingTemp: return "Max temp"
        case .garagingTemp: return "Garaging temp"
        case .holdTime: return "Hold time"
        case .rampDownRate: return "Ramp down"
        }
    }

    /// Longer, more descriptive display name (for tooltips/details)
    nonisolated var displayNameLong: String {
        switch self {
        case .noDeepEncase: return "Don't deep-encase this color"
        case .canDeepEncase: return "Safe to deep-encase"
        case .beginnerColor: return "Beginner-friendly color"
        case .advancedColor: return "Advanced color (requires experience)"
        case .needsLongAnneal: return "Needs extended annealing time"
        case .needsShortAnneal: return "Can use shorter annealing time"
        case .colorMaturesInKiln: return "Color develops/changes in the kiln"
        case .strikingColor: return "Striking color (develops with heat/time)"
        case .reductionColor: return "Reduction color (develops in reducing flame)"
        case .mottledColor: return "Multicolored, mottled, or variegated appearance"
        case .reactive: return "Reactive glass (interacts with other colors)"
        case .reactsWithSilver: return "Reacts with silver-containing glass"
        case .reactsWithCopper: return "Reacts with copper-containing glass"
        case .shocky: return "Prone to thermal shock - heat and cool carefully"
        case .boilsEasily: return "Tends to boil - use lower heat"
        case .devitrifies: return "Prone to devitrification - work quickly"
        case .sensitiveToCoolingRate: return "Color affected by cooling rate"
        case .containsSilver: return "Contains silver (Raku-style reactions)"
        case .containsCopper: return "Contains copper compounds"
        case .containsLead: return "Contains lead - handle appropriately"
        case .containsSulfur: return "Contains sulfur compounds"
        case .containsGold: return "Contains gold - needs 2hr hold at 1225°F/663°C when fusing"
        case .copperFree: return "Copper-free formulation"
        case .containsChrome: return "Contains chrome compounds"
        case .chromeFree: return "Chrome-free formulation"
        case .containsUranium: return "Contains uranium (vaseline/uranium glass)"
        case .goodStringers: return "Thins well - good for stringers and blowing"
        case .transparent: return "Transparent - light passes through clearly"
        case .translucent: return "Translucent - light passes through diffusely"
        case .opaque: return "Opaque - blocks light"
        case .meltsSmoothly: return "Melts smoothly without bubbling"
        case .meltNeutralOxidizing: return "Best worked in neutral to oxidizing flame"
        case .neutralFlame: return "Work in a neutral flame"
        case .oxidizingFlame: return "Work in an oxidizing flame"
        case .bushySoftFlame: return "Use a bushy, soft flame"
        case .heatSlowly: return "Heat slowly to avoid thermal shock"
        case .cadmium: return "Contains cadmium - ensure ventilation"
        case .etchesPoorly: return "Does not etch well with acid"
        case .thinsWhenStretched: return "Color dilutes/lightens when stretched"
        case .containsSparkles: return "Contains sparkles or aventurine"
        case .containsDichro: return "Contains dichroic coating/particles"
        case .includesMicroBubbles: return "Seeded glass with micro-bubbles"
        case .glowsInDark: return "Phosphorescent - glows in the dark"
        case .uvReactive: return "Fluoresces under UV/blacklight"
        case .cflColorshift: return "Color shifts under CFL/fluorescent lighting"
        case .experimental: return "Experimental or test batch"
        case .discontinued: return "Discontinued, limited availability, or experimental"
        case .metallicLuster: return "Metallic or luster surface finish"
        case .metallicShimmer: return "Subtle metallic shimmer effect"
        case .satinSheen: return "Satin or matte sheen finish"
        case .patterned: return "Patterned glass (streaky, striped, etc.)"
        case .speckled: return "Contains speckles or frits"
        case .textured: return "Has surface texture"
        case .clear: return "Clear/colorless glass"
        case .blackGreyBased: return "Black glass with grey undertones"
        case .blackBlueBased: return "Black glass with blue undertones"
        case .blackPurpleBased: return "Black glass with purple undertones"
        case .blackGreenBased: return "Black glass with green undertones"
        case .blackBrownBased: return "Black glass with brown undertones"
        case .iridescentCoating: return "Rainbow iridescent coating"
        case .iridescentCoatingSilver: return "Silver iridescent coating"
        case .bubbleSqueeze: return "Suitable for bubble squeeze technique (fusing)"
        case .workCool: return "Work at cooler temperatures"
        case .multi: return "Multiple distinct colors (not blended)"

        case .customAnnealTemp: return "Requires custom kiln annealing temperature"
        case .maxWorkingTemp: return "Maximum recommended working temperature"
        case .garagingTemp: return "Recommended garaging temperature"
        case .holdTime: return "Recommended hold time at temperature"
        case .rampDownRate: return "Recommended ramp-down cooling rate"
        }
    }

    /// Unit suffix for numeric values (nil for boolean flags)
    nonisolated var valueUnit: String? {
        switch self {
        case .customAnnealTemp, .maxWorkingTemp, .garagingTemp: return "°F"
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
