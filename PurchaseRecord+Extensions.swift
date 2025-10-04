//
//  PurchaseRecord+Extensions.swift
//  Flameworker
//
//  Created by Assistant on 10/3/25.
//
//  NOTE: This file is causing compilation issues due to type resolution.
//  Consider removing it and using direct Core Data setValue/getValue calls instead.
//  The AddPurchaseRecordView and detail views work fine without these extensions.

/*
// This extension is currently disabled due to type resolution issues
// The types InventoryItemType and InventoryUnits are not being found
// even though they should be available in the same target.

// If you want to use these extensions:
// 1. Ensure InventoryItemType.swift and InventoryUnits.swift are in the same target
// 2. Make sure this file is added to the main app target, not just tests
// 3. Consider putting the enums and extensions in the same file

import Foundation
import SwiftUI
import CoreData

extension NSManagedObject {
    
    var purchaseItemType: InventoryItemType {
        get {
            let typeValue = value(forKey: "type") as? Int16 ?? 0
            return InventoryItemType(from: typeValue)
        }
        set {
            setValue(newValue.rawValue, forKey: "type")
        }
    }
    
    var purchaseTypeDisplayName: String {
        return purchaseItemType.displayName
    }
    
    var purchaseUnitsKind: InventoryUnits {
        get {
            let unitsValue = value(forKey: "units") as? Int16 ?? 0
            return InventoryUnits(from: unitsValue)
        }
        set {
            setValue(newValue.rawValue, forKey: "units")
        }
    }
    
    var purchaseUnitsDisplayName: String {
        return purchaseUnitsKind.displayName
    }
    
    func setPurchaseItemType(_ type: InventoryItemType) {
        setValue(type.rawValue, forKey: "type")
    }
    
    func setPurchaseUnitsKind(_ units: InventoryUnits) {
        setValue(units.rawValue, forKey: "units")
    }
}
*/