//
//  CatalogColorHelper.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI

struct CatalogColorHelper {
    // Color scheme for manufacturers
    static func colorForManufacturer(_ manufacturer: String?) -> Color {
        let cleanManufacturer = manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "unknown"
        
        switch cleanManufacturer {
        case "effetre", "moretti":
            return .blue
        case "vetrofond":
            return .green
        case "reichenbach":
            return .purple
        case "double helix":
            return .orange
        case "northstar":
            return .red
        case "glass alchemy":
            return .mint
        case "zimmermann":
            return .yellow
        case "kugler":
            return .pink
        case "unknown":
            return .secondary
        default:
            // Generate a consistent color based on manufacturer name
            let hash = cleanManufacturer.hash
            let colors: [Color] = [.cyan, .indigo, .teal, .brown, .gray]
            return colors[abs(hash) % colors.count]
        }
    }
}
