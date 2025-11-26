//
//  DataExportService.swift
//  Molten
//
//  Service for exporting all Molten data to JSON format
//

import Foundation
import CoreData
#if canImport(UIKit)
import UIKit
#endif

/// Service for exporting all app data to JSON format
@MainActor
class DataExportService {

    private let catalogService: CatalogService
    private let inventoryService: InventoryTrackingService
    private let projectRepository: ProjectRepository
    private let logbookRepository: LogbookRepository
    private let purchaseRecordRepository: PurchaseRecordRepository
    #if os(iOS)
    private let userImageRepository: UserImageRepository
    #endif
    private let userNotesRepository: UserNotesRepository

    #if os(iOS)
    init(
        catalogService: CatalogService,
        inventoryService: InventoryTrackingService,
        projectRepository: ProjectRepository,
        logbookRepository: LogbookRepository,
        purchaseRecordRepository: PurchaseRecordRepository,
        userNotesRepository: UserNotesRepository,
        userImageRepository: UserImageRepository
    ) {
        self.catalogService = catalogService
        self.inventoryService = inventoryService
        self.projectRepository = projectRepository
        self.logbookRepository = logbookRepository
        self.purchaseRecordRepository = purchaseRecordRepository
        self.userNotesRepository = userNotesRepository
        self.userImageRepository = userImageRepository
    }
    #else
    init(
        catalogService: CatalogService,
        inventoryService: InventoryTrackingService,
        projectRepository: ProjectRepository,
        logbookRepository: LogbookRepository,
        purchaseRecordRepository: PurchaseRecordRepository,
        userNotesRepository: UserNotesRepository
    ) {
        self.catalogService = catalogService
        self.inventoryService = inventoryService
        self.projectRepository = projectRepository
        self.logbookRepository = logbookRepository
        self.purchaseRecordRepository = purchaseRecordRepository
        self.userNotesRepository = userNotesRepository
    }
    #endif

    // MARK: - Public API

    /// Export all data to a zip file
    /// - Parameter configuration: Export configuration options
    /// - Returns: Result with file URL or error
    func exportAllData(configuration: DataExportConfiguration = .default) async -> Result<DataExportResult, DataExportError> {
        do {
            // Create temporary directory for export files
            let tempDir = try createTempExportDirectory()

            // Fetch and export all entities
            let entityCounts = try await exportAllEntities(to: tempDir, configuration: configuration)

            // Create metadata file
            try await createMetadataFile(at: tempDir, entityCounts: entityCounts, configuration: configuration)

            // TODO: Create zip file (requires ZIPFoundation or similar library)
            // For now, we'll share the directory of JSON files directly
            // The share sheet can handle sharing a directory

            // Calculate total size of all files in directory
            let fileSize = try calculateDirectorySize(tempDir)

            // Move to a more permanent location in temp (so it doesn't get cleaned up immediately)
            let exportFileName = "Molten_Export_\(ISO8601DateFormatter().string(from: Date()))"
            let permanentTempURL = FileManager.default.temporaryDirectory.appendingPathComponent(exportFileName)
            try? FileManager.default.removeItem(at: permanentTempURL)  // Remove if exists
            try FileManager.default.moveItem(at: tempDir, to: permanentTempURL)

            let result = DataExportResult(
                fileURL: permanentTempURL,
                exportDate: Date(),
                fileSize: fileSize,
                includedImages: configuration.includeImages,
                entityCounts: entityCounts
            )

            return .success(result)

        } catch let error as DataExportError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error))
        }
    }

    // MARK: - Export Entities

    private func exportAllEntities(to directory: URL, configuration: DataExportConfiguration) async throws -> ExportEntityCounts {
        var counts = ExportEntityCounts(
            glassItems: 0,
            inventoryRecords: 0,
            projects: 0,
            logbookEntries: 0,
            purchaseRecords: 0,
            userImages: 0,
            userNotes: 0
        )

        // Export glass items
        counts = try await exportGlassItems(to: directory, currentCounts: counts)

        // Export inventory
        counts = try await exportInventory(to: directory, currentCounts: counts)

        // Export projects
        counts = try await exportProjects(to: directory, configuration: configuration, currentCounts: counts)

        // Export logbook
        counts = try await exportLogbook(to: directory, currentCounts: counts)

        // Export purchase records
        counts = try await exportPurchaseRecords(to: directory, currentCounts: counts)

        // Export user images (if enabled)
        if configuration.includeImages {
            counts = try await exportUserImages(to: directory, currentCounts: counts)
        }

        // Export user notes (if enabled)
        if configuration.includeUserNotes {
            counts = try await exportUserNotes(to: directory, currentCounts: counts)
        }

        return counts
    }

    private func exportGlassItems(to directory: URL, currentCounts: ExportEntityCounts) async throws -> ExportEntityCounts {
        let items = try await catalogService.getAllGlassItems()
        let exportItems = items.map { ExportGlassItem.from($0.glassItem) }

        try writeJSONFile(exportItems, to: directory.appendingPathComponent(ExportFileName.glassItems.rawValue))

        return ExportEntityCounts(
            glassItems: exportItems.count,
            inventoryRecords: currentCounts.inventoryRecords,
            projects: currentCounts.projects,
            logbookEntries: currentCounts.logbookEntries,
            purchaseRecords: currentCounts.purchaseRecords,
            userImages: currentCounts.userImages,
            userNotes: currentCounts.userNotes
        )
    }

    private func exportInventory(to directory: URL, currentCounts: ExportEntityCounts) async throws -> ExportEntityCounts {
        // Get all inventory records
        let items = try await catalogService.getAllGlassItems()
        let allInventory = items.flatMap { $0.inventory }
        let exportInventory = allInventory.map { ExportInventory.from($0) }

        try writeJSONFile(exportInventory, to: directory.appendingPathComponent(ExportFileName.inventory.rawValue))

        return ExportEntityCounts(
            glassItems: currentCounts.glassItems,
            inventoryRecords: exportInventory.count,
            projects: currentCounts.projects,
            logbookEntries: currentCounts.logbookEntries,
            purchaseRecords: currentCounts.purchaseRecords,
            userImages: currentCounts.userImages,
            userNotes: currentCounts.userNotes
        )
    }

    private func exportProjects(to directory: URL, configuration: DataExportConfiguration, currentCounts: ExportEntityCounts) async throws -> ExportEntityCounts {
        let allProjects = try await projectRepository.getAllProjects(includeArchived: true)

        // Filter projects based on archived setting
        let projects = allProjects.filter { project in
            configuration.includeArchivedProjects || !project.isArchived
        }

        let exportProjects: [ExportProject] = try await projects.asyncMap { project in
            // Note: Project glass items are embedded in ProjectModel
            let glassItems: [ExportProjectGlassItem] = project.glassItems.map { item in
                ExportProjectGlassItem(
                    id: item.id.uuidString,
                    itemStableId: item.stableId,
                    item_stable_id: nil,
                    freeformDescription: item.freeformDescription,
                    quantity: NSDecimalNumber(decimal: item.quantity).doubleValue,
                    unit: item.unit,
                    notes: item.notes,
                    orderIndex: nil
                )
            }

            // Note: Steps are embedded in ProjectModel
            let steps: [ExportProjectStep] = project.steps.map { step in
                ExportProjectStep(
                    id: step.id.uuidString,
                    stepDescription: step.description,
                    orderIndex: Int32(step.order),
                    glassItems: (step.glassItemsNeeded ?? []).map { item in
                        ExportProjectStepGlassItem(
                            id: item.id.uuidString,
                            itemStableId: item.stableId,
                            quantity: NSDecimalNumber(decimal: item.quantity).doubleValue,
                            unit: item.unit
                        )
                    }
                )
            }

            // Note: Images are embedded in ProjectModel
            let images: [ExportProjectImage] = project.images.map { image in
                ExportProjectImage(
                    id: image.id.uuidString,
                    fileName: image.fileName,
                    caption: image.caption,
                    fileExtension: image.fileExtension,
                    dateAdded: image.dateAdded,
                    orderIndex: Int32(image.order)
                )
            }

            // Note: Reference URLs are embedded in ProjectModel
            let referenceUrls: [ExportProjectReferenceUrl] = project.referenceUrls.map { url in
                ExportProjectReferenceUrl(
                    id: url.id.uuidString,
                    url: url.url,
                    title: url.title,
                    urlDescription: url.description,
                    dateAdded: url.dateAdded,
                    orderIndex: nil  // ProjectReferenceUrl doesn't have orderIndex
                )
            }

            return ExportProject(
                id: project.id.uuidString,
                title: project.title,
                summary: project.summary,
                projectType: project.type.rawValue,
                coe: project.coe,
                difficultyLevel: project.difficultyLevel?.rawValue,
                estimatedTime: project.estimatedTime,
                proposedPriceMin: project.proposedPriceRange?.min,
                proposedPriceMax: project.proposedPriceRange?.max,
                priceCurrency: project.proposedPriceRange?.currency,
                dateCreated: project.dateCreated,
                dateModified: project.dateModified,
                isArchived: project.isArchived,
                heroImageId: project.heroImageId?.uuidString,
                glassItems: glassItems,
                images: images,
                steps: steps,
                referenceUrls: referenceUrls
            )
        }

        try writeJSONFile(exportProjects, to: directory.appendingPathComponent(ExportFileName.projects.rawValue))

        return ExportEntityCounts(
            glassItems: currentCounts.glassItems,
            inventoryRecords: currentCounts.inventoryRecords,
            projects: exportProjects.count,
            logbookEntries: currentCounts.logbookEntries,
            purchaseRecords: currentCounts.purchaseRecords,
            userImages: currentCounts.userImages,
            userNotes: currentCounts.userNotes
        )
    }

    private func exportLogbook(to directory: URL, currentCounts: ExportEntityCounts) async throws -> ExportEntityCounts {
        let entries = try await logbookRepository.getAllLogs()

        let exportEntries: [ExportLogbookEntry] = entries.map { entry in
            // Note: Glass items are embedded in LogbookModel
            let glassItems: [ExportLogbookGlassItem] = entry.glassItems.map { item in
                ExportLogbookGlassItem(
                    id: item.id.uuidString,
                    itemStableId: item.stableId,
                    quantity: NSDecimalNumber(decimal: item.quantity).doubleValue,
                    unit: item.unit,
                    notes: item.notes
                )
            }

            // Note: Images are embedded in LogbookModel
            let images: [ExportProjectImage] = entry.images.map { image in
                ExportProjectImage(
                    id: image.id.uuidString,
                    fileName: image.fileName,
                    caption: image.caption,
                    fileExtension: image.fileExtension,
                    dateAdded: image.dateAdded,
                    orderIndex: Int32(image.order)
                )
            }

            return ExportLogbookEntry(
                id: entry.id.uuidString,
                title: entry.title,
                entryDescription: entry.notes,
                entryType: entry.techniqueType?.rawValue,  // LogbookModel doesn't have entryType
                dateCreated: entry.dateCreated,
                dateModified: entry.dateModified,
                glassItems: glassItems,
                images: images
            )
        }

        try writeJSONFile(exportEntries, to: directory.appendingPathComponent(ExportFileName.logbook.rawValue))

        return ExportEntityCounts(
            glassItems: currentCounts.glassItems,
            inventoryRecords: currentCounts.inventoryRecords,
            projects: currentCounts.projects,
            logbookEntries: exportEntries.count,
            purchaseRecords: currentCounts.purchaseRecords,
            userImages: currentCounts.userImages,
            userNotes: currentCounts.userNotes
        )
    }

    private func exportPurchaseRecords(to directory: URL, currentCounts: ExportEntityCounts) async throws -> ExportEntityCounts {
        let records = try await purchaseRecordRepository.getAllRecords()

        let exportRecords: [ExportPurchaseRecord] = records.map { record in
            // Note: Items are embedded in PurchaseRecordModel
            let items: [ExportPurchaseRecordItem] = record.items.map { item in
                ExportPurchaseRecordItem(
                    id: item.id.uuidString,
                    itemStableId: item.item_stable_id,
                    quantity: item.quantity,
                    unitPrice: nil,  // PurchaseRecordItemModel doesn't have unitPrice
                    totalPrice: item.totalPrice
                )
            }

            return ExportPurchaseRecord(
                id: record.id.uuidString,
                storeName: record.supplier,
                purchaseDate: record.datePurchased,
                totalCost: record.totalPrice,
                currency: record.currency,
                notes: record.notes,
                dateCreated: record.dateAdded,
                items: items
            )
        }

        try writeJSONFile(exportRecords, to: directory.appendingPathComponent(ExportFileName.purchaseRecords.rawValue))

        return ExportEntityCounts(
            glassItems: currentCounts.glassItems,
            inventoryRecords: currentCounts.inventoryRecords,
            projects: currentCounts.projects,
            logbookEntries: currentCounts.logbookEntries,
            purchaseRecords: exportRecords.count,
            userImages: currentCounts.userImages,
            userNotes: currentCounts.userNotes
        )
    }

    private func exportUserImages(to directory: URL, currentCounts: ExportEntityCounts) async throws -> ExportEntityCounts {
        #if os(iOS)
        // Get all standalone images and images for all owner types
        let standaloneImages = try await userImageRepository.getStandaloneImages()

        // Note: Getting all images across all owners requires iterating through all possible owners
        // For now, just export standalone images. Full implementation would need a getAllImages method.
        let images = standaloneImages

        let exportImages = try await images.asyncMap { image in
            // Load the actual image data if available
            var imageDataBase64: String? = nil
            if let uiImage = try? await userImageRepository.loadImage(image),
               let imageData = uiImage.jpegData(compressionQuality: 0.9) {
                imageDataBase64 = imageData.base64EncodedString()
            }

            return ExportUserImage(
                id: image.id.uuidString,
                ownerType: image.ownerType.rawValue,
                ownerId: image.ownerId,
                imageType: image.imageType.rawValue,
                fileExtension: image.fileExtension,
                dateCreated: image.dateCreated,
                dateModified: image.dateModified,
                imageDataBase64: imageDataBase64
            )
        }

        try writeJSONFile(exportImages, to: directory.appendingPathComponent(ExportFileName.userImages.rawValue))

        return ExportEntityCounts(
            glassItems: currentCounts.glassItems,
            inventoryRecords: currentCounts.inventoryRecords,
            projects: currentCounts.projects,
            logbookEntries: currentCounts.logbookEntries,
            purchaseRecords: currentCounts.purchaseRecords,
            userImages: exportImages.count,
            userNotes: currentCounts.userNotes
        )
        #else
        return currentCounts
        #endif
    }

    private func exportUserNotes(to directory: URL, currentCounts: ExportEntityCounts) async throws -> ExportEntityCounts {
        // Note: UserNotesRepository doesn't have fetchAllNotes, would need to iterate through all items
        // For now, export empty array. Full implementation would need a getAllNotes method.
        let notes: [UserNotesModel] = []

        let exportNotes = notes.map { note in
            ExportUserNote(
                id: note.id.uuidString,
                itemStableId: note.item_stable_id,
                noteText: note.notes,
                dateCreated: nil,
                dateModified: nil
            )
        }

        try writeJSONFile(exportNotes, to: directory.appendingPathComponent(ExportFileName.userNotes.rawValue))

        return ExportEntityCounts(
            glassItems: currentCounts.glassItems,
            inventoryRecords: currentCounts.inventoryRecords,
            projects: currentCounts.projects,
            logbookEntries: currentCounts.logbookEntries,
            purchaseRecords: currentCounts.purchaseRecords,
            userImages: currentCounts.userImages,
            userNotes: exportNotes.count
        )
    }

    // MARK: - Helper Methods

    private func createMetadataFile(at directory: URL, entityCounts: ExportEntityCounts, configuration: DataExportConfiguration) async throws {
        let metadata = DataExportContainer(
            exportVersion: DataExportContainer.currentVersion,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            includesImages: configuration.includeImages,
            entityCounts: entityCounts
        )

        try writeJSONFile(metadata, to: directory.appendingPathComponent(ExportFileName.metadata.rawValue))
    }

    private func writeJSONFile<T: Encodable>(_ data: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(data)
        try jsonData.write(to: url)
    }

    private func createTempExportDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MoltenExport_\(UUID().uuidString)")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )

        return tempDir
    }

    private func calculateDirectorySize(_ url: URL) throws -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            if resourceValues.isRegularFile == true {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }

        return totalSize
    }
}

// MARK: - Errors

enum DataExportError: Error, LocalizedError {
    case exportFailed(String)
    case zipCreationFailed(Error)
    case fileSystemError(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .zipCreationFailed(let error):
            return "Failed to create zip file: \(error.localizedDescription)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Async Sequence Helpers

extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results: [T] = []
        for element in self {
            try await results.append(transform(element))
        }
        return results
    }

    func asyncCompactMap<T>(_ transform: (Element) async throws -> T?) async rethrows -> [T] {
        var results: [T] = []
        for element in self {
            if let result = try await transform(element) {
                results.append(result)
            }
        }
        return results
    }
}
