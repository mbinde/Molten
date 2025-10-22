//
//  InventoryItem+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias InventoryItemCoreDataPropertiesSet = NSSet

extension InventoryItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<InventoryItem> {
        return NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
    }

    @NSManaged public var catalog_code: String?
    @NSManaged public var count: Double
    @NSManaged public var id: String?
    @NSManaged public var location: String?
    @NSManaged public var notes: String?
    @NSManaged public var purchase_record_id: String?
    @NSManaged public var type: Int16

}

extension InventoryItem : Identifiable {

}
