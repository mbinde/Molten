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
    case projects = 3
    case purchases = 4 // Kept for backwards compatibility, but disabled in UI
    case projectPlans = 5 // Deprecated - now accessed through projects menu
    case logbook = 6 // Deprecated - now accessed through projects menu
    case settings = 7

    var displayName: String {
        switch self {
        case .catalog:
            return "Catalog"
        case .inventory:
            return "Inventory"
        case .shopping:
            return "Shopping"
        case .projects:
            return "Projects"
        case .purchases:
            return "Purchases"
        case .projectPlans:
            return "Plans"
        case .logbook:
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
        case .projects:
            return "folder" // Folder icon for grouped projects
        case .purchases:
            return "creditcard"
        case .projectPlans:
            return "pencil.and.list.clipboard" // Planning icon
        case .logbook:
            return "book.pages" // Consistent with existing MainTabView
        case .settings:
            return "gear" // Consistent with existing MainTabView
        }
    }
}

/// Project view type options shown in the projects menu
enum ProjectViewType {
    case plans
    case logs

    var displayName: String {
        switch self {
        case .plans:
            return "Project"
        case .logs:
            return "Project Logs"
        }
    }

    var systemImage: String {
        switch self {
        case .plans:
            return "pencil.and.list.clipboard"
        case .logs:
            return "book.pages"
        }
    }

    var description: String {
        switch self {
        case .plans:
            return "Plan future projects and track materials"
        case .logs:
            return "Record completed projects and notes"
        }
    }
}
