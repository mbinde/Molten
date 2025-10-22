//
//  CatalogItemParent+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias CatalogItemParentCoreDataPropertiesSet = NSSet

extension CatalogItemParent {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CatalogItemParent> {
        return NSFetchRequest<CatalogItemParent>(entityName: "CatalogItemParent")
    }

    @NSManaged public var base_code: String?
    @NSManaged public var base_name: String?
    @NSManaged public var coe: Int16
    @NSManaged public var id: UUID?
    @NSManaged public var manufacturer: String?
    @NSManaged public var manufacturer_description: String?
    @NSManaged public var tags: String?

}

extension CatalogItemParent : Identifiable {

}
