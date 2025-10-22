//
//  ItemShopping+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ItemShoppingCoreDataPropertiesSet = NSSet

extension ItemShopping {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ItemShopping> {
        return NSFetchRequest<ItemShopping>(entityName: "ItemShopping")
    }

    @NSManaged public var dateAdded: Date?
    @NSManaged public var dimensions_x: String?
    @NSManaged public var dimensions_y: String?
    @NSManaged public var dimensions_z: String?
    @NSManaged public var id: UUID?
    @NSManaged public var item_natural_key: String?
    @NSManaged public var quantity: Double
    @NSManaged public var store: String?
    @NSManaged public var subsubtype: String?
    @NSManaged public var subtype: String?
    @NSManaged public var type: String?

}

extension ItemShopping : Identifiable {

}
