//
//  RecipeModel.swift
//  Molten
//
//  Domain models for Recipes
//

import Foundation

// MARK: - MeasurementType

/// How measurements are interpreted in a recipe
enum MeasurementType: String, Codable, CaseIterable, Sendable {
    case byWeight = "weight"
    case byRatio = "ratio"

    nonisolated var displayName: String {
        switch self {
        case .byWeight:
            return "By Weight"
        case .byRatio:
            return "By Ratio"
        }
    }
}

// MARK: - RecipeIngredientModel

/// Represents a single ingredient in a recipe
struct RecipeIngredientModel: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let stableId: String  // References a GlassItem in Local Store (cross-store reference)
    let amount: Double    // Interpreted based on parent recipe's measurementType

    nonisolated init(id: UUID = UUID(), stableId: String, amount: Double) {
        self.id = id
        self.stableId = stableId
        self.amount = amount
    }
}

// MARK: - RecipeModel

/// Represents a recipe for mixing glass
struct RecipeModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let descriptionText: String
    let measurementType: MeasurementType
    let ingredients: [RecipeIngredientModel]
    let dateCreated: Date
    let dateModified: Date

    // Future-proofing fields (added pre-release for easier migrations)
    let workspace_id: UUID?  // For multi-inventory sets: references Workspace entity

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        descriptionText: String,
        measurementType: MeasurementType,
        ingredients: [RecipeIngredientModel],
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        workspace_id: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.measurementType = measurementType
        self.ingredients = ingredients
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.workspace_id = workspace_id
    }

    // MARK: - Business Rules / Validation

    /// Validates if a title is acceptable for a recipe
    /// - Parameter title: The title to validate
    /// - Returns: True if valid, false otherwise
    nonisolated static func isValidTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 100
    }

    /// Creates a copy with updated modification date
    nonisolated func withUpdatedModificationDate() -> RecipeModel {
        RecipeModel(
            id: id,
            title: title,
            descriptionText: descriptionText,
            measurementType: measurementType,
            ingredients: ingredients,
            dateCreated: dateCreated,
            dateModified: Date(),
            workspace_id: workspace_id
        )
    }
}

// MARK: - Hashable Conformance

extension RecipeModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
