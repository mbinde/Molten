import Foundation
import CoreData

/// Enumeration representing the units for an InventoryItem
enum InventoryUnits: Int16, CaseIterable, Identifiable {
    case rods = 1
    case ounces = 2
    case pounds = 3
    case grams = 4
    case kilograms = 5
    
    var id: Int16 { rawValue }
    
    /// Human-readable display name for the units
    var displayName: String {
        switch self {
        case .rods:
            return "Rods"
        case .ounces:
            return "oz"
        case .pounds:
            return "lb"
        case .grams:
            return "g"
        case .kilograms:
            return "kg"
        }
    }
    
}

// MARK: - InventoryItem Convenience

extension InventoryItem {
    /// Get the related catalog item's units, with fallback to .rods
    var unitsKind: InventoryUnits {
        guard !self.isDeleted,
              let catalogCode = self.catalog_code,
              !catalogCode.isEmpty,
              let context = self.managedObjectContext else { 
            return .rods 
        }
        
        // Create fetch request with manual entity configuration for safety
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        
        // Ensure entity is properly configured to prevent "fetch request must have an entity" crash
        guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            print("❌ Could not find CatalogItem entity in context")
            return .rods
        }
        fetchRequest.entity = entity
        fetchRequest.predicate = NSPredicate(format: "id == %@ OR code == %@", catalogCode, catalogCode)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            if let catalogItem = results.first {
                return InventoryUnits(rawValue: catalogItem.units) ?? .rods
            }
        } catch {
            print("❌ Failed to fetch catalog item units: \(error)")
        }
        
        return .rods
    }
    
    /// Display string for units
    var unitsDisplayName: String { 
        guard !self.isDeleted else { return "Unknown" }
        return unitsKind.displayName 
    }
    
    /// Get converted count and unit display info based on user preferences
    var displayInfo: (count: Double, unit: String) {
        // Safely access Core Data properties to prevent EXC_BAD_ACCESS
        guard !self.isDeleted else {
            return (count: 0.0, unit: "Unknown")
        }
        
        let units = unitsKind
        let formattedUnits = units.displayName
        
        return (count: count, unit: formattedUnits)
    }
    
    /// Formatted display string for count with units
    var formattedCountWithUnits: String {
        // Safely access Core Data properties to prevent EXC_BAD_ACCESS
        guard !self.isDeleted else {
            return "0 Unknown"
        }
        
        let info = displayInfo
        
        // Format number without unnecessary decimal places
        let formattedCount: String
        if info.count.truncatingRemainder(dividingBy: 1) == 0 {
            // Whole number - show without decimal
            formattedCount = String(format: "%.0f", info.count)
        } else {
            // Has decimal part - show one decimal place
            formattedCount = String(format: "%.1f", info.count)
        }
        
        return formattedCount + " " + info.unit
    }
}
