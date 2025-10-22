//
//  PurchaseRecordItem+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias PurchaseRecordItemCoreDataPropertiesSet = NSSet

extension PurchaseRecordItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PurchaseRecordItem> {
        return NSFetchRequest<PurchaseRecordItem>(entityName: "PurchaseRecordItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var item_natural_key: String?
    @NSManaged public var order_index: Int32
    @NSManaged public var quantity: Double
    @NSManaged public var subsubtype: String?
    @NSManaged public var subtype: String?
    @NSManaged public var total_price: NSDecimalNumber?
    @NSManaged public var type: String?
    @NSManaged public var purchaserecord: PurchaseRecord?

}

extension PurchaseRecordItem : Identifiable {

}
