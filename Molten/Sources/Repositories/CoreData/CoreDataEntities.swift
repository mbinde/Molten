//
//  CoreDataEntities.swift
//  Molten
//
//  Base class definitions for Core Data entities
//  Xcode generates the property extensions automatically
//

import Foundation
@preconcurrency import CoreData

// MARK: - Core Data Entity Base Classes

@preconcurrency @objc(CatalogItem)
public class CatalogItem: NSManagedObject {}

@preconcurrency @objc(CatalogItemParent)
public class CatalogItemParent: NSManagedObject {}

@preconcurrency @objc(CatalogItemUser)
public class CatalogItemUser: CatalogItem {}

@preconcurrency @objc(GlassItem)
public class GlassItem: Item {}

@preconcurrency @objc(Inventory)
public class Inventory: NSManagedObject {}

@preconcurrency @objc(InventoryItem)
public class InventoryItem: NSManagedObject {}

@preconcurrency @objc(Item)
public class Item: NSManagedObject {}

@preconcurrency @objc(ItemDimensions)
public class ItemDimensions: NSManagedObject {}

@preconcurrency @objc(ItemMinimum)
public class ItemMinimum: NSManagedObject {}

@preconcurrency @objc(ItemShopping)
public class ItemShopping: NSManagedObject {}

@preconcurrency @objc(ItemTags)
public class ItemTags: NSManagedObject {}

@preconcurrency @objc(Location)
public class Location: NSManagedObject {}

@preconcurrency @objc(ProjectImage)
public class ProjectImage: NSManagedObject {}

@preconcurrency @objc(Logbook)
public class Logbook: NSManagedObject {}

@preconcurrency @objc(LogbookGlassItem)
public class LogbookGlassItem: NSManagedObject {}

@preconcurrency @objc(ProjectPlan)
public class ProjectPlan: NSManagedObject {}

@preconcurrency @objc(ProjectPlanGlassItem)
public class ProjectPlanGlassItem: NSManagedObject {}

@preconcurrency @objc(ProjectPlanReferenceUrl)
public class ProjectPlanReferenceUrl: NSManagedObject {}

@preconcurrency @objc(ProjectStep)
public class ProjectStep: NSManagedObject {}

@preconcurrency @objc(ProjectStepGlassItem)
public class ProjectStepGlassItem: NSManagedObject {}

@preconcurrency @objc(ProjectTag)
public class ProjectTag: NSManagedObject {}

@preconcurrency @objc(ProjectTechnique)
public class ProjectTechnique: NSManagedObject {}

@preconcurrency @objc(PurchaseRecord)
public class PurchaseRecord: NSManagedObject {}

@preconcurrency @objc(PurchaseRecordItem)
public class PurchaseRecordItem: NSManagedObject {}

@preconcurrency @objc(ToolItem)
public class ToolItem: Item {}

@preconcurrency @objc(UserImage)
public class UserImage: NSManagedObject {}

@preconcurrency @objc(UserItem)
public class UserItem: Item {}

@preconcurrency @objc(UserNotes)
public class UserNotes: NSManagedObject {}

@preconcurrency @objc(UserTags)
public class UserTags: NSManagedObject {}
