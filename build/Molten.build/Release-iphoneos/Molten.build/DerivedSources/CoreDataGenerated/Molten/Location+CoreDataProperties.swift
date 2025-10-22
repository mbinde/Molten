//
//  Location+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias LocationCoreDataPropertiesSet = NSSet

extension Location {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Location> {
        return NSFetchRequest<Location>(entityName: "Location")
    }

    @NSManaged public var inventory_id: UUID?
    @NSManaged public var location: String?
    @NSManaged public var quantity: String?

}

extension Location : Identifiable {

}
