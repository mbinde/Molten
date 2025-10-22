//
//  ProjectLog+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ProjectLogCoreDataPropertiesSet = NSSet

extension ProjectLog {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectLog> {
        return NSFetchRequest<ProjectLog>(entityName: "ProjectLog")
    }

    @NSManaged public var based_on_plan_id: UUID?
    @NSManaged public var buyer_info: String?
    @NSManaged public var coe: String?
    @NSManaged public var date_created: Date?
    @NSManaged public var date_modified: Date?
    @NSManaged public var hero_image_id: UUID?
    @NSManaged public var hours_spent: NSDecimalNumber?
    @NSManaged public var id: UUID?
    @NSManaged public var inventory_deduction_recorded: Bool
    @NSManaged public var notes: String?
    @NSManaged public var price_point: NSDecimalNumber?
    @NSManaged public var project_date: Date?
    @NSManaged public var sale_date: Date?
    @NSManaged public var status: String?
    @NSManaged public var title: String?
    @NSManaged public var glassItems: NSSet?
    @NSManaged public var images: NSSet?
    @NSManaged public var tags: NSSet?
    @NSManaged public var techniques: NSSet?

}

// MARK: Generated accessors for glassItems
extension ProjectLog {

    @objc(addGlassItemsObject:)
    @NSManaged public func addToGlassItems(_ value: ProjectLogGlassItem)

    @objc(removeGlassItemsObject:)
    @NSManaged public func removeFromGlassItems(_ value: ProjectLogGlassItem)

    @objc(addGlassItems:)
    @NSManaged public func addToGlassItems(_ values: NSSet)

    @objc(removeGlassItems:)
    @NSManaged public func removeFromGlassItems(_ values: NSSet)

}

// MARK: Generated accessors for images
extension ProjectLog {

    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: ProjectImage)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: ProjectImage)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: NSSet)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: NSSet)

}

// MARK: Generated accessors for tags
extension ProjectLog {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: ProjectTag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: ProjectTag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)

}

// MARK: Generated accessors for techniques
extension ProjectLog {

    @objc(addTechniquesObject:)
    @NSManaged public func addToTechniques(_ value: ProjectTechnique)

    @objc(removeTechniquesObject:)
    @NSManaged public func removeFromTechniques(_ value: ProjectTechnique)

    @objc(addTechniques:)
    @NSManaged public func addToTechniques(_ values: NSSet)

    @objc(removeTechniques:)
    @NSManaged public func removeFromTechniques(_ values: NSSet)

}

extension ProjectLog : Identifiable {

}
