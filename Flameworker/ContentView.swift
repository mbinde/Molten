//
//  ContentView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//
//  Note: This file is kept for backward compatibility.
//  The main catalog functionality has been moved to CatalogView.swift
//

import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        CatalogView()
    }
}

#Preview {
    let persistenceController = PersistenceController.preview
    return ContentView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
}
