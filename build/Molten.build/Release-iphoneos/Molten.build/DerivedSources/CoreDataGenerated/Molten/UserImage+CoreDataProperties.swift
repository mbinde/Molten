//
//  UserImage+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias UserImageCoreDataPropertiesSet = NSSet

extension UserImage {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserImage> {
        return NSFetchRequest<UserImage>(entityName: "UserImage")
    }

    @NSManaged public var dateCreated: Date?
    @NSManaged public var dateModified: Date?
    @NSManaged public var fileExtension: String?
    @NSManaged public var id: UUID?
    @NSManaged public var imageData: Data?
    @NSManaged public var imageType: String?
    @NSManaged public var ownerId: String?
    @NSManaged public var ownerType: String?

}

extension UserImage : Identifiable {

}
