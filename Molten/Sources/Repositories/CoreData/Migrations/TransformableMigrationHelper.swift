//
//  TransformableMigrationHelper.swift
//  Molten
//
//  Helper for migrating Transformable attributes to proper Core Data relationships
//  This handles one-time migration from Molten 5 to Molten 6
//

import Foundation
import CoreData

/// Helper for migrating Transformable attributes to Core Data relationships
struct TransformableMigrationHelper {

    // MARK: - Tags Migration (Phase 1)

    /// Migrate tags for a single Logbook
    static func migrateTags(for log: Logbook, in context: NSManagedObjectContext) throws {
        // Get old tags data (will be nil after attribute is removed, but exists during migration)
        guard let oldTagsData = log.value(forKey: "tags") as? Data else { return }

        // Decode old tags array from JSON
        let decoder = JSONDecoder()
        guard let oldTags = try? decoder.decode([String].self, from: oldTagsData) else { return }

        // Create new ProjectTag entities for each tag string
        for tagString in oldTags where !tagString.isEmpty {
            let projectTag = NSEntityDescription.insertNewObject(forEntityName: "ProjectTag", into: context)
            projectTag.setValue(tagString, forKey: "tag")
            projectTag.setValue(Date(), forKey: "dateAdded")
            projectTag.setValue(log, forKey: "log")
        }
    }

    /// Migrate tags for a single Project
    static func migrateTags(for plan: Project, in context: NSManagedObjectContext) throws {
        guard let oldTagsData = plan.value(forKey: "tags") as? Data else { return }

        let decoder = JSONDecoder()
        guard let oldTags = try? decoder.decode([String].self, from: oldTagsData) else { return }

        for tagString in oldTags where !tagString.isEmpty {
            let projectTag = NSEntityDescription.insertNewObject(forEntityName: "ProjectTag", into: context)
            projectTag.setValue(tagString, forKey: "tag")
            projectTag.setValue(Date(), forKey: "dateAdded")
            projectTag.setValue(plan, forKey: "plan")
        }
    }

    /// Migrate all tags in the store
    static func migrateAllTags(in context: NSManagedObjectContext) throws {
        print("🔄 Starting tags migration...")

        // Migrate Logbook tags
        let logFetch = NSFetchRequest<Logbook>(entityName: "Logbook")
        let logs = try context.fetch(logFetch)
        print("  Found \(logs.count) project logs to migrate")

        for log in logs {
            try? migrateTags(for: log, in: context)
        }

        // Migrate Project tags
        let planFetch = NSFetchRequest<Project>(entityName: "Project")
        let plans = try context.fetch(planFetch)
        print("  Found \(plans.count) projects to migrate")

        for plan in plans {
            try? migrateTags(for: plan, in: context)
        }

        try context.save()
        print("✅ Tags migration complete")
    }

    // MARK: - Techniques Migration (Phase 2)

    /// Migrate techniques for a single Logbook
    static func migrateTechniques(for log: Logbook, in context: NSManagedObjectContext) throws {
        guard let oldTechniquesData = log.value(forKey: "techniques_used") as? Data else { return }

        let decoder = JSONDecoder()
        guard let oldTechniques = try? decoder.decode([String].self, from: oldTechniquesData) else { return }

        for techniqueString in oldTechniques where !techniqueString.isEmpty {
            let projectTechnique = NSEntityDescription.insertNewObject(forEntityName: "ProjectTechnique", into: context)
            projectTechnique.setValue(techniqueString, forKey: "technique")
            projectTechnique.setValue(Date(), forKey: "dateAdded")
            projectTechnique.setValue(log, forKey: "log")
        }
    }

    /// Migrate all techniques in the store
    static func migrateAllTechniques(in context: NSManagedObjectContext) throws {
        print("🔄 Starting techniques migration...")

        let logFetch = NSFetchRequest<Logbook>(entityName: "Logbook")
        let logs = try context.fetch(logFetch)
        print("  Found \(logs.count) project logs to migrate")

        for log in logs {
            try? migrateTechniques(for: log, in: context)
        }

        try context.save()
        print("✅ Techniques migration complete")
    }

    // MARK: - Reference URLs Migration (Phase 3)

    /// Migrate reference URLs for a single Project
    static func migrateReferenceUrls(for plan: Project, in context: NSManagedObjectContext) throws {
        guard let oldUrlsData = plan.value(forKey: "reference_urls_data") as? Data else { return }

        let decoder = JSONDecoder()
        guard let oldUrls = try? decoder.decode([ProjectReferenceUrl].self, from: oldUrlsData) else { return }

        for (index, urlModel) in oldUrls.enumerated() {
            let projectUrl = NSEntityDescription.insertNewObject(forEntityName: "ProjectReferenceUrl", into: context)
            projectUrl.setValue(urlModel.url, forKey: "url")
            projectUrl.setValue(urlModel.title, forKey: "title")
            projectUrl.setValue(urlModel.description, forKey: "urlDescription")
            projectUrl.setValue(Date(), forKey: "dateAdded")
            projectUrl.setValue(Int32(index), forKey: "orderIndex")
            projectUrl.setValue(plan, forKey: "plan")
        }
    }

    /// Migrate all reference URLs in the store
    static func migrateAllReferenceUrls(in context: NSManagedObjectContext) throws {
        print("🔄 Starting reference URLs migration...")

        let planFetch = NSFetchRequest<Project>(entityName: "Project")
        let plans = try context.fetch(planFetch)
        print("  Found \(plans.count) projects to migrate")

        for plan in plans {
            try? migrateReferenceUrls(for: plan, in: context)
        }

        try context.save()
        print("✅ Reference URLs migration complete")
    }

    // MARK: - Glass Items Migration (Phase 4)

    /// Migrate glass items for Logbook
    static func migrateLogGlassItems(for log: Logbook, in context: NSManagedObjectContext) throws {
        guard let oldItemsData = log.value(forKey: "glass_items_data") as? Data else { return }

        let decoder = JSONDecoder()
        guard let oldItems = try? decoder.decode([ProjectGlassItem].self, from: oldItemsData) else { return }

        for (index, item) in oldItems.enumerated() {
            let glassItem = NSEntityDescription.insertNewObject(forEntityName: "LogbookGlassItem", into: context)
            glassItem.setValue(item.naturalKey, forKey: "itemNaturalKey")
            glassItem.setValue(item.quantity, forKey: "quantity")
            glassItem.setValue(item.notes, forKey: "notes")
            glassItem.setValue(Int32(index), forKey: "orderIndex")
            glassItem.setValue(log, forKey: "log")
        }
    }

    /// Migrate glass items for Project
    static func migratePlanGlassItems(for plan: Project, in context: NSManagedObjectContext) throws {
        guard let oldItemsData = plan.value(forKey: "glass_items_data") as? Data else { return }

        let decoder = JSONDecoder()
        guard let oldItems = try? decoder.decode([ProjectGlassItem].self, from: oldItemsData) else { return }

        for (index, item) in oldItems.enumerated() {
            let glassItem = NSEntityDescription.insertNewObject(forEntityName: "ProjectGlassItem", into: context)
            glassItem.setValue(item.naturalKey, forKey: "itemNaturalKey")
            glassItem.setValue(item.quantity, forKey: "quantity")
            glassItem.setValue(item.notes, forKey: "notes")
            glassItem.setValue(Int32(index), forKey: "orderIndex")
            glassItem.setValue(plan, forKey: "plan")
        }
    }

    /// Migrate glass items for ProjectStep
    static func migrateStepGlassItems(for step: ProjectStep, in context: NSManagedObjectContext) throws {
        guard let oldItemsData = step.value(forKey: "glass_items_needed_data") as? Data else { return }

        let decoder = JSONDecoder()
        guard let oldItems = try? decoder.decode([ProjectGlassItem].self, from: oldItemsData) else { return }

        for (index, item) in oldItems.enumerated() {
            let glassItem = NSEntityDescription.insertNewObject(forEntityName: "ProjectStepGlassItem", into: context)
            glassItem.setValue(item.naturalKey, forKey: "itemNaturalKey")
            glassItem.setValue(item.quantity, forKey: "quantity")
            glassItem.setValue(item.notes, forKey: "notes")
            glassItem.setValue(Int32(index), forKey: "orderIndex")
            glassItem.setValue(step, forKey: "step")
        }
    }

    /// Migrate all glass items in the store
    static func migrateAllGlassItems(in context: NSManagedObjectContext) throws {
        print("🔄 Starting glass items migration...")

        // Migrate Logbook glass items
        let logFetch = NSFetchRequest<Logbook>(entityName: "Logbook")
        let logs = try context.fetch(logFetch)
        print("  Found \(logs.count) project logs to migrate")

        for log in logs {
            try? migrateLogGlassItems(for: log, in: context)
        }

        // Migrate Project glass items
        let planFetch = NSFetchRequest<Project>(entityName: "Project")
        let plans = try context.fetch(planFetch)
        print("  Found \(plans.count) projects to migrate")

        for plan in plans {
            try? migratePlanGlassItems(for: plan, in: context)
        }

        // Migrate ProjectStep glass items
        let stepFetch = NSFetchRequest<ProjectStep>(entityName: "ProjectStep")
        let steps = try context.fetch(stepFetch)
        print("  Found \(steps.count) project steps to migrate")

        for step in steps {
            try? migrateStepGlassItems(for: step, in: context)
        }

        try context.save()
        print("✅ Glass items migration complete")
    }

    // MARK: - Run All Migrations

    /// Run all migrations in sequence
    /// Call this once after creating Molten 6 model
    static func runAllMigrations(in context: NSManagedObjectContext) throws {
        print("🚀 Starting Transformable attributes migration to Molten 6...")

        // Check if already migrated
        if UserDefaults.standard.bool(forKey: "migratedToMolten6_Complete") {
            print("ℹ️  Migration already completed, skipping")
            return
        }

        var errors: [Error] = []

        // Phase 1: Tags
        if !UserDefaults.standard.bool(forKey: "migratedToMolten6_Tags") {
            do {
                try migrateAllTags(in: context)
                UserDefaults.standard.set(true, forKey: "migratedToMolten6_Tags")
            } catch {
                errors.append(error)
                print("❌ Tags migration failed: \(error)")
            }
        }

        // Phase 2: Techniques
        if !UserDefaults.standard.bool(forKey: "migratedToMolten6_Techniques") {
            do {
                try migrateAllTechniques(in: context)
                UserDefaults.standard.set(true, forKey: "migratedToMolten6_Techniques")
            } catch {
                errors.append(error)
                print("❌ Techniques migration failed: \(error)")
            }
        }

        // Phase 3: Reference URLs
        if !UserDefaults.standard.bool(forKey: "migratedToMolten6_ReferenceUrls") {
            do {
                try migrateAllReferenceUrls(in: context)
                UserDefaults.standard.set(true, forKey: "migratedToMolten6_ReferenceUrls")
            } catch {
                errors.append(error)
                print("❌ Reference URLs migration failed: \(error)")
            }
        }

        // Phase 4: Glass Items
        if !UserDefaults.standard.bool(forKey: "migratedToMolten6_GlassItems") {
            do {
                try migrateAllGlassItems(in: context)
                UserDefaults.standard.set(true, forKey: "migratedToMolten6_GlassItems")
            } catch {
                errors.append(error)
                print("❌ Glass items migration failed: \(error)")
            }
        }

        if errors.isEmpty {
            UserDefaults.standard.set(true, forKey: "migratedToMolten6_Complete")
            print("✅✅✅ All migrations completed successfully!")
        } else {
            print("⚠️  Migration completed with \(errors.count) error(s)")
            throw errors.first!
        }
    }
}
