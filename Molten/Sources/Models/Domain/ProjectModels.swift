//
//  ProjectModels.swift
//  Flameworker
//
//  Domain models for Project Plan and Project Log system
//

import Foundation

// MARK: - Project Glass Item

/// Represents a glass item with quantity needed for a project
/// Supports fractional quantities (e.g., 0.5 rods, 2.3 oz)
/// Can reference a catalog item OR be free-form text
nonisolated struct ProjectGlassItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let stableId: String?              // Reference to glass item (e.g., "bullseye-clear-0"), nil for free-form
    let freeformDescription: String?     // For non-catalog items: what user typed ("any dark transparent")
    let quantity: Decimal                // Amount needed (fractional, e.g., 0.5 rods)
    let unit: String                     // "rods", "grams", "oz" (matches inventory units)
    let notes: String?                   // Optional context for ANY item ("for the base layer")

    /// True if this is a catalog item reference, false if free-form
    var isCatalogItem: Bool {
        stableId != nil
    }

    /// Display name for this glass item
    var displayName: String {
        if let stableId = stableId {
            return stableId  // Will be replaced with actual name in UI
        } else if let freeformDescription = freeformDescription {
            return freeformDescription
        } else {
            return "Unknown glass"
        }
    }

    /// Initialize with a catalog item reference (notes optional)
    nonisolated init(id: UUID = UUID(), stableId: String, quantity: Decimal, unit: String = "rods", notes: String? = nil) {
        self.id = id
        self.stableId = stableId
        self.freeformDescription = nil
        self.quantity = quantity
        self.unit = unit
        self.notes = notes
    }

    /// Initialize with free-form description (no catalog reference, notes optional)
    nonisolated init(id: UUID = UUID(), freeformDescription: String, quantity: Decimal, unit: String = "rods", notes: String? = nil) {
        self.id = id
        self.stableId = nil
        self.freeformDescription = freeformDescription
        self.quantity = quantity
        self.unit = unit
        self.notes = notes
    }
}

// MARK: - Project Reference URL

/// Represents a reference URL for tutorials, inspiration, etc.
nonisolated struct ProjectReferenceUrl: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let url: String                      // The actual URL
    let title: String?                   // Optional display name
    let description: String?             // Optional notes about this resource
    let dateAdded: Date

    nonisolated init(id: UUID = UUID(), url: String, title: String? = nil, description: String? = nil, dateAdded: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.description = description
        self.dateAdded = dateAdded
    }
}

// MARK: - Enums

enum ProjectType: String, Codable, Sendable {
    case recipe         // Repeatable pattern/design (display as "Instructions")
    case idea           // Future concept to explore
    case technique      // Specific method/process
    case tutorial       // Step-by-step learning resource
    case commission     // Template for custom orders

    var displayName: String {
        switch self {
        case .recipe: return "Instructions"
        case .idea: return "Idea"
        case .technique: return "Technique"
        case .tutorial: return "Tutorial"
        case .commission: return "Commission"
        }
    }
}

enum TechniqueType: String, Codable, Sendable, CaseIterable {
    case glassBlowing = "glass_blowing"
    case flameworking
    case fusing
    case casting
    case other

    var displayName: String {
        switch self {
        case .glassBlowing: return "Glass Blowing"
        case .flameworking: return "Flameworking"
        case .fusing: return "Fusing"
        case .casting: return "Casting"
        case .other: return "Other"
        }
    }
}

enum DifficultyLevel: String, Codable, Sendable {
    case beginner
    case intermediate
    case advanced
    case expert
}

enum ProjectStatus: String, Codable, Sendable {
    case inProgress = "in_progress"
    case completed
    case sold
    case gifted
    case kept                            // Personal collection
    case broken                          // Didn't survive
}

// MARK: - Price Range

nonisolated struct PriceRange: Codable, Hashable, Sendable {
    let min: Decimal?
    let max: Decimal?
    let currency: String  // "USD"

    nonisolated init(min: Decimal? = nil, max: Decimal? = nil, currency: String = "USD") {
        self.min = min
        self.max = max
        self.currency = currency
    }
}

// MARK: - Project Model

nonisolated struct ProjectModel: Identifiable, Hashable, Sendable, Codable {
    // Identity
    let id: UUID
    let title: String
    let type: ProjectType

    // Metadata
    let dateCreated: Date
    let dateModified: Date
    let isArchived: Bool

    // Categorization
    // NOTE: Tags are now managed via UserTagsRepository (TagOwnerType.project)
    // Use ProjectService.getTags(forProject:) to fetch tags
    let coe: String
    let techniqueType: TechniqueType?

    // Content
    let summary: String?
    let steps: [ProjectStepModel]
    let estimatedTime: TimeInterval?
    let difficultyLevel: DifficultyLevel?
    let proposedPriceRange: PriceRange?

    // Attachments
    let images: [ProjectImageModel]
    let heroImageId: UUID?
    let glassItems: [ProjectGlassItem]
    let referenceUrls: [ProjectReferenceUrl]

    // Attribution
    let author: AuthorModel?

    // Usage Tracking
    let timesUsed: Int
    let lastUsedDate: Date?

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        type: ProjectType,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        isArchived: Bool = false,
        coe: String = "any",
        techniqueType: TechniqueType? = nil,
        summary: String? = nil,
        steps: [ProjectStepModel] = [],
        estimatedTime: TimeInterval? = nil,
        difficultyLevel: DifficultyLevel? = nil,
        proposedPriceRange: PriceRange? = nil,
        images: [ProjectImageModel] = [],
        heroImageId: UUID? = nil,
        glassItems: [ProjectGlassItem] = [],
        referenceUrls: [ProjectReferenceUrl] = [],
        author: AuthorModel? = nil,
        timesUsed: Int = 0,
        lastUsedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.isArchived = isArchived
        self.coe = coe
        self.techniqueType = techniqueType
        self.summary = summary
        self.steps = steps
        self.estimatedTime = estimatedTime
        self.difficultyLevel = difficultyLevel
        self.proposedPriceRange = proposedPriceRange
        self.images = images
        self.heroImageId = heroImageId
        self.glassItems = glassItems
        self.referenceUrls = referenceUrls
        self.author = author
        self.timesUsed = timesUsed
        self.lastUsedDate = lastUsedDate
    }
}

// MARK: - Project Step Model

nonisolated struct ProjectStepModel: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let projectId: UUID
    let order: Int
    let title: String
    let description: String?
    let estimatedMinutes: Int?
    let glassItemsNeeded: [ProjectGlassItem]?

    nonisolated init(
        id: UUID = UUID(),
        projectId: UUID,
        order: Int,
        title: String,
        description: String? = nil,
        estimatedMinutes: Int? = nil,
        glassItemsNeeded: [ProjectGlassItem]? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.order = order
        self.title = title
        self.description = description
        self.estimatedMinutes = estimatedMinutes
        self.glassItemsNeeded = glassItemsNeeded
    }
}

// MARK: - Project Image Model

nonisolated struct ProjectImageModel: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let projectId: UUID
    let projectCategory: ProjectCategory
    let fileExtension: String
    let caption: String?
    let dateAdded: Date
    let order: Int

    var fileName: String {
        "\(id.uuidString).\(fileExtension)"
    }

    nonisolated init(
        id: UUID = UUID(),
        projectId: UUID,
        projectCategory: ProjectCategory,
        fileExtension: String,
        caption: String? = nil,
        dateAdded: Date = Date(),
        order: Int = 0
    ) {
        self.id = id
        self.projectId = projectId
        self.projectCategory = projectCategory
        self.fileExtension = fileExtension
        self.caption = caption
        self.dateAdded = dateAdded
        self.order = order
    }
}

enum ProjectCategory: String, Codable, Sendable {
    case plan
    case log
}

// MARK: - Logbook Model

nonisolated struct LogbookModel: Identifiable, Sendable, Codable, Hashable {
    // Identity
    let id: UUID
    let title: String

    // Metadata
    let dateCreated: Date
    let dateModified: Date
    let startDate: Date?
    let completionDate: Date?

    // Source - can link to multiple project plans
    let basedOnProjectIds: [UUID]

    // Categorization
    let tags: [String]
    let coe: String
    let techniqueType: TechniqueType?

    // Content
    let notes: String?
    let techniquesUsed: [String]?

    // Time Tracking
    let hoursSpent: Decimal?

    // Attachments
    let images: [ProjectImageModel]
    let heroImageId: UUID?
    let glassItems: [ProjectGlassItem]

    // Business
    let pricePoint: Decimal?
    let saleDate: Date?
    let buyerInfo: String?
    let status: ProjectStatus

    // Inventory Impact
    let inventoryDeductionRecorded: Bool

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        startDate: Date? = nil,
        completionDate: Date? = nil,
        basedOnProjectIds: [UUID] = [],
        tags: [String] = [],
        coe: String = "any",
        techniqueType: TechniqueType? = nil,
        notes: String? = nil,
        techniquesUsed: [String]? = nil,
        hoursSpent: Decimal? = nil,
        images: [ProjectImageModel] = [],
        heroImageId: UUID? = nil,
        glassItems: [ProjectGlassItem] = [],
        pricePoint: Decimal? = nil,
        saleDate: Date? = nil,
        buyerInfo: String? = nil,
        status: ProjectStatus = .inProgress,
        inventoryDeductionRecorded: Bool = false
    ) {
        self.id = id
        self.title = title
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.startDate = startDate
        self.completionDate = completionDate
        self.basedOnProjectIds = basedOnProjectIds
        self.tags = tags
        self.coe = coe
        self.techniqueType = techniqueType
        self.notes = notes
        self.techniquesUsed = techniquesUsed
        self.hoursSpent = hoursSpent
        self.images = images
        self.heroImageId = heroImageId
        self.glassItems = glassItems
        self.pricePoint = pricePoint
        self.saleDate = saleDate
        self.buyerInfo = buyerInfo
        self.status = status
        self.inventoryDeductionRecorded = inventoryDeductionRecorded
    }
}

// MARK: - Deprecated Type Aliases (for backward compatibility during transition)

@available(*, deprecated, renamed: "ProjectModel")
typealias ProjectPlanModel = ProjectModel

@available(*, deprecated, renamed: "ProjectType")
typealias ProjectPlanType = ProjectType
