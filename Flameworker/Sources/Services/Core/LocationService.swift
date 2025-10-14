//
//  LocationService.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Foundation

/// Service for managing inventory item locations using repository pattern
class LocationService {
    private let inventoryService: InventoryService
    
    /// Initialize with inventory service dependency injection
    init(inventoryService: InventoryService) {
        self.inventoryService = inventoryService
    }
    
    /// Convenience initializer for shared singleton with default service
    static let shared = LocationService(
        inventoryService: InventoryService(repository: LegacyCoreDataInventoryRepository())
    )
    
    /// Retrieves unique locations from existing inventory items using repository pattern
    func getUniqueLocations() async throws -> [String] {
        // Get all inventory items via service layer
        let items = try await inventoryService.getAllItems()
        
        // Extract non-empty locations, make unique, and sort
        let locations = items
            .compactMap { $0.notes } // Use notes field for location data from business model
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Remove duplicates and sort
        let uniqueLocations = Set(locations)
        return uniqueLocations.sorted()
    }
    
    /// Filters locations based on search text using repository pattern
    func getLocationSuggestions(matching searchText: String) async throws -> [String] {
        let allLocations = try await getUniqueLocations()
        
        guard !searchText.isEmpty else {
            return allLocations
        }
        
        let lowercaseSearch = searchText.lowercased()
        return allLocations.filter { location in
            location.lowercased().contains(lowercaseSearch)
        }
    }
}
