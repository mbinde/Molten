//
//  CaneSegment.swift
//  Molten
//
//  Model for a single color segment in a cane design.
//

import SwiftUI

/// A single color segment in a cane, representing a portion of the circumference
struct CaneSegment: Identifiable, Equatable {
    let id: UUID
    var color: Color
    /// The angular width of this segment (in radians, relative to total circumference)
    var angularWidth: Double

    init(id: UUID = UUID(), color: Color, angularWidth: Double = .pi / 4) {
        self.id = id
        self.color = color
        self.angularWidth = angularWidth
    }
}

/// Default glass colors commonly used in cane making
enum GlassColor: CaseIterable {
    case clear
    case white
    case black
    case red
    case orange
    case yellow
    case green
    case aqua
    case blue
    case purple
    case pink

    var color: Color {
        switch self {
        case .clear: return Color(hex: "E8F4F8").opacity(0.7)
        case .white: return Color(hex: "FAFAFA")
        case .black: return Color(hex: "1A1A1A")
        case .red: return Color(hex: "C62828")
        case .orange: return Color(hex: "EF6C00")
        case .yellow: return Color(hex: "F9A825")
        case .green: return Color(hex: "2E7D32")
        case .aqua: return Color(hex: "00838F")
        case .blue: return Color(hex: "1565C0")
        case .purple: return Color(hex: "6A1B9A")
        case .pink: return Color(hex: "AD1457")
        }
    }

    var name: String {
        switch self {
        case .clear: return "Clear"
        case .white: return "White"
        case .black: return "Black"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .aqua: return "Aqua"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        }
    }
}
