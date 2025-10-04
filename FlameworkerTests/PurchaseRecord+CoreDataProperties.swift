//
//  PurchaseRecord+CoreDataProperties.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Foundation
import CoreData

extension PurchaseRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PurchaseRecord> {
        return NSFetchRequest<PurchaseRecord>(entityName: "PurchaseRecord")
    }

    @NSManaged public var supplier: String?
    @NSManaged public var price: Double
    @NSManaged public var date_added: Date?
    @NSManaged public var notes: String?
    @NSManaged public var type: Int16
    @NSManaged public var units: Int16
    @NSManaged public var id: String?
    @NSManaged public var catalog_code: String?
    @NSManaged public var count: Double

}

extension PurchaseRecord : Identifiable {

}

// MARK: - DisplayableEntity Conformance
// Note: DisplayableEntity conformance moved to avoid compilation issues
// The conformance will be handled in a separate extension file