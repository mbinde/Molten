//
//  GlassItem+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias GlassItemCoreDataPropertiesSet = NSSet

extension GlassItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<GlassItem> {
        return NSFetchRequest<GlassItem>(entityName: "GlassItem")
    }

    @NSManaged public var coe: Int16

}
