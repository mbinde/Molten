//
//  FlameworkerApp.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//

import SwiftUI
import CoreData

@main
struct FlameworkerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
