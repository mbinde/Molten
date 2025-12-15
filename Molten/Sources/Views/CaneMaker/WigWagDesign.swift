//
//  WigWagDesign.swift
//  Molten
//
//  Model for wigwag cane design - twisted tube that reverses direction
//

import SwiftUI

/// Represents the state of a wigwag cane being twisted
@Observable
class WigWagDesign {
    /// Color segments around the initial tube (like pie slices)
    var segments: [WigWagSegment] = WigWagDesign.defaultSegments()

    /// History of twist operations - each entry is cumulative twist in radians
    /// Positive = clockwise, negative = counter-clockwise
    /// Each entry represents the twist state at that "moment" as we pull the cane
    var twistHistory: [Double] = [0.0]

    /// Current twist position (radians) - this is what the user is actively changing
    var currentTwist: Double = 0.0

    /// Saved state for undo after revert
    private var undoHistory: [Double]?
    private var undoTwist: Double?

    /// Whether undo is available
    var canUndo: Bool { undoHistory != nil }

    /// How much the tube has been stretched (affects how many "rings" we see)
    /// 1.0 = original size, smaller = more stretched (thinner tube, more rings visible)
    var stretchFactor: Double = 1.0

    /// Number of rings to display in end view (based on twist history)
    var ringCount: Int {
        twistHistory.count
    }

    /// Add current twist state to history (called periodically as user twists)
    func recordTwist() {
        // Only record if twist has changed meaningfully from last recorded
        // 0.01 radians ≈ 0.6° - captures smooth curves
        if let last = twistHistory.last, abs(currentTwist - last) > 0.01 {
            twistHistory.append(currentTwist)
        }
    }

    /// Reset the design
    func reset() {
        twistHistory = [0.0]
        currentTwist = 0.0
        stretchFactor = 1.0
    }

    /// Revert to a specific point in the twist history
    func revertToIndex(_ index: Int) {
        guard index >= 0 && index < twistHistory.count else { return }
        // Save current state for undo
        undoHistory = twistHistory
        undoTwist = currentTwist
        // Truncate history to the selected point
        twistHistory = Array(twistHistory.prefix(index + 1))
        // Set current twist to the value at that point
        currentTwist = twistHistory[index]
    }

    /// Undo the last revert operation
    func undo() {
        guard let history = undoHistory, let twist = undoTwist else { return }
        twistHistory = history
        currentTwist = twist
        undoHistory = nil
        undoTwist = nil
    }

    /// Default starting segments - simple two-color split
    static func defaultSegments() -> [WigWagSegment] {
        [
            WigWagSegment(color: .white, angularWidth: .pi),
            WigWagSegment(color: .black, angularWidth: .pi)
        ]
    }
}

/// A color segment in the wigwag tube
struct WigWagSegment: Identifiable, Equatable {
    let id = UUID()
    var color: Color
    var angularWidth: Double  // in radians, should sum to 2π
}
