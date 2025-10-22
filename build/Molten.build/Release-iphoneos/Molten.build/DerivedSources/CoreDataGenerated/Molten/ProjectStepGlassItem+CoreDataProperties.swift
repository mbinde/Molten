//
//  ProjectStepGlassItem+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ProjectStepGlassItemCoreDataPropertiesSet = NSSet

extension ProjectStepGlassItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectStepGlassItem> {
        return NSFetchRequest<ProjectStepGlassItem>(entityName: "ProjectStepGlassItem")
    }

    @NSManaged public var freeformDescription: String?
    @NSManaged public var id: UUID?
    @NSManaged public var itemNaturalKey: String?
    @NSManaged public var notes: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var quantity: Double
    @NSManaged public var unit: String?
    @NSManaged public var step: ProjectStep?

}

extension ProjectStepGlassItem : Identifiable {

}
