//
//  Persistence.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for i in 0..<10 {
            let newItem = CatalogItem(context: viewContext)
            newItem.code = "PREVIEW-\(i + 1)"
            newItem.name = "Preview Item \(i + 1)"
            newItem.manufacturer = i % 2 == 0 ? "Preview Manufacturer A" : "Preview Manufacturer B"
  //          newItem.price = Double.random(in: 10...100)
        }
        do {
            try viewContext.save()
        } catch {
            // Log the error but don't crash the app in production
            let nsError = error as NSError
            print("Preview data creation error: \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Flameworker")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Log the error but don't crash the app in production
                print("Core Data error: \(error), \(error.userInfo)")
                
                // In a production app, you might want to:
                // 1. Show an alert to the user
                // 2. Attempt to recover
                // 3. Report to crash analytics
                // 4. Fall back to a different data source
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
