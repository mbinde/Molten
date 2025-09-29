//
//  InventoryView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct InventoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "archivebox")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("Inventory")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Track your glass rod inventory")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("This feature will allow you to:")
                    .font(.headline)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("Track rod quantities", systemImage: "ruler")
                    Label("Mark items for reorder", systemImage: "chart.line.uptrend.xyaxis")
                    Label("Log purchases", systemImage: "note.text")
                    Label("Search and filter your inventory", systemImage: "magnifyingglass")
                    Label("Identify items for resale", systemImage: "dollarsign")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Coming Soon!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding()
            .navigationTitle("Inventory")
            .searchable(text: $searchText, prompt: "Search inventory...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        // Future: Add inventory item
                    }) {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(true) // Disabled until implemented
                }
            }
        }
    }
}

#Preview {
    InventoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
