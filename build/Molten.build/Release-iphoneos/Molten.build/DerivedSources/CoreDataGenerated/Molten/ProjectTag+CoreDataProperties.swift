//
//  ProjectTag+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ProjectTagCoreDataPropertiesSet = NSSet

extension ProjectTag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectTag> {
        return NSFetchRequest<ProjectTag>(entityName: "ProjectTag")
    }

    @NSManaged public var dateAdded: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var tag: String?
    @NSManaged public var log: ProjectLog?
    @NSManaged public var plan: ProjectPlan?

}

extension ProjectTag : Identifiable {

}
