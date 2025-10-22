//
//  ProjectLogGlassItem+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ProjectLogGlassItemCoreDataPropertiesSet = NSSet

extension ProjectLogGlassItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectLogGlassItem> {
        return NSFetchRequest<ProjectLogGlassItem>(entityName: "ProjectLogGlassItem")
    }

    @NSManaged public var freeformDescription: String?
    @NSManaged public var id: UUID?
    @NSManaged public var itemNaturalKey: String?
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var quantity: Double
    @NSManaged public var unit: String?
    @NSManaged public var log: ProjectLog?

}

extension ProjectLogGlassItem : Identifiable {

}
