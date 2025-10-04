//
//  CatalogItem+CoreDataProperties.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Foundation
import CoreData

extension CatalogItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CatalogItem> {
        return NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
    }

    @NSManaged public var id: String?
    @NSManaged public var code: String?
    @NSManaged public var name: String?
    @NSManaged public var manufacturer: String?
    @NSManaged public var manufacturer_description: String?
    @NSManaged public var manufacturer_url: String?
    @NSManaged public var image_path: String?
    @NSManaged public var image_url: String?
    @NSManaged public var coe: String?
    @NSManaged public var stock_type: String?
    @NSManaged public var synonyms: String?
    @NSManaged public var tags: String?

}

extension CatalogItem : Identifiable {

}

// MARK: - DisplayableEntity Conformance
// Note: DisplayableEntity conformance moved to avoid compilation issues
// The conformance will be handled in a separate extension file