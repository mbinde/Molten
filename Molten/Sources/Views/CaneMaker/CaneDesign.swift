//
//  CaneDesign.swift
//  Molten
//
//  Model representing a complete twisted cane design with segments and twist parameters.
//

import SwiftUI
import Observation

/// Observable model for a twisted cane design
@Observable
class CaneDesign {
    /// The color segments arranged around the circumference
    var segments: [CaneSegment]

    /// Total twist in complete rotations (1.0 = 360 degrees)
    /// This represents how many times the cane rotates over its visible length
    var twistRotations: Double

    /// The visual length of the cane being displayed (in arbitrary units)
    var displayLength: Double

    /// Stretch factor (1.0 = original diameter, 0.5 = stretched to half diameter)
    /// When glass is pulled/stretched, the diameter decreases as length increases.
    /// Volume is conserved: original_r² × original_L = new_r² × new_L
    /// So if stretchFactor = 0.5, diameter is 50% and the twist appears tighter
    /// because the same number of rotations are now spread over a thinner rod.
    var stretchFactor: Double

    init(
        segments: [CaneSegment] = CaneDesign.defaultSegments(),
        twistRotations: Double = 1.0,
        displayLength: Double = 200,
        stretchFactor: Double = 1.0
    ) {
        self.segments = segments
        self.twistRotations = twistRotations
        self.displayLength = displayLength
        self.stretchFactor = stretchFactor
    }

    /// Total twist angle in radians
    var totalTwistRadians: Double {
        twistRotations * 2 * .pi
    }

    /// Twist rate (radians per unit length)
    var twistRate: Double {
        totalTwistRadians / displayLength
    }

    /// Default starting design: 4 alternating color segments
    static func defaultSegments() -> [CaneSegment] {
        let colors: [Color] = [
            GlassColor.white.color,
            GlassColor.blue.color,
            GlassColor.white.color,
            GlassColor.blue.color
        ]
        let angularWidth = (2 * .pi) / Double(colors.count)
        return colors.map { CaneSegment(color: $0, angularWidth: angularWidth) }
    }

    /// Add a new segment, redistributing angular widths equally
    func addSegment(color: Color) {
        segments.append(CaneSegment(color: color, angularWidth: 0))
        redistributeWidths()
    }

    /// Remove a segment by ID, redistributing angular widths
    func removeSegment(id: UUID) {
        segments.removeAll { $0.id == id }
        if !segments.isEmpty {
            redistributeWidths()
        }
    }

    /// Redistribute angular widths equally among all segments
    func redistributeWidths() {
        guard !segments.isEmpty else { return }
        let equalWidth = (2 * .pi) / Double(segments.count)
        for i in segments.indices {
            segments[i].angularWidth = equalWidth
        }
    }

    /// Get the starting angle for a segment at the given index
    func startAngle(for index: Int) -> Double {
        var angle = 0.0
        for i in 0..<index {
            angle += segments[i].angularWidth
        }
        return angle
    }

    /// Get the ending angle for a segment at the given index
    func endAngle(for index: Int) -> Double {
        startAngle(for: index) + segments[index].angularWidth
    }
}
