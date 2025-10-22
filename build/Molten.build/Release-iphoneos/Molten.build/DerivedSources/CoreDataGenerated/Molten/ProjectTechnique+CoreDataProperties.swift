//
//  ProjectTechnique+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ProjectTechniqueCoreDataPropertiesSet = NSSet

extension ProjectTechnique {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectTechnique> {
        return NSFetchRequest<ProjectTechnique>(entityName: "ProjectTechnique")
    }

    @NSManaged public var dateAdded: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var technique: String?
    @NSManaged public var log: ProjectLog?

}

extension ProjectTechnique : Identifiable {

}
