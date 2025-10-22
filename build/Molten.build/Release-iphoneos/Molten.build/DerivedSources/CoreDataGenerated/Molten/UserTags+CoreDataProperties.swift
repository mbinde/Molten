//
//  UserTags+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias UserTagsCoreDataPropertiesSet = NSSet

extension UserTags {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserTags> {
        return NSFetchRequest<UserTags>(entityName: "UserTags")
    }

    @NSManaged public var item_natural_key: String?
    @NSManaged public var tag: String?

}

extension UserTags : Identifiable {

}
