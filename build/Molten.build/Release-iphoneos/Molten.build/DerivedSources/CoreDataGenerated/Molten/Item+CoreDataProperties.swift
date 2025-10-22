//
//  Item+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ItemCoreDataPropertiesSet = NSSet

extension Item {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Item> {
        return NSFetchRequest<Item>(entityName: "Item")
    }

    @NSManaged public var image_path: String?
    @NSManaged public var image_url: URL?
    @NSManaged public var last_seen: Date?
    @NSManaged public var manufacturer: String?
    @NSManaged public var mfr_notes: String?
    @NSManaged public var mfr_status: String?
    @NSManaged public var name: String?
    @NSManaged public var natural_key: String?
    @NSManaged public var sku: String?
    @NSManaged public var uri: URL?
    @NSManaged public var url: String?

}

extension Item : Identifiable {

}
