//
//  CatalogDataModels.swift
//  Flameworker
//
//  Created by Assistant on 9/28/25.
//

import Foundation

// Wrapper struct to handle nested JSON structure like { "colors": [...] }
struct WrappedColorsData: Decodable {
    let colors: [CatalogItemData]
}

// Flexible struct to handle various JSON formats and prevent type mismatches
struct CatalogItemData: Decodable {
    let id: String?
    let code: String
    let name: String
    let full_name: String?
    let manufacturer: String?
    let manufacturer_description: String?
    let start_date: Date?
    let end_date: Date?
    let tags: [String]?
    
    // Custom initializer to handle different JSON structures
    init(from decoder: Decoder) throws {
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
        
        // Handle dates - try multiple formats
        if let dateString = try? container.decode(String.self, forKey: .start_date) {
            self.start_date = Self.parseDate(from: dateString)
        } else {
            self.start_date = nil
        }
        
        if let dateString = try? container.decode(String.self, forKey: .end_date) {
            self.end_date = Self.parseDate(from: dateString)
        } else {
            self.end_date = nil
        }
        
        // Handle tags array - optional field
        self.tags = try? container.decode([String].self, forKey: .tags)
    }
    
    // Helper method to parse dates from various formats
    private static func parseDate(from dateString: String) -> Date? {
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
        case start_date = "start_date"
        case end_date = "end_date"
        case tags = "tags"
        
        // Alternative key names your JSON might use
        case fullName = "fullName"
        case manufacturerDescription = "manufacturerDescription"
        case startDate = "startDate"
        case endDate = "endDate"
    }
}