//
//  CoreDataKilnScheduleRepository.swift
//  Molten
//
//  Core Data implementation of KilnScheduleRepository
//

import Foundation
@preconcurrency import CoreData

/// Core Data implementation of KilnScheduleRepository
class CoreDataKilnScheduleRepository: @unchecked Sendable, KilnScheduleRepository {
    private let context: NSManagedObjectContext

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - CRUD Operations

    func createSchedule(_ schedule: KilnSchedule) async throws -> KilnSchedule {
        return try await context.perform {
            let entity = KilnSchedule(context: self.context)
            self.mapModelToEntity(schedule, entity: entity)

            try self.context.save()
            return schedule
        }
    }

    func getSchedule(id: UUID) async throws -> KilnSchedule? {
        return try await context.perform {
            let fetchRequest = KilnSchedule.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                return nil
            }

            return try self.mapEntityToModel(entity)
        }
    }

    func getAllSchedules() async throws -> [KilnSchedule] {
        return try await context.perform {
            let fetchRequest = KilnSchedule.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_created", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    func updateSchedule(_ schedule: KilnSchedule) async throws {
        try await context.perform {
            let fetchRequest = KilnSchedule.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", schedule.id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw KilnScheduleRepositoryError.scheduleNotFound
            }

            self.mapModelToEntity(schedule, entity: entity)
            try self.context.save()
        }
    }

    func deleteSchedule(id: UUID) async throws {
        try await context.perform {
            let fetchRequest = KilnSchedule.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw KilnScheduleRepositoryError.scheduleNotFound
            }

            self.context.delete(entity)
            try self.context.save()
        }
    }

    // MARK: - Business Queries

    func getSchedules(technique: KilnTechnique) async throws -> [KilnSchedule] {
        return try await context.perform {
            let fetchRequest = KilnSchedule.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "technique == %@", technique.rawValue)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    func getSchedulesSortedByName() async throws -> [KilnSchedule] {
        return try await context.perform {
            let fetchRequest = KilnSchedule.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    // MARK: - Search

    func searchSchedules(query: String) async throws -> [KilnSchedule] {
        return try await context.perform {
            let fetchRequest = KilnSchedule.fetchRequest()

            // Search in name, notes, and technique
            let namePredicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
            let notesPredicate = NSPredicate(format: "notes CONTAINS[cd] %@", query)
            let techniquePredicate = NSPredicate(format: "technique CONTAINS[cd] %@", query)

            fetchRequest.predicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [namePredicate, notesPredicate, techniquePredicate]
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    // MARK: - Mapping Helpers

    private nonisolated func mapModelToEntity(_ model: KilnSchedule, entity: KilnSchedule) {
        entity.setValue(model.id, forKey: "id")
        entity.setValue(model.name, forKey: "name")
        entity.setValue(model.technique.rawValue, forKey: "technique")
        entity.setValue(model.dateCreated, forKey: "date_created")
        entity.setValue(model.dateModified, forKey: "date_modified")
        entity.setValue(model.startTemperature as NSDecimalNumber, forKey: "start_temperature")
        entity.setValue(model.temperatureUnit.rawValue, forKey: "temperature_unit")
        entity.setValue(model.notes, forKey: "notes")

        // Clear existing segments
        if let existingSegments = entity.value(forKey: "segments") as? Set<KilnSegment> {
            for segment in existingSegments {
                self.context.delete(segment)
            }
        }

        // Create new segment entities
        for (index, segment) in model.segments.enumerated() {
            let segmentEntity = KilnSegment(context: self.context)
            segmentEntity.setValue(segment.id, forKey: "id")
            segmentEntity.setValue(segment.targetTemperature as NSDecimalNumber, forKey: "target_temperature")
            segmentEntity.setValue(segment.rampRate as NSDecimalNumber?, forKey: "ramp_rate")
            segmentEntity.setValue(segment.holdTime as NSDecimalNumber?, forKey: "hold_time")
            segmentEntity.setValue(Int32(index), forKey: "order_index")
            segmentEntity.setValue(entity, forKey: "schedule")
        }
    }

    private nonisolated func mapEntityToModel(_ entity: KilnSchedule) throws -> KilnSchedule {
        guard let id = entity.value(forKey: "id") as? UUID,
              let name = entity.value(forKey: "name") as? String,
              let techniqueString = entity.value(forKey: "technique") as? String,
              let technique = KilnTechnique(rawValue: techniqueString),
              let dateCreated = entity.value(forKey: "date_created") as? Date,
              let dateModified = entity.value(forKey: "date_modified") as? Date,
              let startTemperature = entity.value(forKey: "start_temperature") as? NSDecimalNumber,
              let temperatureUnitString = entity.value(forKey: "temperature_unit") as? String,
              let temperatureUnit = TemperatureUnit(rawValue: temperatureUnitString) else {
            throw KilnScheduleRepositoryError.invalidData("Missing required fields in KilnSchedule entity")
        }

        // Extract segments from relationship
        let segments: [KilnSegment] = (entity.value(forKey: "segments") as? Set<KilnSegment>)?
            .sorted { ($0.value(forKey: "order_index") as? Int32 ?? 0) < ($1.value(forKey: "order_index") as? Int32 ?? 0) }
            .compactMap { segmentEntity in
                guard let segmentId = segmentEntity.value(forKey: "id") as? UUID,
                      let targetTemp = segmentEntity.value(forKey: "target_temperature") as? NSDecimalNumber else {
                    return nil
                }

                let rampRate = segmentEntity.value(forKey: "ramp_rate") as? NSDecimalNumber
                let holdTime = segmentEntity.value(forKey: "hold_time") as? NSDecimalNumber

                // Determine segment type and create appropriate initializer
                if let rate = rampRate, rate.decimalValue > 0 {
                    return KilnSegment(
                        id: segmentId,
                        targetTemperature: targetTemp as Decimal,
                        rampRate: rate as Decimal
                    )
                } else if let time = holdTime, time.decimalValue > 0 {
                    return KilnSegment(
                        id: segmentId,
                        targetTemperature: targetTemp as Decimal,
                        holdTime: time as Decimal
                    )
                } else {
                    // Default to ramp with 0 rate if neither is set
                    return KilnSegment(
                        id: segmentId,
                        targetTemperature: targetTemp as Decimal,
                        rampRate: 0
                    )
                }
            } ?? []

        return KilnSchedule(
            id: id,
            name: name,
            technique: technique,
            dateCreated: dateCreated,
            dateModified: dateModified,
            segments: segments,
            notes: entity.value(forKey: "notes") as? String,
            startTemperature: startTemperature as Decimal,
            temperatureUnit: temperatureUnit
        )
    }
}
