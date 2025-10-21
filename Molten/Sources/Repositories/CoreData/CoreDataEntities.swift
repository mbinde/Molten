//
//  CoreDataEntities.swift
//  Molten
//
//  Base class definitions for Core Data entities
//  Xcode generates the property extensions automatically
//

import Foundation
import CoreData

// MARK: - Core Data Entity Base Classes

@objc(CatalogItem)
public class CatalogItem: NSManagedObject {}

@objc(CatalogItemParent)
public class CatalogItemParent: NSManagedObject {}

@objc(CatalogItemUser)
public class CatalogItemUser: CatalogItem {}

@objc(GlassItem)
public class GlassItem: Item {}

@objc(Inventory)
public class Inventory: NSManagedObject {}

@objc(InventoryItem)
public class InventoryItem: NSManagedObject {}

@objc(Item)
public class Item: NSManagedObject {}

@objc(ItemDimensions)
public class ItemDimensions: NSManagedObject {}

@objc(ItemMinimum)
public class ItemMinimum: NSManagedObject {}

@objc(ItemShopping)
public class ItemShopping: NSManagedObject {}

@objc(ItemTags)
public class ItemTags: NSManagedObject {}

@objc(Location)
public class Location: NSManagedObject {}

@objc(ProjectImage)
public class ProjectImage: NSManagedObject {}

@objc(ProjectLog)
public class ProjectLog: NSManagedObject {}

@objc(ProjectLogGlassItem)
public class ProjectLogGlassItem: NSManagedObject {}

@objc(ProjectPlan)
public class ProjectPlan: NSManagedObject {}

@objc(ProjectPlanGlassItem)
public class ProjectPlanGlassItem: NSManagedObject {}

@objc(ProjectPlanReferenceUrl)
public class ProjectPlanReferenceUrl: NSManagedObject {}

@objc(ProjectStep)
public class ProjectStep: NSManagedObject {}

@objc(ProjectStepGlassItem)
public class ProjectStepGlassItem: NSManagedObject {}

@objc(ProjectTag)
public class ProjectTag: NSManagedObject {}

@objc(ProjectTechnique)
public class ProjectTechnique: NSManagedObject {}

@objc(PurchaseRecord)
public class PurchaseRecord: NSManagedObject {}

@objc(PurchaseRecordItem)
public class PurchaseRecordItem: NSManagedObject {}

@objc(ToolItem)
public class ToolItem: Item {}

@objc(UserImage)
public class UserImage: NSManagedObject {}

@objc(UserItem)
public class UserItem: Item {}

@objc(UserNotes)
public class UserNotes: NSManagedObject {}

@objc(UserTags)
public class UserTags: NSManagedObject {}
