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
struct ProjectGlassItem: Identifiable, Codable {
    let id: UUID
    let naturalKey: String               // Reference to glass item (e.g., "bullseye-clear-0")
    let quantity: Decimal                // Amount needed (fractional, e.g., 0.5 rods)
    let unit: String                     // "rods", "grams", "oz" (matches inventory units)
    let notes: String?                   // Optional notes: "for the body", "accent color"

    init(id: UUID = UUID(), naturalKey: String, quantity: Decimal, unit: String = "rods", notes: String? = nil) {
        self.id = id
        self.naturalKey = naturalKey
        self.quantity = quantity
        self.unit = unit
        self.notes = notes
    }
}

// MARK: - Project Reference URL

/// Represents a reference URL for tutorials, inspiration, etc.
struct ProjectReferenceUrl: Identifiable, Codable {
    let id: UUID
    let url: String                      // The actual URL
    let title: String?                   // Optional display name
    let description: String?             // Optional notes about this resource
    let dateAdded: Date

    init(id: UUID = UUID(), url: String, title: String? = nil, description: String? = nil, dateAdded: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.description = description
        self.dateAdded = dateAdded
    }
}

// MARK: - Enums

enum ProjectPlanType: String, Codable {
    case recipe         // Repeatable pattern/design
    case idea           // Future concept to explore
    case technique      // Specific method/process
    case commission     // Template for custom orders
}

enum DifficultyLevel: String, Codable {
    case beginner
    case intermediate
    case advanced
    case expert
}

enum ProjectStatus: String, Codable {
    case inProgress = "in_progress"
    case completed
    case sold
    case gifted
    case kept                            // Personal collection
    case broken                          // Didn't survive
}

// MARK: - Price Range

struct PriceRange: Codable {
    let min: Decimal?
    let max: Decimal?
    let currency: String  // "USD"

    init(min: Decimal? = nil, max: Decimal? = nil, currency: String = "USD") {
        self.min = min
        self.max = max
        self.currency = currency
    }
}

// MARK: - Project Plan Model

struct ProjectPlanModel: Identifiable {
    // Identity
    let id: UUID
    let title: String
    let planType: ProjectPlanType

    // Metadata
    let dateCreated: Date
    let dateModified: Date
    let isArchived: Bool

    // Categorization
    let tags: [String]

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

    // Usage Tracking
    let timesUsed: Int
    let lastUsedDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        planType: ProjectPlanType,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        isArchived: Bool = false,
        tags: [String] = [],
        summary: String? = nil,
        steps: [ProjectStepModel] = [],
        estimatedTime: TimeInterval? = nil,
        difficultyLevel: DifficultyLevel? = nil,
        proposedPriceRange: PriceRange? = nil,
        images: [ProjectImageModel] = [],
        heroImageId: UUID? = nil,
        glassItems: [ProjectGlassItem] = [],
        referenceUrls: [ProjectReferenceUrl] = [],
        timesUsed: Int = 0,
        lastUsedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.planType = planType
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.isArchived = isArchived
        self.tags = tags
        self.summary = summary
        self.steps = steps
        self.estimatedTime = estimatedTime
        self.difficultyLevel = difficultyLevel
        self.proposedPriceRange = proposedPriceRange
        self.images = images
        self.heroImageId = heroImageId
        self.glassItems = glassItems
        self.referenceUrls = referenceUrls
        self.timesUsed = timesUsed
        self.lastUsedDate = lastUsedDate
    }
}

// MARK: - Project Step Model

struct ProjectStepModel: Identifiable {
    let id: UUID
    let planId: UUID
    let order: Int
    let title: String
    let description: String?
    let estimatedMinutes: Int?
    let glassItemsNeeded: [ProjectGlassItem]?

    init(
        id: UUID = UUID(),
        planId: UUID,
        order: Int,
        title: String,
        description: String? = nil,
        estimatedMinutes: Int? = nil,
        glassItemsNeeded: [ProjectGlassItem]? = nil
    ) {
        self.id = id
        self.planId = planId
        self.order = order
        self.title = title
        self.description = description
        self.estimatedMinutes = estimatedMinutes
        self.glassItemsNeeded = glassItemsNeeded
    }
}

// MARK: - Project Image Model

struct ProjectImageModel: Identifiable {
    let id: UUID
    let projectId: UUID
    let projectType: ProjectType
    let fileExtension: String
    let caption: String?
    let dateAdded: Date
    let order: Int

    var fileName: String {
        "\(id.uuidString).\(fileExtension)"
    }

    init(
        id: UUID = UUID(),
        projectId: UUID,
        projectType: ProjectType,
        fileExtension: String,
        caption: String? = nil,
        dateAdded: Date = Date(),
        order: Int = 0
    ) {
        self.id = id
        self.projectId = projectId
        self.projectType = projectType
        self.fileExtension = fileExtension
        self.caption = caption
        self.dateAdded = dateAdded
        self.order = order
    }
}

enum ProjectType: String, Codable {
    case plan
    case log
}

// MARK: - Project Log Model

struct ProjectLogModel: Identifiable {
    // Identity
    let id: UUID
    let title: String

    // Metadata
    let dateCreated: Date
    let dateModified: Date
    let projectDate: Date?

    // Source
    let basedOnPlanId: UUID?

    // Categorization
    let tags: [String]

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

    init(
        id: UUID = UUID(),
        title: String,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        projectDate: Date? = nil,
        basedOnPlanId: UUID? = nil,
        tags: [String] = [],
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
        self.projectDate = projectDate
        self.basedOnPlanId = basedOnPlanId
        self.tags = tags
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
