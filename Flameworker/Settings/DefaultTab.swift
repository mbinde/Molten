//
//  DefaultTab.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import Foundation

enum DefaultTab: Int, CaseIterable {
    case catalog = 0
    case inventory = 1
    case purchases = 2
    case projectLog = 3
    case settings = 4
    
    var displayName: String {
        switch self {
        case .catalog:
            return "Catalog"
        case .inventory:
            return "Inventory"
        case .purchases:
            return "Purchases"
        case .projectLog:
            return "Project Log"
        case .settings:
            return "Settings"
        }
    }
    
    var systemImage: String {
        switch self {
        case .catalog:
            return "text.justify" // Looks like multiple horizontal lines (rods)
        case .inventory:
            return "archivebox"
        case .purchases:
            return "creditcard"
        case .projectLog:
            return "book.pages" // Consistent with existing MainTabView  
        case .settings:
            return "gear" // Consistent with existing MainTabView
        }
    }
}
