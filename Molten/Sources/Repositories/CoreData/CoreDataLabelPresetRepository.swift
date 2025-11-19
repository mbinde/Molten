//
//  CoreDataLabelPresetRepository.swift
//  Molten
//
//  Core Data implementation for label preset persistence with CloudKit sync
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of LabelPresetRepository
/// Stores user presets in CloudKit-synced Core Data store
class CoreDataLabelPresetRepository: @unchecked Sendable, LabelPresetRepository {

    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.motleywoods.molten", category: "label-preset-repository")

    // MARK: - Initialization

    /// Initialize with a managed object context
    /// - Parameter context: The NSManagedObjectContext to use (should be cloudContext for CloudKit sync)
    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.backgroundContext = context
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Fetch Operations

    func fetchAllPresets() async throws -> [LabelBuilderPreset] {
        return try await fetchPresets(matching: nil)
    }

    func fetchPreset(byId id: UUID) async throws -> LabelBuilderPreset? {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let presets = try await fetchPresets(matching: predicate)
        return presets.first
    }

    func fetchPresets(matching predicate: NSPredicate?) async throws -> [LabelBuilderPreset] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[LabelBuilderPreset], Error>) in
            nonisolated(unsafe) let predicateCopy = predicate
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "LabelPresetEntity")
                    fetchRequest.predicate = predicateCopy
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "name", ascending: true)
                    ]

                    let entities = try self.backgroundContext.fetch(fetchRequest)
                    let presets = entities.compactMap { self.convertToModel($0) }

                    continuation.resume(returning: presets)

                } catch {
                    self.log.error("Failed to fetch label presets: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Write Operations

    func createPreset(_ preset: LabelBuilderPreset) async throws -> LabelBuilderPreset {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LabelBuilderPreset, Error>) in
            backgroundContext.perform {
                do {
                    guard let entity = NSEntityDescription.entity(forEntityName: "LabelPresetEntity", in: self.backgroundContext) else {
                        throw CoreDataLabelPresetError.entityNotFound
                    }
                    let coreDataEntity = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                    // Set properties
                    try self.updateEntity(coreDataEntity, with: preset)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Created label preset: \(preset.name)")
                    continuation.resume(returning: preset)

                } catch {
                    self.log.error("Failed to create label preset: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updatePreset(_ preset: LabelBuilderPreset) async throws -> LabelBuilderPreset {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LabelBuilderPreset, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "LabelPresetEntity")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", preset.id as CVarArg)
                    fetchRequest.fetchLimit = 1

                    guard let entity = try self.backgroundContext.fetch(fetchRequest).first else {
                        throw CoreDataLabelPresetError.presetNotFound(preset.id)
                    }

                    // Update properties
                    try self.updateEntity(entity, with: preset)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Updated label preset: \(preset.name)")
                    continuation.resume(returning: preset)

                } catch {
                    self.log.error("Failed to update label preset: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deletePreset(id: UUID) async throws {
        try await deletePresets(ids: [id])
    }

    func deletePresets(ids: [UUID]) async throws {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "LabelPresetEntity")
                    fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)

                    let entities = try self.backgroundContext.fetch(fetchRequest)

                    for entity in entities {
                        self.backgroundContext.delete(entity)
                    }

                    try self.backgroundContext.save()

                    self.log.info("Deleted \(entities.count) label preset(s)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete label presets: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Conversion Helpers

    /// Convert Core Data entity to model
    private func convertToModel(_ entity: NSManagedObject) -> LabelBuilderPreset? {
        guard let id = entity.value(forKey: "id") as? UUID,
              let name = entity.value(forKey: "name") as? String,
              let createdAt = entity.value(forKey: "created_at") as? Date,
              let modifiedAt = entity.value(forKey: "modified_at") as? Date,
              let qrPositionString = entity.value(forKey: "qr_position") as? String,
              let qrPosition = QRCodePosition(rawValue: qrPositionString),
              let textAlignmentString = entity.value(forKey: "text_alignment") as? String,
              let textAlignment = LabelTextAlignment(rawValue: textAlignmentString),
              let textFieldsOrderJSON = entity.value(forKey: "text_fields_order") as? String,
              let fieldFormatsJSON = entity.value(forKey: "field_formats") as? String else {
            log.error("Failed to convert LabelPresetEntity to model - missing required fields")
            return nil
        }

        let description = entity.value(forKey: "desc") as? String
        let qrSize = entity.value(forKey: "qr_size") as? Double  // Optional now
        let fontScale = entity.value(forKey: "font_scale") as? Double  // Optional
        let manufacturerImageSize = entity.value(forKey: "manufacturer_image_size") as? Double  // Optional

        // Manufacturer image position (with fallback to .none for old presets)
        let manufacturerImagePositionString = entity.value(forKey: "manufacturer_image_position") as? String
        let manufacturerImagePosition: ManufacturerImagePosition
        if let posString = manufacturerImagePositionString, let position = ManufacturerImagePosition(rawValue: posString) {
            manufacturerImagePosition = position
        } else {
            manufacturerImagePosition = .none
        }

        // Decode text fields order
        guard let textFieldsData = textFieldsOrderJSON.data(using: .utf8),
              let textFields = try? JSONDecoder().decode([LabelTextField].self, from: textFieldsData) else {
            log.error("Failed to decode text_fields_order JSON")
            return nil
        }

        // Decode field formats
        guard let fieldFormatsData = fieldFormatsJSON.data(using: .utf8),
              let fieldFormats = try? JSONDecoder().decode([LabelTextField: LabelFieldFormat].self, from: fieldFormatsData) else {
            log.error("Failed to decode field_formats JSON")
            return nil
        }

        // Convert optionals without closures to avoid isolation issues
        let qrSizeCGFloat: CGFloat? = qrSize != nil ? CGFloat(qrSize!) : nil
        let fontScaleCGFloat: CGFloat? = fontScale != nil ? CGFloat(fontScale!) : nil
        let manufacturerImageSizeCGFloat: CGFloat? = manufacturerImageSize != nil ? CGFloat(manufacturerImageSize!) : nil

        let config = LabelBuilderConfig(
            qrPosition: qrPosition,
            qrSize: qrSizeCGFloat,
            fontScale: fontScaleCGFloat,
            manufacturerImagePosition: manufacturerImagePosition,
            manufacturerImageSize: manufacturerImageSizeCGFloat,
            textFields: textFields,
            textAlignment: textAlignment,
            fieldFormats: fieldFormats
        )

        return LabelBuilderPreset(
            id: id,
            name: name,
            description: description ?? "",
            config: config,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }

    /// Update Core Data entity from model
    private func updateEntity(_ entity: NSManagedObject, with preset: LabelBuilderPreset) throws {
        entity.setValue(preset.id, forKey: "id")
        entity.setValue(preset.name, forKey: "name")
        entity.setValue(preset.description.isEmpty ? nil : preset.description, forKey: "desc")
        entity.setValue(preset.createdAt, forKey: "created_at")
        entity.setValue(preset.modifiedAt, forKey: "modified_at")
        entity.setValue(preset.config.qrPosition.rawValue, forKey: "qr_position")
        entity.setValue(preset.config.qrSize.map { Double($0) }, forKey: "qr_size")  // Convert CGFloat? to Double?
        entity.setValue(preset.config.fontScale.map { Double($0) }, forKey: "font_scale")  // Convert CGFloat? to Double?
        entity.setValue(preset.config.manufacturerImagePosition.rawValue, forKey: "manufacturer_image_position")
        entity.setValue(preset.config.manufacturerImageSize.map { Double($0) }, forKey: "manufacturer_image_size")  // Convert CGFloat? to Double?
        entity.setValue(preset.config.textAlignment.rawValue, forKey: "text_alignment")

        // Encode text fields order to JSON
        let textFieldsData = try JSONEncoder().encode(preset.config.textFields)
        guard let textFieldsJSON = String(data: textFieldsData, encoding: .utf8) else {
            throw CoreDataLabelPresetError.encodingFailed("text_fields_order")
        }
        entity.setValue(textFieldsJSON, forKey: "text_fields_order")

        // Encode field formats to JSON
        let fieldFormatsData = try JSONEncoder().encode(preset.config.fieldFormats)
        guard let fieldFormatsJSON = String(data: fieldFormatsData, encoding: .utf8) else {
            throw CoreDataLabelPresetError.encodingFailed("field_formats")
        }
        entity.setValue(fieldFormatsJSON, forKey: "field_formats")
    }
}

// MARK: - Errors

enum CoreDataLabelPresetError: LocalizedError {
    case entityNotFound
    case presetNotFound(UUID)
    case encodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            return "LabelPresetEntity not found in Core Data model"
        case .presetNotFound(let id):
            return "Label preset not found: \(id)"
        case .encodingFailed(let field):
            return "Failed to encode \(field) to JSON"
        }
    }
}
