//
//  LocationService.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Foundation
import CoreData

/// Service for managing inventory item locations and providing auto-complete suggestions
class LocationService {
    static let shared = LocationService()
    
    private init() {}
    
    /// Retrieves unique locations from existing inventory items for auto-complete
    func getUniqueLocations(from context: NSManagedObjectContext) -> [String] {
        let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        
        do {
            let items = try context.fetch(fetchRequest)
            
            // Extract non-empty locations, make unique, and sort
            let locations = items
                .compactMap { $0.location }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            // Remove duplicates and sort
            let uniqueLocations = Set(locations)
            return uniqueLocations.sorted()
            
        } catch {
            print("❌ Failed to fetch inventory items for location suggestions: \(error)")
            return []
        }
    }
    
    /// Filters locations based on search text for auto-complete
    func getLocationSuggestions(matching searchText: String, from context: NSManagedObjectContext) -> [String] {
        let allLocations = getUniqueLocations(from: context)
        
        guard !searchText.isEmpty else {
            return allLocations
        }
        
        let lowercaseSearch = searchText.lowercased()
        return allLocations.filter { location in
            location.lowercased().contains(lowercaseSearch)
        }
    }
}