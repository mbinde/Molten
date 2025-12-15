//
//  ProFeatures.swift
//  Molten
//
//  Shared definition of Pro features for paywall and subscription views
//

import Foundation

/// Defines a Pro feature with its display properties
struct ProFeatureItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let freeLimit: String?

    /// Description for paywall (combines title context with limit)
    var paywallDescription: String {
        freeLimit ?? "Only Included with Pro"
    }
}

/// Centralized list of Pro features for display in UI
enum ProFeaturesList {
    /// Core features always shown
    static var core: [ProFeatureItem] {
        [
            ProFeatureItem(icon: "text.justify", title: "4000+ item Catalog", freeLimit: "Always Free"),
            ProFeatureItem(icon: "archivebox.fill", title: "Unlimited Inventory", freeLimit: "Free: 25 items"),
            ProFeatureItem(icon: "cart.fill", title: "Unlimited Shopping Lists", freeLimit: "Free: 10 items"),
            ProFeatureItem(icon: "creditcard.fill", title: "Unlimited Purchase History", freeLimit: "Free: 10 purchase records"),
        ]
    }

    /// Project-related features (shown when ENABLE_PROJECTS is true)
    static var projects: [ProFeatureItem] {
        [
            ProFeatureItem(icon: "folder.fill", title: "Unlimited Projects", freeLimit: "Free: 5 projects"),
            ProFeatureItem(icon: "book.fill", title: "Unlimited Logbook Entries", freeLimit: "Free: 10 entries"),
        ]
    }

    /// Features without limits (always Pro-only)
    static var proOnly: [ProFeatureItem] {
        [
            ProFeatureItem(icon: "clock.arrow.circlepath", title: "Versioned Cloud Backups", freeLimit: nil),
        ]
    }

    /// All features respecting current feature flags
    static var all: [ProFeatureItem] {
        var features = core
        if FeatureFlags.ENABLE_PROJECTS {
            features.append(contentsOf: projects)
        }
        features.append(contentsOf: proOnly)
        return features
    }
}
