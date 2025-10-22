//
//  ProjectImage+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ProjectImageCoreDataPropertiesSet = NSSet

extension ProjectImage {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectImage> {
        return NSFetchRequest<ProjectImage>(entityName: "ProjectImage")
    }

    @NSManaged public var caption: String?
    @NSManaged public var date_added: Date?
    @NSManaged public var file_extension: String?
    @NSManaged public var file_name: String?
    @NSManaged public var id: UUID?
    @NSManaged public var order_index: Int32
    @NSManaged public var log: ProjectLog?
    @NSManaged public var plan: ProjectPlan?

}

extension ProjectImage : Identifiable {

}
