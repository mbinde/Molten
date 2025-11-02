//
//  RecipeModel.swift
//  Molten
//
//  Domain models for Recipes
//

import Foundation

// MARK: - FritMeasurementType

/// How measurements are interpreted in a frit recipe
enum FritMeasurementType: String, Codable, CaseIterable, Sendable {
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

// MARK: - FritIngredientModel

/// Represents a single ingredient in a frit recipe
struct FritIngredientModel: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let stableId: String  // References a GlassItem in Local Store (cross-store reference)
    let amount: Double    // Interpreted based on parent recipe's measurementType

    nonisolated init(id: UUID = UUID(), stableId: String, amount: Double) {
        self.id = id
        self.stableId = stableId
        self.amount = amount
    }
}

// MARK: - FritRecipeModel

/// Represents a recipe for mixing glass frit
struct FritRecipeModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let descriptionText: String
    let measurementType: FritMeasurementType
    let ingredients: [FritIngredientModel]
    let dateCreated: Date
    let dateModified: Date

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        descriptionText: String,
        measurementType: FritMeasurementType,
        ingredients: [FritIngredientModel],
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.measurementType = measurementType
        self.ingredients = ingredients
        self.dateCreated = dateCreated
        self.dateModified = dateModified
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
    nonisolated func withUpdatedModificationDate() -> FritRecipeModel {
        FritRecipeModel(
            id: id,
            title: title,
            descriptionText: descriptionText,
            measurementType: measurementType,
            ingredients: ingredients,
            dateCreated: dateCreated,
            dateModified: Date()
        )
    }
}

// MARK: - Hashable Conformance

extension FritRecipeModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
