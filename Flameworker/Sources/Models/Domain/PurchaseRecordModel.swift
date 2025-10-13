//
//  PurchaseRecordModel.swift
//  Flameworker
//
//  Created by Repository Pattern Migration on 10/12/25.
//

import Foundation

/// Business model for purchase records with validation and business logic
struct PurchaseRecordModel: Identifiable, Equatable, Codable {
    let id: String
    let supplier: String
    let price: Double
    let dateAdded: Date
    let notes: String?
    
    /// Initialize with business logic validation
    init(id: String = UUID().uuidString, supplier: String, price: Double, dateAdded: Date = Date(), notes: String? = nil) {
        self.id = id
        self.supplier = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.price = price
        self.dateAdded = dateAdded
        self.notes = notes?.isEmpty == true ? nil : notes
    }
    
    // MARK: - Business Logic
    
    /// Display name combining supplier and price
    var displayName: String {
        return "\(supplier) - \(formattedPrice)"
    }
    
    /// Check if record matches search text
    func matchesSearchText(_ searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()
        return supplier.lowercased().contains(lowercaseSearch) ||
               (notes?.lowercased().contains(lowercaseSearch) ?? false)
    }
    
    /// Formatted price for display
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
    
    /// Formatted date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dateAdded)
    }
    
    /// Check if record has notes
    var hasNotes: Bool {
        return notes?.isEmpty == false
    }
    
    /// Check if record falls within date range
    func isWithinDateRange(from startDate: Date, to endDate: Date) -> Bool {
        return dateAdded >= startDate && dateAdded <= endDate
    }
    
    /// Compare records for changes (useful for updates)
    static func hasChanges(existing: PurchaseRecordModel, new: PurchaseRecordModel) -> Bool {
        return existing.supplier != new.supplier ||
               existing.price != new.price ||
               existing.dateAdded != new.dateAdded ||
               existing.notes != new.notes
    }
    
    // MARK: - Validation
    
    /// Validate that the record has required data
    var isValid: Bool {
        return !supplier.isEmpty && price > 0
    }
    
    /// Get validation errors if any
    var validationErrors: [String] {
        var errors: [String] = []
        
        if supplier.isEmpty {
            errors.append("Supplier name is required")
        }
        
        if price <= 0 {
            errors.append("Price must be greater than 0")
        }
        
        return errors
    }
}

// MARK: - Helper Extensions

extension PurchaseRecordModel {
    /// Create a purchase record from a dictionary (useful for JSON parsing)
    static func from(dictionary: [String: Any]) -> PurchaseRecordModel? {
        guard let supplier = dictionary["supplier"] as? String,
              let price = dictionary["price"] as? Double else {
            return nil
        }
        
        let id = dictionary["id"] as? String ?? UUID().uuidString
        let dateAdded = dictionary["dateAdded"] as? Date ?? Date()
        let notes = dictionary["notes"] as? String
        
        return PurchaseRecordModel(
            id: id,
            supplier: supplier,
            price: price,
            dateAdded: dateAdded,
            notes: notes
        )
    }
    
    /// Convert to dictionary (useful for storage or API calls)
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "supplier": supplier,
            "price": price,
            "dateAdded": dateAdded
        ]
        
        if let notes = notes {
            dict["notes"] = notes
        }
        
        return dict
    }
}