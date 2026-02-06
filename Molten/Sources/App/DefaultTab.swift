//
//  DefaultTab.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import Foundation

enum DefaultTab: Int, CaseIterable {
    case glass = -1 // Unified glass view (replaces catalog, inventory, shopping)
    case catalog = 0
    case inventory = 1
    case shopping = 2
    case projects = 3
    case purchases = 4 // Kept for backwards compatibility, but disabled in UI
    case projectPlans = 5 // Deprecated - now accessed through projects menu
    case logbook = 6 // Deprecated - now accessed through projects menu
    case recipes = 7
    case locations = 8
    case kilnSchedules = 9
    case caneMaker = 10
    case wigWag = 11
    case settings = 99 // Always sorted last in tab reconciliation

    var displayName: String {
        switch self {
        case .glass:
            return "Supplies"
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
            return "Projects"
        case .logbook:
            return "Logbook"
        case .recipes:
            return "Recipes"
        case .settings:
            return "Settings"
        case .locations:
            return "Locations"
        case .kilnSchedules:
            return "Kiln"
        case .caneMaker:
            return "Twist"
        case .wigWag:
            return "Wig Wag"
        }
    }

    var systemImage: String {
        switch self {
        case .glass:
            return "archivebox" // Same as old Inventory tab for familiarity
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
        case .recipes:
            return "book.closed" // Recipe book icon
        case .settings:
            return "gear" // Consistent with existing MainTabView
        case .locations:
            return "map" // Unified locations view for stores, classes, workshops
        case .kilnSchedules:
            return "fireplace.fill" // Matches Hot Shop terminology
        case .caneMaker:
            return "arrow.triangle.swap" // Represents twisting motion
        case .wigWag:
            return "scribble.variable" // Represents the wavy wigwag pattern
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
