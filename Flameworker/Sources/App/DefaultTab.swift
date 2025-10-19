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
    case shopping = 2
    case purchases = 3
    case projectPlans = 4
    case projectLog = 5
    case settings = 6

    var displayName: String {
        switch self {
        case .catalog:
            return "Catalog"
        case .inventory:
            return "Inventory"
        case .shopping:
            return "Shopping"
        case .purchases:
            return "Purchases"
        case .projectPlans:
            return "Plans"
        case .projectLog:
            return "Logs"
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
        case .shopping:
            return "cart"
        case .purchases:
            return "creditcard"
        case .projectPlans:
            return "pencil.and.list.clipboard" // Planning icon
        case .projectLog:
            return "book.pages" // Consistent with existing MainTabView
        case .settings:
            return "gear" // Consistent with existing MainTabView
        }
    }
}
