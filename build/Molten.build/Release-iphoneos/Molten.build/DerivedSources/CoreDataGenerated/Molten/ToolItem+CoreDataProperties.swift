//
//  ToolItem+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias ToolItemCoreDataPropertiesSet = NSSet

extension ToolItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ToolItem> {
        return NSFetchRequest<ToolItem>(entityName: "ToolItem")
    }


}
