//
//  ItemTags+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ItemTagsCoreDataPropertiesSet = NSSet

extension ItemTags {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ItemTags> {
        return NSFetchRequest<ItemTags>(entityName: "ItemTags")
    }

    @NSManaged public var item_natural_key: String?
    @NSManaged public var tag: String?

}

extension ItemTags : Identifiable {

}
