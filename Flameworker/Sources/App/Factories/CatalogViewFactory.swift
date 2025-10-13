//
//  ContentView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//
//  Note: This file provides the main entry point and sets up the repository pattern
//  for the catalog functionality in CatalogView.swift
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        CatalogView(catalogService: createCatalogService())
    }
    
    /// Create the production catalog service with Core Data repository
    private func createCatalogService() -> CatalogService {
        let coreDataRepository = CoreDataCatalogRepository(context: viewContext)
        return CatalogService(repository: coreDataRepository)
    }
}

#Preview {
    let persistenceController = PersistenceController.preview
    return ContentView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
}
