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
    private let deps = AppDependencies.shared

    var body: some View {
        CatalogView(deps: deps)
    }
}

#Preview {
    let persistenceController = PersistenceController.preview
    ContentView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
}
