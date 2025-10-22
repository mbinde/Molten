//
//  ProjectPlan+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ProjectPlanCoreDataPropertiesSet = NSSet

extension ProjectPlan {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectPlan> {
        return NSFetchRequest<ProjectPlan>(entityName: "ProjectPlan")
    }

    @NSManaged public var coe: String?
    @NSManaged public var date_created: Date?
    @NSManaged public var date_modified: Date?
    @NSManaged public var difficulty_level: String?
    @NSManaged public var estimated_time: Double
    @NSManaged public var hero_image_id: UUID?
    @NSManaged public var id: UUID?
    @NSManaged public var is_archived: Bool
    @NSManaged public var last_used_date: Date?
    @NSManaged public var plan_type: String?
    @NSManaged public var price_currency: String?
    @NSManaged public var proposed_price_max: NSDecimalNumber?
    @NSManaged public var proposed_price_min: NSDecimalNumber?
    @NSManaged public var summary: String?
    @NSManaged public var times_used: Int32
    @NSManaged public var title: String?
    @NSManaged public var glassItems: NSSet?
    @NSManaged public var images: NSSet?
    @NSManaged public var referenceUrls: NSSet?
    @NSManaged public var steps: NSSet?
    @NSManaged public var tags: NSSet?

}

// MARK: Generated accessors for glassItems
extension ProjectPlan {

    @objc(addGlassItemsObject:)
    @NSManaged public func addToGlassItems(_ value: ProjectPlanGlassItem)

    @objc(removeGlassItemsObject:)
    @NSManaged public func removeFromGlassItems(_ value: ProjectPlanGlassItem)

    @objc(addGlassItems:)
    @NSManaged public func addToGlassItems(_ values: NSSet)

    @objc(removeGlassItems:)
    @NSManaged public func removeFromGlassItems(_ values: NSSet)

}

// MARK: Generated accessors for images
extension ProjectPlan {

    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: ProjectImage)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: ProjectImage)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: NSSet)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: NSSet)

}

// MARK: Generated accessors for referenceUrls
extension ProjectPlan {

    @objc(addReferenceUrlsObject:)
    @NSManaged public func addToReferenceUrls(_ value: ProjectPlanReferenceUrl)

    @objc(removeReferenceUrlsObject:)
    @NSManaged public func removeFromReferenceUrls(_ value: ProjectPlanReferenceUrl)

    @objc(addReferenceUrls:)
    @NSManaged public func addToReferenceUrls(_ values: NSSet)

    @objc(removeReferenceUrls:)
    @NSManaged public func removeFromReferenceUrls(_ values: NSSet)

}

// MARK: Generated accessors for steps
extension ProjectPlan {

    @objc(addStepsObject:)
    @NSManaged public func addToSteps(_ value: ProjectStep)

    @objc(removeStepsObject:)
    @NSManaged public func removeFromSteps(_ value: ProjectStep)

    @objc(addSteps:)
    @NSManaged public func addToSteps(_ values: NSSet)

    @objc(removeSteps:)
    @NSManaged public func removeFromSteps(_ values: NSSet)

}

// MARK: Generated accessors for tags
extension ProjectPlan {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: ProjectTag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: ProjectTag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)

}

extension ProjectPlan : Identifiable {

}
