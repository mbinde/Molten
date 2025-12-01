//
//  PageFormatFilter.swift
//  Molten
//
//  Page format type for label filtering (US Letter vs A4)
//

import Foundation

/// Page format options for filtering labels
enum LabelPageFormat: String, CaseIterable, Identifiable {
    case all = "all"
    case letter = "letter"
    case a4 = "a4"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .letter: return "Letter"
        case .a4: return "A4"
        }
    }

    /// The database value to filter by (nil for "all")
    var databaseValue: String? {
        switch self {
        case .all: return nil
        case .letter: return "letter"
        case .a4: return "a4"
        }
    }
}
