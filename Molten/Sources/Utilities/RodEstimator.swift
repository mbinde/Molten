//
//  RodEstimator.swift
//  Molten
//
//  Estimates rod count from weight-based purchases using glass density
//  and standard rod dimensions by COE.
//

import Foundation

/// Standard rod dimensions (length and diameter)
public struct RodDimensions: Sendable {
    /// Length in centimeters
    public let lengthCm: Double
    /// Diameter in millimeters
    public let diameterMm: Double

    public init(lengthCm: Double, diameterMm: Double) {
        self.lengthCm = lengthCm
        self.diameterMm = diameterMm
    }

    /// Length in inches (for display)
    public var lengthInches: Double {
        lengthCm / 2.54
    }
}

/// Weight unit parsed from receipt items (different from the user preference WeightUnit)
public enum ReceiptWeightUnit: String, CaseIterable, Sendable {
    case grams = "G"
    case ounces = "OZ"
    case pounds = "LB"
    case kilograms = "KG"
    case quarterPound = "1/4 LB"
    case halfPound = "1/2 LB"
    case each = "EA"  // Not a weight unit, but we need to handle it

    /// Parse a quantity unit string into a ReceiptWeightUnit
    /// Handles both simple units ("1/4 LB") and variant strings ("5-7mm / 1/4lb")
    public static func parse(_ string: String?) -> ReceiptWeightUnit? {
        guard let string = string?.uppercased().trimmingCharacters(in: .whitespaces) else {
            return nil
        }

        // Direct matches
        if let direct = ReceiptWeightUnit(rawValue: string) {
            return direct
        }

        // Common variations - exact match
        switch string {
        case "GRAM", "GRAMS":
            return .grams
        case "OUNCE", "OUNCES":
            return .ounces
        case "POUND", "POUNDS", "LBS":
            return .pounds
        case "KILOGRAM", "KILOGRAMS", "KGS":
            return .kilograms
        case "1/4LB", "1/4 POUND", "QUARTER POUND", ".25 LB", "0.25 LB":
            return .quarterPound
        case "1/2LB", "1/2 POUND", "HALF POUND", ".5 LB", "0.5 LB":
            return .halfPound
        case "EACH", "UNIT", "UNITS", "PC", "PCS", "PIECE", "PIECES":
            return .each
        default:
            break
        }

        // Try to extract weight unit from variant strings like "5-7mm / 1/4lb" or "4-7mm / 1oz"
        // Look for patterns containing weight units anywhere in the string

        // Check for quarter pound patterns
        if string.contains("1/4LB") || string.contains("1/4 LB") || string.contains("1/4 POUND") {
            return .quarterPound
        }

        // Check for half pound patterns
        if string.contains("1/2LB") || string.contains("1/2 LB") || string.contains("1/2 POUND") {
            return .halfPound
        }

        // Check for ounce patterns (e.g., "1oz", "1 oz", "4oz")
        if string.range(of: #"\d+\s*OZ"#, options: .regularExpression) != nil {
            return .ounces
        }

        // Check for pound patterns (e.g., "1lb", "1 lb", but not "1/4lb")
        if string.range(of: #"(?<!/)\d+\s*LB"#, options: .regularExpression) != nil {
            return .pounds
        }

        // Check for gram patterns
        if string.range(of: #"\d+\s*G\b"#, options: .regularExpression) != nil ||
           string.range(of: #"\d+\s*GRAM"#, options: .regularExpression) != nil {
            return .grams
        }

        return nil
    }

    /// Convert a quantity in this unit to grams
    public func toGrams(_ quantity: Double) -> Double? {
        switch self {
        case .grams:
            return quantity
        case .ounces:
            return quantity * 28.3495
        case .pounds:
            return quantity * 453.592
        case .kilograms:
            return quantity * 1000.0
        case .quarterPound:
            return quantity * 453.592 * 0.25
        case .halfPound:
            return quantity * 453.592 * 0.5
        case .each:
            return nil  // Can't convert count to weight
        }
    }

    /// Whether this is a weight-based unit (vs count-based like "each")
    public var isWeightBased: Bool {
        self != .each
    }
}

/// Result of rod estimation
public struct RodEstimate: Sendable {
    /// Estimated number of rods (rounded)
    public let rodCount: Int
    /// Price per rod
    public let pricePerRod: Double?
    /// The dimensions used for calculation
    public let dimensions: RodDimensions
    /// Weight per rod in grams
    public let rodWeightGrams: Double

    public init(rodCount: Int, pricePerRod: Double?, dimensions: RodDimensions, rodWeightGrams: Double) {
        self.rodCount = rodCount
        self.pricePerRod = pricePerRod
        self.dimensions = dimensions
        self.rodWeightGrams = rodWeightGrams
    }
}

/// Estimates rod counts from weight-based purchases
public struct RodEstimator: Sendable {

    // MARK: - Constants

    /// Glass density in g/cm³ by COE
    /// - COE 33 (borosilicate): 2.23 g/cm³
    /// - COE 90/96/104 (soda-lime soft glass): ~2.5 g/cm³
    public static let coeDensity: [Int32: Double] = [
        33: 2.23,   // Borosilicate
        90: 2.51,    // Soft glass
        96: 2.51,    // Soft glass
        104: 2.51,   // Soft glass
    ]

    /// Default density for unknown COE (soft glass)
    public static let defaultDensity: Double = 2.51

    /// Default dimensions by COE
    /// - COE 33 (boro): 20" long, 7mm diameter
    /// - COE 90/96/104 (soft glass): 12" long, 6mm diameter
    public static let coeDefaults: [Int32: RodDimensions] = [
        33: RodDimensions(lengthCm: 50.8, diameterMm: 7),   // 20 inches
        90: RodDimensions(lengthCm: 30.5, diameterMm: 6),   // 12 inches
        96: RodDimensions(lengthCm: 30.5, diameterMm: 6),   // 12 inches
        104: RodDimensions(lengthCm: 30.5, diameterMm: 6),  // 12 inches
    ]

    /// Manufacturer-specific overrides (keyed by lowercase manufacturer abbreviation)
    /// Empty for now, but structure is ready for future additions
    public static let manufacturerOverrides: [String: RodDimensions] = [:]

    // MARK: - Calculation

    /// Get dimensions for a given COE and manufacturer
    /// - Parameters:
    ///   - coe: The COE rating
    ///   - manufacturer: Optional manufacturer abbreviation for overrides
    /// - Returns: Rod dimensions, or nil if COE not recognized
    public static func dimensions(forCOE coe: Int32, manufacturer: String? = nil) -> RodDimensions? {
        // Check manufacturer override first
        if let mfr = manufacturer?.lowercased(),
           let override = manufacturerOverrides[mfr] {
            return override
        }

        // Fall back to COE default
        return coeDefaults[coe]
    }

    /// Calculate the weight of a single rod in grams
    /// - Parameters:
    ///   - dimensions: The rod dimensions
    ///   - coe: The COE rating (for density lookup)
    /// - Returns: Weight in grams
    public static func rodWeight(dimensions: RodDimensions, coe: Int32) -> Double {
        // Convert diameter from mm to cm, get radius
        let radiusCm = dimensions.diameterMm / 20.0  // mm to cm, then halve for radius

        // Volume = π × r² × length (all in cm)
        let volumeCm3 = Double.pi * radiusCm * radiusCm * dimensions.lengthCm

        // Get density for this COE
        let density = coeDensity[coe] ?? defaultDensity

        // Weight = volume × density
        return volumeCm3 * density
    }

    /// Estimate rod count from a weight-based purchase
    /// - Parameters:
    ///   - quantity: The quantity purchased
    ///   - unit: The unit string (e.g., "LB", "OZ")
    ///   - totalPrice: Optional total price for per-rod calculation
    ///   - coe: The COE rating of the glass
    ///   - manufacturer: Optional manufacturer for dimension overrides
    /// - Returns: Estimation result, or nil if calculation not possible
    public static func estimate(
        quantity: Double,
        unit: String?,
        totalPrice: Double?,
        coe: Int32,
        manufacturer: String? = nil
    ) -> RodEstimate? {
        // Parse the unit
        guard let weightUnit = ReceiptWeightUnit.parse(unit),
              weightUnit.isWeightBased else {
            return nil  // Can't estimate from non-weight units
        }

        // Get dimensions for this COE
        guard let dimensions = dimensions(forCOE: coe, manufacturer: manufacturer) else {
            return nil  // Unknown COE
        }

        // Convert purchase quantity to grams
        guard let purchaseWeightGrams = weightUnit.toGrams(quantity) else {
            return nil
        }

        // Calculate single rod weight
        let singleRodWeight = rodWeight(dimensions: dimensions, coe: coe)

        // Estimate rod count
        let rawCount = purchaseWeightGrams / singleRodWeight
        let rodCount = max(1, Int(rawCount.rounded()))

        // Calculate price per rod if we have a total price
        let pricePerRod = totalPrice.map { $0 / Double(rodCount) }

        return RodEstimate(
            rodCount: rodCount,
            pricePerRod: pricePerRod,
            dimensions: dimensions,
            rodWeightGrams: singleRodWeight
        )
    }

    /// Estimate rod count for a receipt item with a catalog match
    /// - Parameters:
    ///   - item: The receipt item
    ///   - catalogCOE: The COE from the matched catalog item
    ///   - catalogManufacturer: The manufacturer from the matched catalog item
    /// - Returns: Estimation result, or nil if calculation not possible
    public static func estimate(
        item: ReceiptItem,
        catalogCOE: Int32,
        catalogManufacturer: String?
    ) -> RodEstimate? {
        guard let quantity = item.quantity else {
            return nil
        }

        return estimate(
            quantity: quantity,
            unit: item.quantityUnit,
            totalPrice: item.totalPrice,
            coe: catalogCOE,
            manufacturer: catalogManufacturer
        )
    }
}
