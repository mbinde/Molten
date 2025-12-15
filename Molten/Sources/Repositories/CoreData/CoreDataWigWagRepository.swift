//
//  CoreDataWigWagRepository.swift
//  Molten
//
//  Core Data implementation of cane pattern repositories - twist canes, wigwag patterns, and glass palettes
//

import Foundation
@preconcurrency import CoreData

// MARK: - TwistCane Repository

/// Core Data implementation of TwistCaneRepository
class CoreDataTwistCaneRepository: @unchecked Sendable, TwistCaneRepository {
    private let context: NSManagedObjectContext

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - CRUD Operations

    func create(_ cane: TwistCaneModel) async throws -> TwistCaneModel {
        return try await context.perform {
            guard let entity = NSEntityDescription.insertNewObject(
                forEntityName: "TwistCane",
                into: self.context
            ) as? NSManagedObject else {
                throw WigWagRepositoryError.invalidData("Failed to create TwistCane entity")
            }

            self.mapModelToEntity(cane, entity: entity)
            try CoreDataErrorHandler.save(context: self.context)
            return cane
        }
    }

    func get(id: UUID) async throws -> TwistCaneModel? {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TwistCane")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                return nil
            }

            return self.mapEntityToModel(entity)
        }
    }

    func getAll() async throws -> [TwistCaneModel] {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TwistCane")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updated_at", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    func update(_ cane: TwistCaneModel) async throws {
        try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TwistCane")
            fetchRequest.predicate = NSPredicate(format: "id == %@", cane.id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw WigWagRepositoryError.caneNotFound
            }

            self.mapModelToEntity(cane.withUpdatedTimestamp(), entity: entity)
            try CoreDataErrorHandler.save(context: self.context)
        }
    }

    func delete(id: UUID) async throws {
        try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TwistCane")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw WigWagRepositoryError.caneNotFound
            }

            self.context.delete(entity)
            try CoreDataErrorHandler.save(context: self.context)
        }
    }

    // MARK: - Queries

    func getAllSortedByName() async throws -> [TwistCaneModel] {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TwistCane")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    func getAllSortedByDate() async throws -> [TwistCaneModel] {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TwistCane")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updated_at", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    // MARK: - Mapping

    private func mapModelToEntity(_ model: TwistCaneModel, entity: NSManagedObject) {
        entity.setValue(model.id, forKey: "id")
        entity.setValue(model.name, forKey: "name")
        entity.setValue(model.createdAt, forKey: "created_at")
        entity.setValue(model.updatedAt, forKey: "updated_at")
        entity.setValue(model.glassPaletteId, forKey: "glass_palette_id")
        entity.setValue(model.twist, forKey: "twist")
        entity.setValue(model.width, forKey: "width")
    }

    private func mapEntityToModel(_ entity: NSManagedObject) -> TwistCaneModel? {
        guard let id = entity.value(forKey: "id") as? UUID,
              let name = entity.value(forKey: "name") as? String,
              let createdAt = entity.value(forKey: "created_at") as? Date,
              let updatedAt = entity.value(forKey: "updated_at") as? Date,
              let glassPaletteId = entity.value(forKey: "glass_palette_id") as? UUID else {
            return nil
        }

        let twist = entity.value(forKey: "twist") as? Double ?? 1.0
        let width = entity.value(forKey: "width") as? Double ?? 1.0

        return TwistCaneModel(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            glassPaletteId: glassPaletteId,
            twist: twist,
            width: width
        )
    }
}

// MARK: - TwistPattern Repository

/// Core Data implementation of TwistPatternRepository
class CoreDataTwistPatternRepository: @unchecked Sendable, TwistPatternRepository {
    private let context: NSManagedObjectContext

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - CRUD Operations

    func create(_ pattern: TwistPatternModel) async throws -> TwistPatternModel {
        return try await context.perform {
            // Use NSEntityDescription to create the entity to avoid name collision
            guard let entity = NSEntityDescription.insertNewObject(
                forEntityName: "WigWagTwistPattern",
                into: self.context
            ) as? NSManagedObject else {
                throw WigWagRepositoryError.invalidData("Failed to create WigWagTwistPattern entity")
            }

            self.mapModelToEntity(pattern, entity: entity)
            try CoreDataErrorHandler.save(context: self.context)
            return pattern
        }
    }

    func get(id: UUID) async throws -> TwistPatternModel? {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WigWagTwistPattern")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                return nil
            }

            return self.mapEntityToModel(entity)
        }
    }

    func getAll() async throws -> [TwistPatternModel] {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WigWagTwistPattern")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updated_at", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    func update(_ pattern: TwistPatternModel) async throws {
        try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WigWagTwistPattern")
            fetchRequest.predicate = NSPredicate(format: "id == %@", pattern.id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw WigWagRepositoryError.patternNotFound
            }

            self.mapModelToEntity(pattern.withUpdatedTimestamp(), entity: entity)
            try CoreDataErrorHandler.save(context: self.context)
        }
    }

    func delete(id: UUID) async throws {
        try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WigWagTwistPattern")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw WigWagRepositoryError.patternNotFound
            }

            self.context.delete(entity)
            try CoreDataErrorHandler.save(context: self.context)
        }
    }

    // MARK: - Queries

    func getAllSortedByName() async throws -> [TwistPatternModel] {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WigWagTwistPattern")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    func getAllSortedByDate() async throws -> [TwistPatternModel] {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "WigWagTwistPattern")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updated_at", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    // MARK: - Mapping

    private func mapModelToEntity(_ model: TwistPatternModel, entity: NSManagedObject) {
        entity.setValue(model.id, forKey: "id")
        entity.setValue(model.name, forKey: "name")
        entity.setValue(model.createdAt, forKey: "created_at")
        entity.setValue(model.updatedAt, forKey: "updated_at")
        entity.setValue(WigWagJSONHelper.encodeHistory(model.twistHistory), forKey: "twist_history")
    }

    private func mapEntityToModel(_ entity: NSManagedObject) -> TwistPatternModel? {
        guard let id = entity.value(forKey: "id") as? UUID,
              let name = entity.value(forKey: "name") as? String,
              let createdAt = entity.value(forKey: "created_at") as? Date,
              let updatedAt = entity.value(forKey: "updated_at") as? Date else {
            return nil
        }

        let twistHistoryJSON = entity.value(forKey: "twist_history") as? String
        let twistHistory = WigWagJSONHelper.decodeHistory(twistHistoryJSON)

        return TwistPatternModel(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            twistHistory: twistHistory
        )
    }
}

// MARK: - GlassPalette Repository

/// Core Data implementation of GlassPaletteRepository
class CoreDataGlassPaletteRepository: @unchecked Sendable, GlassPaletteRepository {
    private let context: NSManagedObjectContext

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - CRUD Operations

    func create(_ palette: GlassPaletteModel) async throws -> GlassPaletteModel {
        return try await context.perform {
            // Use NSEntityDescription to create the entity to avoid name collision
            guard let entity = NSEntityDescription.insertNewObject(
                forEntityName: "GlassPalette",
                into: self.context
            ) as? NSManagedObject else {
                throw WigWagRepositoryError.invalidData("Failed to create GlassPalette entity")
            }

            self.mapModelToEntity(palette, entity: entity)
            try CoreDataErrorHandler.save(context: self.context)
            return palette
        }
    }

    func get(id: UUID) async throws -> GlassPaletteModel? {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "GlassPalette")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                return nil
            }

            return self.mapEntityToModel(entity)
        }
    }

    func getAll() async throws -> [GlassPaletteModel] {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "GlassPalette")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updated_at", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    func update(_ palette: GlassPaletteModel) async throws {
        try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "GlassPalette")
            fetchRequest.predicate = NSPredicate(format: "id == %@", palette.id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw WigWagRepositoryError.paletteNotFound
            }

            self.mapModelToEntity(palette.withUpdatedTimestamp(), entity: entity)
            try CoreDataErrorHandler.save(context: self.context)
        }
    }

    func delete(id: UUID) async throws {
        try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "GlassPalette")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw WigWagRepositoryError.paletteNotFound
            }

            self.context.delete(entity)
            try CoreDataErrorHandler.save(context: self.context)
        }
    }

    // MARK: - Queries

    func getByType(_ type: String) async throws -> [GlassPaletteModel] {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "GlassPalette")
            fetchRequest.predicate = NSPredicate(format: "type == %@", type)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    func getByCOE(_ coe: Int16) async throws -> [GlassPaletteModel] {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "GlassPalette")
            fetchRequest.predicate = NSPredicate(format: "coe == %d", coe)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    func getAllSortedByName() async throws -> [GlassPaletteModel] {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "GlassPalette")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    func getAllSortedByDate() async throws -> [GlassPaletteModel] {
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "GlassPalette")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updated_at", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    // MARK: - Mapping

    private func mapModelToEntity(_ model: GlassPaletteModel, entity: NSManagedObject) {
        entity.setValue(model.id, forKey: "id")
        entity.setValue(model.name, forKey: "name")
        entity.setValue(model.type, forKey: "type")
        entity.setValue(model.createdAt, forKey: "created_at")
        entity.setValue(model.updatedAt, forKey: "updated_at")
        entity.setValue(model.coe, forKey: "coe")
        entity.setValue(WigWagJSONHelper.encodeItemIds(model.catalogItemIds), forKey: "catalog_item_ids")
        entity.setValue(WigWagJSONHelper.encodeItemIds(model.allCatalogItemIds), forKey: "all_catalog_item_ids")
    }

    private func mapEntityToModel(_ entity: NSManagedObject) -> GlassPaletteModel? {
        guard let id = entity.value(forKey: "id") as? UUID,
              let name = entity.value(forKey: "name") as? String,
              let type = entity.value(forKey: "type") as? String,
              let createdAt = entity.value(forKey: "created_at") as? Date,
              let updatedAt = entity.value(forKey: "updated_at") as? Date else {
            return nil
        }

        let coe = entity.value(forKey: "coe") as? Int16 ?? 0
        let catalogItemIdsJSON = entity.value(forKey: "catalog_item_ids") as? String
        let catalogItemIds = WigWagJSONHelper.decodeItemIds(catalogItemIdsJSON)
        let allCatalogItemIdsJSON = entity.value(forKey: "all_catalog_item_ids") as? String
        let allCatalogItemIds = WigWagJSONHelper.decodeItemIds(allCatalogItemIdsJSON)

        return GlassPaletteModel(
            id: id,
            name: name,
            type: type,
            createdAt: createdAt,
            updatedAt: updatedAt,
            coe: coe,
            catalogItemIds: catalogItemIds,
            allCatalogItemIds: allCatalogItemIds
        )
    }
}
