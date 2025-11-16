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
            let entity = KilnScheduleEntity(context: self.context)
            self.mapModelToEntity(schedule, entity: entity)

            try CoreDataErrorHandler.save(context: self.context)
            return schedule
        }
    }

    func getSchedule(id: UUID) async throws -> KilnSchedule? {
        return try await context.perform {
            let fetchRequest = KilnScheduleEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                return nil
            }

            return try self.mapEntityToModel(entity)
        }
    }

    func getAllSchedules() async throws -> [KilnSchedule] {
        return try await context.perform {
            let fetchRequest = KilnScheduleEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_created", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    func updateSchedule(_ schedule: KilnSchedule) async throws {
        try await context.perform {
            let fetchRequest = KilnScheduleEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", schedule.id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw KilnScheduleRepositoryError.scheduleNotFound
            }

            self.mapModelToEntity(schedule, entity: entity)
            try CoreDataErrorHandler.save(context: self.context)
        }
    }

    func deleteSchedule(id: UUID) async throws {
        try await context.perform {
            let fetchRequest = KilnScheduleEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw KilnScheduleRepositoryError.scheduleNotFound
            }

            self.context.delete(entity)
            try CoreDataErrorHandler.save(context: self.context)
        }
    }

    // MARK: - Business Queries

    func getSchedules(technique: TechniqueType) async throws -> [KilnSchedule] {
        return try await context.perform {
            let fetchRequest = KilnScheduleEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "technique == %@", technique.rawValue)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    func getSchedulesSortedByName() async throws -> [KilnSchedule] {
        return try await context.perform {
            let fetchRequest = KilnScheduleEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    // MARK: - Search

    func searchSchedules(query: String) async throws -> [KilnSchedule] {
        return try await context.perform {
            let fetchRequest = KilnScheduleEntity.fetchRequest()

            // Search in name, description, and technique
            // Handle optional fields (description, technique) by checking for nil
            let namePredicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
            let descriptionPredicate = NSPredicate(format: "schedule_description != nil AND schedule_description CONTAINS[cd] %@", query)
            let techniquePredicate = NSPredicate(format: "technique != nil AND technique CONTAINS[cd] %@", query)

            fetchRequest.predicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [namePredicate, descriptionPredicate, techniquePredicate]
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    // MARK: - Mapping Helpers

    private func mapModelToEntity(_ model: KilnSchedule, entity: KilnScheduleEntity) {
        // Ensure segments array is not empty
        guard !model.segments.isEmpty else {
            fatalError("Cannot save KilnSchedule with no segments. Schedule: \(model.name), segments count: \(model.segments.count)")
        }

        entity.setValue(model.id, forKey: "id")
        entity.setValue(model.name, forKey: "name")
        entity.setValue(model.technique?.rawValue, forKey: "technique")  // TechniqueType is optional
        entity.setValue(model.dateCreated, forKey: "date_created")
        entity.setValue(model.dateModified, forKey: "date_modified")

        // Temperature unit always stored as Celsius
        entity.setValue(TemperatureUnit.celsius.rawValue, forKey: "temperature_unit")

        // Set description (optional field added in model version 12)
        entity.setValue(model.description, forKey: "schedule_description")

        // Clear existing segments
        if let existingSegments = entity.value(forKey: "segments") as? Set<KilnSegmentEntity> {
            for segment in existingSegments {
                self.context.delete(segment)
            }
        }

        // Create new segment entities (normalize segment temperatures to Celsius)
        // Use parent's mutableSetValue to add children, letting Core Data handle inverse relationship
        let segmentsSet = entity.mutableSetValue(forKey: "segments")
        for (index, segment) in model.segments.enumerated() {
            let segmentEntity = KilnSegmentEntity(context: self.context)
            segmentEntity.setValue(segment.id, forKey: "id")

            // Normalize target temperature to Celsius
            let targetTempCelsius = model.temperatureUnit.toCelsius(segment.targetTemperature)
            segmentEntity.setValue(targetTempCelsius as NSDecimalNumber, forKey: "target_temperature")
            segmentEntity.setValue(segment.rampRate as NSDecimalNumber?, forKey: "ramp_rate")
            segmentEntity.setValue(segment.holdTime as NSDecimalNumber?, forKey: "hold_time")
            segmentEntity.setValue(Int32(index), forKey: "order_index")

            // Add to parent's collection instead of setting child's parent property
            // This avoids KVC issues with auto-generated Core Data classes
            segmentsSet.add(segmentEntity)
        }
    }

    private func mapEntityToModel(_ entity: KilnScheduleEntity) throws -> KilnSchedule {
        guard let id = entity.value(forKey: "id") as? UUID,
              let name = entity.value(forKey: "name") as? String,
              let dateCreated = entity.value(forKey: "date_created") as? Date,
              let dateModified = entity.value(forKey: "date_modified") as? Date else {
            throw KilnScheduleRepositoryError.invalidData("Missing required fields in KilnSchedule entity")
        }

        // Technique is optional - parse if present
        let technique: TechniqueType?
        if let techniqueString = entity.value(forKey: "technique") as? String {
            technique = TechniqueType(rawValue: techniqueString)
        } else {
            technique = nil
        }

        // Description is optional
        let description = entity.value(forKey: "schedule_description") as? String

        // Extract segments from relationship
        let segments: [KilnSegment] = (entity.value(forKey: "segments") as? Set<KilnSegmentEntity>)?
            .sorted { ($0.value(forKey: "order_index") as? Int32 ?? 0) < ($1.value(forKey: "order_index") as? Int32 ?? 0) }
            .compactMap { segmentEntity -> KilnSegment? in
                guard let segmentId = segmentEntity.value(forKey: "id") as? UUID,
                      let targetTemp = segmentEntity.value(forKey: "target_temperature") as? NSDecimalNumber else {
                    return nil
                }

                let rampRate = segmentEntity.value(forKey: "ramp_rate") as? NSDecimalNumber
                let holdTime = segmentEntity.value(forKey: "hold_time") as? NSDecimalNumber

                return KilnSegment(
                    id: segmentId,
                    targetTemperature: targetTemp as Decimal,
                    rampRate: rampRate?.decimalValue ?? 0,
                    holdTime: holdTime?.decimalValue ?? 0
                )
            } ?? []

        return KilnSchedule(
            id: id,
            name: name,
            technique: technique,
            dateCreated: dateCreated,
            dateModified: dateModified,
            segments: segments,
            description: description,
            temperatureUnit: .celsius  // All schedules stored in Celsius
        )
    }
}
