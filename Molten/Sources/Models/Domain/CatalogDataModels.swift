//
//  CatalogDataModels.swift
//  Flameworker
//
//  Created by Assistant on 9/28/25.
//

import Foundation

// MARK: - Metadata Models

/// Metadata about the catalog JSON file for debugging and version tracking
nonisolated struct CatalogMetadata: Codable, Sendable {
    let version: String
    let generated: String  // ISO 8601 timestamp
    let itemCount: Int?    // Optional for backward compatibility

    enum CodingKeys: String, CodingKey {
        case version
        case generated
        case itemCount = "item_count"
    }
}

// MARK: - JSON Wrapper Structures

/// Expected JSON format: { "version": "1.0", "generated": "...", "item_count": 3, "glassitems": [...] }
nonisolated struct WrappedGlassItemsData: Decodable, Sendable {
    let metadata: CatalogMetadata
    let glassitems: [CatalogItemData]

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Extract metadata
        let version = try container.decode(String.self, forKey: .version)
        let generated = try container.decode(String.self, forKey: .generated)
        let itemCount = try? container.decode(Int.self, forKey: .itemCount)

        self.metadata = CatalogMetadata(version: version, generated: generated, itemCount: itemCount)
        self.glassitems = try container.decode([CatalogItemData].self, forKey: .glassitems)
    }

    enum CodingKeys: String, CodingKey {
        case version
        case generated
        case itemCount = "item_count"
        case glassitems
    }
}

// MARK: - Catalog Item Data Model

/// Data transfer object for decoding glass items from JSON
nonisolated struct CatalogItemData: Decodable, Sendable {
    let id: String?
    let code: String
    let name: String
    let full_name: String?
    let manufacturer: String?
    let manufacturer_description: String?
    let tags: [String]?
    let image_path: String?
    let synonyms: [String]?
    let coe: String?
    let stock_type: String?
    let image_url: String?
    let manufacturer_url: String?
    
    // Custom initializer to handle different JSON structures
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle id - optional field
        self.id = try? container.decode(String.self, forKey: .id)
        
        // Handle code - might be string or number
        if let codeString = try? container.decode(String.self, forKey: .code) {
            self.code = codeString
        } else if let codeInt = try? container.decode(Int.self, forKey: .code) {
            self.code = String(codeInt)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .code, in: container, debugDescription: "Code must be string or number")
        }
        
        // Handle name - should be string
        self.name = try container.decode(String.self, forKey: .name)
        
        // Handle optional fields with fallbacks
        self.full_name = try? container.decode(String.self, forKey: .full_name)
        self.manufacturer = try? container.decode(String.self, forKey: .manufacturer)
        self.manufacturer_description = try? container.decode(String.self, forKey: .manufacturer_description)
        
        // Handle tags - can be array or malformed string
        if let tagsArray = try? container.decode([String].self, forKey: .tags) {
            self.tags = tagsArray
        } else if let tagsString = try? container.decode(String.self, forKey: .tags) {
            // Handle malformed tags like "\"black\", \"purple\""
            // Split by comma and remove quotes
            self.tags = tagsString
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { $0.replacingOccurrences(of: "\"", with: "") }
                .filter { !$0.isEmpty && $0 != "unknown" }
        } else {
            self.tags = nil
        }
        
        // Handle image_path - optional field
        self.image_path = try? container.decode(String.self, forKey: .image_path)
        
        // Handle synonyms - can be array or malformed string
        if let synonymsArray = try? container.decode([String].self, forKey: .synonyms) {
            self.synonyms = synonymsArray
        } else if let synonymsString = try? container.decode(String.self, forKey: .synonyms) {
            // Handle malformed synonyms like "\"word1\", \"word2\""
            // Split by comma and remove quotes
            self.synonyms = synonymsString
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { $0.replacingOccurrences(of: "\"", with: "") }
                .filter { !$0.isEmpty }
        } else {
            self.synonyms = nil
        }
        
        // Handle COE (Coefficient of Expansion) - optional field
        // COE might be stored as string or number, normalize to string
        if let coeString = try? container.decode(String.self, forKey: .coe) {
            self.coe = coeString
        } else if let coeInt = try? container.decode(Int.self, forKey: .coe) {
            self.coe = String(coeInt)
        } else if let coeDouble = try? container.decode(Double.self, forKey: .coe) {
            self.coe = String(format: "%.0f", coeDouble)
        } else {
            self.coe = nil
        }
        
        // Handle new optional fields
        self.stock_type = try? container.decode(String.self, forKey: .stock_type)
        self.image_url = try? container.decode(String.self, forKey: .image_url)
        self.manufacturer_url = try? container.decode(String.self, forKey: .manufacturer_url)
    }
    
    // Regular initializer for programmatic creation
    nonisolated init(id: String?, code: String, manufacturer: String?, name: String, manufacturer_description: String?, synonyms: [String]?, tags: [String]?, image_path: String?, coe: String?, stock_type: String? = nil, image_url: String? = nil, manufacturer_url: String? = nil) {
        self.id = id
        self.code = code
        self.name = name
        self.full_name = nil
        self.manufacturer = manufacturer
        self.manufacturer_description = manufacturer_description
        self.tags = tags
        self.image_path = image_path
        self.synonyms = synonyms
        self.coe = coe
        self.stock_type = stock_type
        self.image_url = image_url
        self.manufacturer_url = manufacturer_url
    }
    
    // Helper method to parse dates from various formats
    nonisolated private static func parseDate(from dateString: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd",
            "MM/dd/yyyy", 
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss"
        ]
        
        for formatString in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = formatString
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        print("⚠️ Could not parse date: \(dateString)")
        return nil
    }
    
    // Custom keys mapping for different JSON field names
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case code = "code"
        case name = "name"
        case full_name = "full_name"
        case manufacturer = "manufacturer"
        case manufacturer_description = "manufacturer_description"
        case end_date = "end_date"
        case tags = "tags"
        case image_path = "image_path"
        case synonyms = "synonyms"
        case coe = "coe"
        case stock_type = "stock_type"
        case image_url = "image_url"
        case manufacturer_url = "manufacturer_url"
        
        // Alternative key names your JSON might use
        case fullName = "fullName"
        case manufacturerDescription = "manufacturerDescription"
        case endDate = "endDate"
        case imagePath = "imagePath"
        case COE = "COE"
        case stockType = "stockType"
        case imageUrl = "imageUrl"
        case manufacturerUrl = "manufacturerUrl"
    }
}