//
//  Inventory+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias InventoryCoreDataPropertiesSet = NSSet

extension Inventory {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Inventory> {
        return NSFetchRequest<Inventory>(entityName: "Inventory")
    }

    @NSManaged public var date_added: Date?
    @NSManaged public var date_modified: Date?
    @NSManaged public var dimensions_x: String?
    @NSManaged public var dimensions_y: String?
    @NSManaged public var dimensions_z: String?
    @NSManaged public var id: UUID?
    @NSManaged public var item_natural_key: String?
    @NSManaged public var quantity: Double
    @NSManaged public var subsubtype: String?
    @NSManaged public var subtype: String?
    @NSManaged public var type: String?

}

extension Inventory : Identifiable {

}
