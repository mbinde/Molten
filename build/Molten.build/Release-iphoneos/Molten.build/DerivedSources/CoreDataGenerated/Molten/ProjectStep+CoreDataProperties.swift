//
//  ProjectStep+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ProjectStepCoreDataPropertiesSet = NSSet

extension ProjectStep {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectStep> {
        return NSFetchRequest<ProjectStep>(entityName: "ProjectStep")
    }

    @NSManaged public var estimated_minutes: Int32
    @NSManaged public var id: UUID?
    @NSManaged public var image_id: UUID?
    @NSManaged public var order_index: Int32
    @NSManaged public var step_description: String?
    @NSManaged public var title: String?
    @NSManaged public var glassItems: NSSet?
    @NSManaged public var plan: ProjectPlan?

}

// MARK: Generated accessors for glassItems
extension ProjectStep {

    @objc(addGlassItemsObject:)
    @NSManaged public func addToGlassItems(_ value: ProjectStepGlassItem)

    @objc(removeGlassItemsObject:)
    @NSManaged public func removeFromGlassItems(_ value: ProjectStepGlassItem)

    @objc(addGlassItems:)
    @NSManaged public func addToGlassItems(_ values: NSSet)

    @objc(removeGlassItems:)
    @NSManaged public func removeFromGlassItems(_ values: NSSet)

}

extension ProjectStep : Identifiable {

}
