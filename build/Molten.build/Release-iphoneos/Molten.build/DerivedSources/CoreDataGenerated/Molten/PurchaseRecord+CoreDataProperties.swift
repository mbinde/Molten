//
//  PurchaseRecord+CoreDataProperties.swift
//  
//
//  Created by Melissa Binde on 10/21/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias PurchaseRecordCoreDataPropertiesSet = NSSet

extension PurchaseRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PurchaseRecord> {
        return NSFetchRequest<PurchaseRecord>(entityName: "PurchaseRecord")
    }

    @NSManaged public var currency: String?
    @NSManaged public var date_added: Date?
    @NSManaged public var date_purchased: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var notes: String?
    @NSManaged public var shipping: NSDecimalNumber?
    @NSManaged public var subtotal: NSDecimalNumber?
    @NSManaged public var supplier: String?
    @NSManaged public var tax: NSDecimalNumber?
    @NSManaged public var purchaserecorditem: NSSet?

}

// MARK: Generated accessors for purchaserecorditem
extension PurchaseRecord {

    @objc(addPurchaserecorditemObject:)
    @NSManaged public func addToPurchaserecorditem(_ value: PurchaseRecordItem)

    @objc(removePurchaserecorditemObject:)
    @NSManaged public func removeFromPurchaserecorditem(_ value: PurchaseRecordItem)

    @objc(addPurchaserecorditem:)
    @NSManaged public func addToPurchaserecorditem(_ values: NSSet)

    @objc(removePurchaserecorditem:)
    @NSManaged public func removeFromPurchaserecorditem(_ values: NSSet)

}

extension PurchaseRecord : Identifiable {

}
