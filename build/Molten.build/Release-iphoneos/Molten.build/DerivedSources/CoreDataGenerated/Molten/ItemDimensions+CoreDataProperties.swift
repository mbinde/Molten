//
//  ItemDimensions+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ItemDimensionsCoreDataPropertiesSet = NSSet

extension ItemDimensions {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ItemDimensions> {
        return NSFetchRequest<ItemDimensions>(entityName: "ItemDimensions")
    }

    @NSManaged public var dimension: String?
    @NSManaged public var item_natural_key: String?

}

extension ItemDimensions : Identifiable {

}
