//
//  CatalogItem+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias CatalogItemCoreDataPropertiesSet = NSSet

extension CatalogItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CatalogItem> {
        return NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
    }

    @NSManaged public var code: String?
    @NSManaged public var coe: Int16
    @NSManaged public var id: String?
    @NSManaged public var id2: UUID?
    @NSManaged public var image_path: String?
    @NSManaged public var image_url: String?
    @NSManaged public var item_subtype: String?
    @NSManaged public var item_type: String?
    @NSManaged public var manufacturer: String?
    @NSManaged public var manufacturer_description: String?
    @NSManaged public var manufacturer_url: String?
    @NSManaged public var name: String?
    @NSManaged public var parent: UUID?
    @NSManaged public var stock_type: String?
    @NSManaged public var tags: String?
    @NSManaged public var units: Int16

}

extension CatalogItem : Identifiable {

}
