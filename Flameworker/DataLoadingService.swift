//
//  DataLoadingService.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//

import Foundation
import CoreData

class DataLoadingService {
    static let shared = DataLoadingService()
    
    private init() {}
    
    func loadCatalogItemsFromJSON(into context: NSManagedObjectContext) async throws {
        // Loading JSON file from Data subdirectory
        guard let url = Bundle.main.url(forResource: "effetre", withExtension: "json", subdirectory: "Data"),
              let data = try? Data(contentsOf: url) else {
            throw DataLoadingError.fileNotFound("Could not find or load Data/effetre.json")
        }
        
        // Check if items already exist to avoid duplicates
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let existingCatalogItemsCount = try context.count(for: fetchRequest)
        
        guard existingCatalogItemsCount == 0 else {
            print("CatalogItems already exist in Core Data, skipping JSON load")
            return
        }
        
        let decoder = JSONDecoder()
        
        // Configure date decoding strategy
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // Adjust this to match your JSON date format
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        
        let jsonCatalogItems = try decoder.decode([CatalogItemData].self, from: data)
        
        // Perform Core Data operations on the main actor
        await MainActor.run {
            for catalogItemData in jsonCatalogItems {
                let newCatalogItem = CatalogItem(context: context)
                newCatalogItem.code = catalogItemData.code
                newCatalogItem.name = catalogItemData.name
                newCatalogItem.full_name = catalogItemData.full_name
                newCatalogItem.manufacturer = catalogItemData.manufacturer
                newCatalogItem.start_date = catalogItemData.start_date
                newCatalogItem.end_date = catalogItemData.end_date
            }
            
            do {
                try context.save()
                print("Successfully loaded \(jsonCatalogItems.count) items from JSON")
            } catch {
                print("Error saving to Core Data: \(error)")
            }
        }
    }
}

enum DataLoadingError: Error, LocalizedError {
    case fileNotFound(String)
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let message):
            return message
        case .decodingFailed(let message):
            return message
        }
    }
}

// You'd need a struct to match your JSON structure
struct CatalogItemData: Codable {
    let code: String
    let name: String
    let full_name: String
    let manufacturer: String
    let start_date: Date
    let end_date: Date
}