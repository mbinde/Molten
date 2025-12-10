//
//  DataExportModels.swift
//  Molten
//
//  Codable models for JSON data export
//

import Foundation

// MARK: - Export Configuration

struct DataExportConfiguration: Sendable {
    let includeImages: Bool
    let includeUserNotes: Bool
    let includeArchivedProjects: Bool

    init(
        includeImages: Bool = true,
        includeUserNotes: Bool = true,
        includeArchivedProjects: Bool = false
    ) {
        self.includeImages = includeImages
        self.includeUserNotes = includeUserNotes
        self.includeArchivedProjects = includeArchivedProjects
    }

    static let `default` = DataExportConfiguration()
}

struct DataExportResult: Sendable {
    let fileURL: URL
    let exportDate: Date
    let fileSize: Int64
    let includedImages: Bool
    let entityCounts: ExportEntityCounts
}

struct ExportEntityCounts: Codable, Sendable {
    let glassItems: Int
    let inventoryRecords: Int
    let projects: Int
    let logbookEntries: Int
    let purchaseRecords: Int
    let userImages: Int
    let userNotes: Int

    var total: Int {
        glassItems + inventoryRecords + projects + logbookEntries + purchaseRecords + userImages + userNotes
    }
}

// MARK: - Export Wrapper

/// Container for all exported data with metadata
struct DataExportContainer: Codable, Sendable {
    let exportVersion: String
    let exportDate: Date
    let appVersion: String
    let includesImages: Bool
    let entityCounts: ExportEntityCounts

    static let currentVersion = "1.0"
}

// MARK: - Exportable Entity Models

struct ExportGlassItem: Codable, Sendable {
    let stableId: String
    let naturalKey: String?
    let name: String
    let sku: String?  // Optional - some manufacturers don't use SKUs
    let manufacturer: String
    let description: String?
    let coe: Int32
    let url: String?
    let manufacturerStatus: String
    let imageUrl: String?
    let imagePath: String?
    let dateAdded: Date?

    static func from(_ model: GlassItemModel) -> ExportGlassItem {
        ExportGlassItem(
            stableId: model.stable_id,
            naturalKey: model.stable_id,
            name: model.name,
            sku: model.sku,
            manufacturer: model.manufacturer,
            description: model.mfr_notes,
            coe: model.coe,
            url: model.url,
            manufacturerStatus: model.mfr_status,
            imageUrl: model.image_url,
            imagePath: model.image_path,
            dateAdded: nil
        )
    }
}

struct ExportInventory: Codable, Sendable {
    let id: String
    let itemStableId: String
    let type: String
    let subtype: String?
    let subsubtype: String?
    let dimensions: [String: Double]?
    let quantity: Double
    let location: String?
    let dateAdded: Date
    let dateModified: Date

    static func from(_ model: InventoryModel) -> ExportInventory {
        ExportInventory(
            id: model.id.uuidString,
            itemStableId: model.item_stable_id,
            type: model.type,
            subtype: model.subtype,
            subsubtype: model.subsubtype,
            dimensions: model.dimensions,
            quantity: model.quantity,
            location: model.location,
            dateAdded: model.date_added,
            dateModified: model.date_modified
        )
    }
}

struct ExportProject: Codable, Sendable {
    let id: String
    let title: String
    let summary: String?
    let projectType: String?
    let coe: String?
    let difficultyLevel: String?
    let estimatedTime: Double?
    let proposedPriceMin: Decimal?
    let proposedPriceMax: Decimal?
    let priceCurrency: String?
    let dateCreated: Date
    let dateModified: Date
    let isArchived: Bool
    let heroImageId: String?
    let glassItems: [ExportProjectGlassItem]
    let images: [ExportProjectImage]
    let steps: [ExportProjectStep]
    let referenceUrls: [ExportProjectReferenceUrl]
}

struct ExportProjectGlassItem: Codable, Sendable {
    let id: String
    let itemStableId: String?
    let item_stable_id: String?
    let freeformDescription: String?
    let quantity: Double?
    let unit: String?
    let notes: String?
    let orderIndex: Int32?
}

struct ExportProjectImage: Codable, Sendable {
    let id: String
    let fileName: String?
    let caption: String?
    let fileExtension: String?
    let dateAdded: Date?
    let orderIndex: Int32?
}

struct ExportProjectStep: Codable, Sendable {
    let id: String
    let stepDescription: String?
    let orderIndex: Int32?
    let glassItems: [ExportProjectStepGlassItem]
}

struct ExportProjectStepGlassItem: Codable, Sendable {
    let id: String
    let itemStableId: String?
    let quantity: Double?
    let unit: String?
}

struct ExportProjectReferenceUrl: Codable, Sendable {
    let id: String
    let url: String?
    let title: String?
    let urlDescription: String?
    let dateAdded: Date?
    let orderIndex: Int32?
}

struct ExportLogbookEntry: Codable, Sendable {
    let id: String
    let title: String
    let entryDescription: String?
    let entryType: String?
    let dateCreated: Date
    let dateModified: Date
    let glassItems: [ExportLogbookGlassItem]
    let images: [ExportProjectImage] // Reuse same structure
}

struct ExportLogbookGlassItem: Codable, Sendable {
    let id: String
    let itemStableId: String?
    let quantity: Double?
    let unit: String?
    let notes: String?
}

struct ExportPurchaseRecord: Codable, Sendable {
    let id: String
    let storeName: String?
    let purchaseDate: Date
    let totalCost: Decimal?
    let currency: String?
    let notes: String?
    let dateCreated: Date
    let items: [ExportPurchaseRecordItem]
}

struct ExportPurchaseRecordItem: Codable, Sendable {
    let id: String
    let itemStableId: String?
    let quantity: Double?
    let unitPrice: Decimal?
    let totalPrice: Decimal?
}

struct ExportUserImage: Codable, Sendable {
    let id: String
    let ownerType: String?
    let ownerId: String?
    let imageType: String?
    let fileExtension: String?
    let dateCreated: Date?
    let dateModified: Date?
    let imageDataBase64: String? // Base64 encoded image data
}

struct ExportUserNote: Codable, Sendable {
    let id: String  // UUID exported as String for JSON compatibility
    let itemStableId: String?
    let noteText: String?
    let dateCreated: Date?
    let dateModified: Date?
}

// MARK: - Export File Names

enum ExportFileName: String, CaseIterable {
    case metadata = "export_metadata.json"
    case glassItems = "glass_items.json"
    case inventory = "inventory.json"
    case projects = "projects.json"
    case logbook = "logbook.json"
    case purchaseRecords = "purchase_records.json"
    case userImages = "user_images.json"
    case userNotes = "user_notes.json"

    var displayName: String {
        switch self {
        case .metadata: return "Export Metadata"
        case .glassItems: return "Glass Items"
        case .inventory: return "Inventory"
        case .projects: return "Projects"
        case .logbook: return "Logbook Entries"
        case .purchaseRecords: return "Purchase Records"
        case .userImages: return "User Images"
        case .userNotes: return "User Notes"
        }
    }
}
