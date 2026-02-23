//
//  ColorDistance.swift
//  Molten
//
//  Utilities for calculating perceptual color distance and matching colors.
//  Uses LAB color space for more accurate human perception matching.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Utilities for color distance calculation and matching
enum ColorDistance {

    // MARK: - LAB Color Space

    /// LAB color representation for perceptual color matching
    struct LABColor {
        let L: Double  // Lightness (0-100)
        let a: Double  // Green-Red axis (-128 to 127)
        let b: Double  // Blue-Yellow axis (-128 to 127)
    }

    /// Convert RGB (0-1 range) to XYZ color space
    private static func rgbToXYZ(r: Double, g: Double, b: Double) -> (x: Double, y: Double, z: Double) {
        // Apply gamma correction
        func gammaCorrect(_ c: Double) -> Double {
            if c > 0.04045 {
                return pow((c + 0.055) / 1.055, 2.4)
            } else {
                return c / 12.92
            }
        }

        let r2 = gammaCorrect(r) * 100
        let g2 = gammaCorrect(g) * 100
        let b2 = gammaCorrect(b) * 100

        // sRGB to XYZ matrix
        let x = r2 * 0.4124564 + g2 * 0.3575761 + b2 * 0.1804375
        let y = r2 * 0.2126729 + g2 * 0.7151522 + b2 * 0.0721750
        let z = r2 * 0.0193339 + g2 * 0.1191920 + b2 * 0.9503041

        return (x, y, z)
    }

    /// Convert XYZ to LAB color space
    private static func xyzToLAB(x: Double, y: Double, z: Double) -> LABColor {
        // D65 reference white
        let refX = 95.047
        let refY = 100.0
        let refZ = 108.883

        func f(_ t: Double) -> Double {
            if t > 0.008856 {
                return pow(t, 1.0 / 3.0)
            } else {
                return (7.787 * t) + (16.0 / 116.0)
            }
        }

        let fx = f(x / refX)
        let fy = f(y / refY)
        let fz = f(z / refZ)

        let L = (116.0 * fy) - 16.0
        let a = 500.0 * (fx - fy)
        let b = 200.0 * (fy - fz)

        return LABColor(L: L, a: a, b: b)
    }

    /// Convert SwiftUI Color to LAB
    static func colorToLAB(_ color: Color) -> LABColor? {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }
        let xyz = rgbToXYZ(r: Double(r), g: Double(g), b: Double(b))
        return xyzToLAB(x: xyz.x, y: xyz.y, z: xyz.z)
        #else
        return nil
        #endif
    }

    /// Convert hex color string to LAB
    static func hexToLAB(_ hex: String) -> LABColor? {
        guard let (r, g, b) = hexToRGB(hex) else { return nil }
        let xyz = rgbToXYZ(r: r, g: g, b: b)
        return xyzToLAB(x: xyz.x, y: xyz.y, z: xyz.z)
    }

    /// Parse hex color string to RGB (0-1 range)
    static func hexToRGB(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        return (r, g, b)
    }

    // MARK: - Distance Calculation

    /// Calculate Delta E (CIE76) distance between two LAB colors
    /// Returns value from 0 (identical) to ~100+ (very different)
    static func deltaE(_ lab1: LABColor, _ lab2: LABColor) -> Double {
        let dL = lab1.L - lab2.L
        let da = lab1.a - lab2.a
        let db = lab1.b - lab2.b
        return sqrt(dL * dL + da * da + db * db)
    }

    /// Calculate minimum distance from a target color to any of the hex colors
    /// - Parameters:
    ///   - targetColor: The color to match against
    ///   - hexColors: Array of hex color strings (e.g., ["#FF0000", "#00FF00"])
    /// - Returns: Minimum distance, or nil if no valid colors
    static func minimumDistance(from targetColor: Color, to hexColors: [String]) -> Double? {
        guard let targetLAB = colorToLAB(targetColor) else { return nil }

        var minDistance: Double?

        for hex in hexColors {
            guard let hexLAB = hexToLAB(hex) else { continue }
            let distance = deltaE(targetLAB, hexLAB)

            if minDistance == nil || distance < minDistance! {
                minDistance = distance
            }
        }

        return minDistance
    }

    // MARK: - Matching

    /// Thresholds for color matching (Delta E values)
    enum MatchThreshold: Double {
        case exact = 5.0        // Nearly indistinguishable
        case close = 15.0       // Noticeable but similar
        case similar = 30.0     // Same general color family
        case loose = 50.0       // Broadly similar
        case veryLoose = 75.0   // Same quadrant of color wheel
    }

    /// Threshold for considering glass as "high spread" (rainbow/reactive)
    static let highSpreadThreshold: Double = 50.0

    /// Check if an item matches the color search criteria
    /// - Parameters:
    ///   - dominantColors: The item's dominant colors (hex strings)
    ///   - colorSpread: The item's color spread value (nil if unknown)
    ///   - targetColor: The color being searched for
    ///   - tolerance: Maximum acceptable distance (0-100 scale)
    ///   - includeHighSpread: Whether to include high-spread items regardless of match
    /// - Returns: Whether the item matches
    static func itemMatches(
        dominantColors: [String]?,
        colorSpread: Double?,
        targetColor: Color,
        tolerance: Double,
        includeHighSpread: Bool
    ) -> Bool {
        // No colors = no match
        guard let colors = dominantColors, !colors.isEmpty else {
            return false
        }

        // Check if this is a high-spread item
        let isHighSpread = (colorSpread ?? 0) > highSpreadThreshold

        // If high spread and we're including them, always include
        if isHighSpread && includeHighSpread {
            return true
        }

        // Calculate minimum distance to any dominant color
        guard let distance = minimumDistance(from: targetColor, to: colors) else {
            return false
        }

        // Match if within tolerance
        return distance <= tolerance
    }

    /// Sort items by color match quality (best matches first)
    /// - Parameters:
    ///   - items: Items with dominant_colors
    ///   - targetColor: Color to sort by
    /// - Returns: Items sorted by distance (closest first), with distance values
    static func sortedByDistance<T>(
        items: [T],
        targetColor: Color,
        dominantColors: (T) -> [String]?
    ) -> [(item: T, distance: Double)] {
        var results: [(item: T, distance: Double)] = []

        for item in items {
            if let colors = dominantColors(item),
               let distance = minimumDistance(from: targetColor, to: colors) {
                results.append((item, distance))
            }
        }

        return results.sorted { $0.distance < $1.distance }
    }
}
