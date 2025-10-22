//
//  ProjectPlanReferenceUrl+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ProjectPlanReferenceUrlCoreDataPropertiesSet = NSSet

extension ProjectPlanReferenceUrl {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectPlanReferenceUrl> {
        return NSFetchRequest<ProjectPlanReferenceUrl>(entityName: "ProjectPlanReferenceUrl")
    }

    @NSManaged public var dateAdded: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var title: String?
    @NSManaged public var url: String?
    @NSManaged public var urlDescription: String?
    @NSManaged public var plan: ProjectPlan?

}

extension ProjectPlanReferenceUrl : Identifiable {

}
