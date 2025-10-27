//
//  DesignSystem+Accessibility.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Accessibility identifiers for UI testing and accessibility support
//

import Foundation

// MARK: - Accessibility Identifiers

extension DesignSystem {
    /// Centralized accessibility identifiers for UI testing and VoiceOver support
    ///
    /// **Naming Convention:** `feature.element[.specifics]`
    ///
    /// **Example Usage:**
    /// ```swift
    /// Button("Add Item") {
    ///     // action
    /// }
    /// .accessibilityIdentifier(DesignSystem.AccessibilityID.Catalog.addButton)
    /// ```
    ///
    /// **In UI Tests:**
    /// ```swift
    /// app.buttons[DesignSystem.AccessibilityID.Catalog.addButton].tap()
    /// ```
    enum AccessibilityID {

        // MARK: - Catalog Feature

        enum Catalog {
            static let searchBar = "catalog.searchBar"
            static let addButton = "catalog.addButton"
            static let sortButton = "catalog.sortButton"
            static let filterButton = "catalog.filterButton"
            static let manufacturerFilterButton = "catalog.manufacturerFilterButton"
            static let coeFilterButton = "catalog.coeFilterButton"

            /// Generate identifier for a catalog item row
            /// - Parameter stableId: The glass item's stable_id
            /// - Returns: Unique identifier for the row (e.g., "catalog.itemRow.bullseye-001-0")
            static func itemRow(_ stableId: String) -> String {
                "catalog.itemRow.\(stableId)"
            }

            /// Generate identifier for item detail view
            static func itemDetail(_ stableId: String) -> String {
                "catalog.itemDetail.\(stableId)"
            }
        }

        // MARK: - Inventory Feature

        enum Inventory {
            static let addButton = "inventory.addButton"
            static let searchBar = "inventory.searchBar"
            static let filterButton = "inventory.filterButton"
            static let typeFilterButton = "inventory.typeFilterButton"
            static let locationFilterButton = "inventory.locationFilterButton"
            static let lowStockFilterButton = "inventory.lowStockFilterButton"

            static let quantityField = "inventory.quantityField"
            static let typeField = "inventory.typeField"
            static let locationField = "inventory.locationField"
            static let saveButton = "inventory.saveButton"
            static let cancelButton = "inventory.cancelButton"

            /// Generate identifier for inventory item row
            static func itemRow(_ inventoryId: String) -> String {
                "inventory.itemRow.\(inventoryId)"
            }

            /// Generate identifier for delete button in row
            static func deleteButton(_ inventoryId: String) -> String {
                "inventory.delete.\(inventoryId)"
            }
        }

        // MARK: - Shopping List Feature

        enum ShoppingList {
            static let addButton = "shopping.addButton"
            static let searchBar = "shopping.searchBar"
            static let clearCompletedButton = "shopping.clearCompleted"

            /// Generate identifier for shopping list item row
            static func itemRow(_ stableId: String) -> String {
                "shopping.itemRow.\(stableId)"
            }

            /// Generate identifier for item checkbox
            static func itemCheckbox(_ stableId: String) -> String {
                "shopping.checkbox.\(stableId)"
            }

            /// Generate identifier for add to cart button
            static func addToCartButton(_ stableId: String) -> String {
                "shopping.addToCart.\(stableId)"
            }
        }

        // MARK: - Purchases Feature

        enum Purchases {
            static let addButton = "purchases.addButton"
            static let searchBar = "purchases.searchBar"
            static let filterButton = "purchases.filterButton"
            static let dateFilterButton = "purchases.dateFilterButton"
            static let vendorFilterButton = "purchases.vendorFilterButton"

            static let dateField = "purchases.dateField"
            static let vendorField = "purchases.vendorField"
            static let totalField = "purchases.totalField"
            static let notesField = "purchases.notesField"
            static let saveButton = "purchases.saveButton"
            static let cancelButton = "purchases.cancelButton"

            /// Generate identifier for purchase record row
            static func recordRow(_ recordId: String) -> String {
                "purchases.recordRow.\(recordId)"
            }

            /// Generate identifier for purchase detail view
            static func recordDetail(_ recordId: String) -> String {
                "purchases.recordDetail.\(recordId)"
            }
        }

        // MARK: - Project Log Feature

        enum ProjectLog {
            static let addButton = "projectLog.addButton"
            static let searchBar = "projectLog.searchBar"
            static let filterButton = "projectLog.filterButton"

            static let titleField = "projectLog.titleField"
            static let descriptionField = "projectLog.descriptionField"
            static let dateField = "projectLog.dateField"
            static let saveButton = "projectLog.saveButton"
            static let cancelButton = "projectLog.cancelButton"

            /// Generate identifier for project entry row
            static func entryRow(_ entryId: String) -> String {
                "projectLog.entryRow.\(entryId)"
            }

            /// Generate identifier for project detail view
            static func entryDetail(_ entryId: String) -> String {
                "projectLog.entryDetail.\(entryId)"
            }
        }

        // MARK: - Settings Feature

        enum Settings {
            static let profileSection = "settings.profileSection"
            static let preferencesSection = "settings.preferencesSection"
            static let dataSection = "settings.dataSection"
            static let aboutSection = "settings.aboutSection"

            static let saveButton = "settings.saveButton"
            static let cancelButton = "settings.cancelButton"
            static let exportButton = "settings.exportButton"
            static let importButton = "settings.importButton"
            static let resetButton = "settings.resetButton"
        }

        // MARK: - Navigation & Tabs

        enum Navigation {
            static let tabBar = "app.tabBar"
            static let catalogTab = "app.tab.catalog"
            static let inventoryTab = "app.tab.inventory"
            static let shoppingTab = "app.tab.shopping"
            static let purchasesTab = "app.tab.purchases"
            static let projectLogTab = "app.tab.projectLog"
            static let settingsTab = "app.tab.settings"

            static let backButton = "navigation.backButton"
            static let closeButton = "navigation.closeButton"
            static let doneButton = "navigation.doneButton"
        }

        // MARK: - Common UI Elements

        enum Common {
            static let searchBar = "common.searchBar"
            static let saveButton = "common.saveButton"
            static let cancelButton = "common.cancelButton"
            static let deleteButton = "common.deleteButton"
            static let editButton = "common.editButton"
            static let addButton = "common.addButton"

            static let emptyStateView = "common.emptyState"
            static let errorView = "common.errorView"
            static let loadingView = "common.loadingView"

            static let confirmDialog = "common.confirmDialog"
            static let alertDialog = "common.alertDialog"
        }

        // MARK: - Forms & Fields

        enum Form {
            static let textField = "form.textField"
            static let numberField = "form.numberField"
            static let dateField = "form.dateField"
            static let pickerField = "form.pickerField"
            static let textEditor = "form.textEditor"

            /// Generate identifier for a specific form field
            static func field(_ name: String) -> String {
                "form.field.\(name)"
            }
        }
    }
}

// MARK: - Accessibility Labels

extension DesignSystem {
    /// Standard accessibility labels for common actions
    ///
    /// **Example Usage:**
    /// ```swift
    /// Button(action: addItem) {
    ///     Image(systemName: "plus")
    /// }
    /// .accessibilityLabel(DesignSystem.AccessibilityLabel.addItem)
    /// ```
    enum AccessibilityLabel {
        // Actions
        static let add = "Add"
        static let addItem = "Add item"
        static let edit = "Edit"
        static let delete = "Delete"
        static let save = "Save"
        static let cancel = "Cancel"
        static let close = "Close"
        static let done = "Done"
        static let search = "Search"
        static let filter = "Filter"
        static let sort = "Sort"
        static let refresh = "Refresh"

        // Navigation
        static let back = "Back"
        static let next = "Next"
        static let previous = "Previous"

        // States
        static let loading = "Loading"
        static let error = "Error"
        static let success = "Success"
        static let empty = "No items"

        // Catalog
        static let addCatalogItem = "Add new catalog item"
        static let editCatalogItem = "Edit catalog item"
        static let deleteCatalogItem = "Delete catalog item"

        // Inventory
        static let addInventory = "Add inventory"
        static let updateInventory = "Update inventory quantity"
        static let deleteInventory = "Delete inventory record"

        // Shopping
        static let addToShoppingList = "Add to shopping list"
        static let markAsComplete = "Mark as complete"
        static let removeFromShoppingList = "Remove from shopping list"

        // Purchases
        static let addPurchaseRecord = "Add purchase record"
        static let editPurchaseRecord = "Edit purchase record"
        static let deletePurchaseRecord = "Delete purchase record"
    }
}

// MARK: - Accessibility Hints

extension DesignSystem {
    /// Standard accessibility hints for common actions
    ///
    /// Hints provide additional context about what will happen when an action is performed.
    ///
    /// **Example Usage:**
    /// ```swift
    /// Button(action: addItem) {
    ///     Image(systemName: "plus")
    /// }
    /// .accessibilityLabel(DesignSystem.AccessibilityLabel.addItem)
    /// .accessibilityHint(DesignSystem.AccessibilityHint.addItem)
    /// ```
    enum AccessibilityHint {
        // Navigation
        static let opensNewScreen = "Opens a new screen"
        static let opensForm = "Opens a form"
        static let closesCurrentScreen = "Closes the current screen"

        // Actions
        static let addItem = "Opens form to add a new item"
        static let editItem = "Opens form to edit this item"
        static let deleteItem = "Deletes this item permanently"
        static let saveChanges = "Saves your changes"
        static let discardChanges = "Discards your changes"

        // Search & Filter
        static let search = "Searches through items"
        static let filter = "Filters the list of items"
        static let sort = "Sorts the list of items"

        // Catalog
        static let addCatalogItem = "Opens form to add a new glass item to catalog"
        static let viewCatalogItem = "Opens detailed view of this glass item"

        // Inventory
        static let addInventory = "Opens form to add inventory for this item"
        static let updateInventory = "Updates the quantity in inventory"

        // Shopping
        static let addToShoppingList = "Adds this item to your shopping list"
        static let markAsComplete = "Marks this shopping list item as purchased"
    }
}

// MARK: - View Modifier Extension

import SwiftUI

extension View {
    /// Apply complete accessibility configuration with identifier, label, and hint
    ///
    /// **Example:**
    /// ```swift
    /// Button(action: addItem) {
    ///     Image(systemName: "plus")
    /// }
    /// .accessibility(
    ///     identifier: DesignSystem.AccessibilityID.Catalog.addButton,
    ///     label: DesignSystem.AccessibilityLabel.addCatalogItem,
    ///     hint: DesignSystem.AccessibilityHint.addCatalogItem
    /// )
    /// ```
    func accessibility(
        identifier: String,
        label: String? = nil,
        hint: String? = nil
    ) -> some View {
        Group {
            if let label = label, let hint = hint {
                self.accessibilityIdentifier(identifier)
                    .accessibilityLabel(label)
                    .accessibilityHint(hint)
            } else if let label = label {
                self.accessibilityIdentifier(identifier)
                    .accessibilityLabel(label)
            } else if let hint = hint {
                self.accessibilityIdentifier(identifier)
                    .accessibilityHint(hint)
            } else {
                self.accessibilityIdentifier(identifier)
            }
        }
    }
}
