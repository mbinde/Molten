//
//  StubCatalogEntities.swift
//  Molten
//
//  TEMPORARY stub classes to allow Core Data entity deletion without crashes.
//  These replace auto-generated classes for GlassItem, CoatingItem, ToolItem, ItemTags, Item.
//
//  DELETE THIS FILE after Core Data entities are removed from model.
//

import Foundation
import CoreData

/// Stub for Item entity (will be deleted)
@objc(Item)
public class Item: NSManagedObject {}

/// Stub for GlassItem entity (will be deleted)
@objc(GlassItem)
public class GlassItem: Item {}

/// Stub for CoatingItem entity (will be deleted)
@objc(CoatingItem)
public class CoatingItem: Item {}

/// Stub for ToolItem entity (will be deleted)
@objc(ToolItem)
public class ToolItem: Item {}

/// Stub for ItemTags entity (will be deleted)
@objc(ItemTags)
public class ItemTags: NSManagedObject {}
