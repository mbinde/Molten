//
//  CatalogItemUser+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias CatalogItemUserCoreDataPropertiesSet = NSSet

extension CatalogItemUser {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CatalogItemUser> {
        return NSFetchRequest<CatalogItemUser>(entityName: "CatalogItemUser")
    }

    @NSManaged public var notes: String?

}
