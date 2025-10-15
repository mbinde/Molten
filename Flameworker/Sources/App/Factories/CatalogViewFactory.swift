//
//  ContentView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//  Updated for GlassItem architecture
//
//  Note: This file provides the main entry point and sets up the new GlassItem architecture
//  for the catalog functionality in CatalogView.swift
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        CatalogView(catalogService: createCatalogService())
    }
    
    /// Create the production catalog service with new GlassItem architecture
    private func createCatalogService() -> CatalogService {
        // Use the RepositoryFactory to create the catalog service
        // The factory will handle Core Data configuration internally
        return RepositoryFactory.createCatalogService()
    }
}

#Preview {
    let persistenceController = PersistenceController.preview
    ContentView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
}
