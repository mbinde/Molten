//
//  UserNotes+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias UserNotesCoreDataPropertiesSet = NSSet

extension UserNotes {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserNotes> {
        return NSFetchRequest<UserNotes>(entityName: "UserNotes")
    }

    @NSManaged public var item_natural_key: String?
    @NSManaged public var notes: String?

}

extension UserNotes : Identifiable {

}
