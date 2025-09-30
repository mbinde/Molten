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
    case projectLog = 2
    case settings = 3
    
    var displayName: String {
        switch self {
        case .catalog:
            return "Catalog"
        case .inventory:
            return "Inventory"
        case .projectLog:
            return "Project Log"
        case .settings:
            return "Settings"
        }
    }
    
    var systemImage: String {
        switch self {
        case .catalog:
            return "eyedropper.halffull" // Consistent with existing MainTabView
        case .inventory:
            return "archivebox"
        case .projectLog:
            return "book.pages" // Consistent with existing MainTabView  
        case .settings:
            return "gear" // Consistent with existing MainTabView
        }
    }
}
