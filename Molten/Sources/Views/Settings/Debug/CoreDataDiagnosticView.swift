//
//  CoreDataDiagnosticView.swift
//  Flameworker
//
//  Created by Assistant on 10/9/25.
//

import SwiftUI
import CoreData
import OSLog
#if canImport(AppKit)
import AppKit
#endif

/// Emergency diagnostic view for Core Data issues
struct CoreDataDiagnosticView: View {
    @State private var diagnosticResults: String = "Tap 'Run Diagnostics' to check Core Data status"
    @State private var isRunning = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🚑 Core Data Emergency Diagnostics")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.red)
            
            Text("Use this when getting crashes like:")
                .font(.caption)
            
            Text("'-[_CDSnapshot_CatalogItem_ values]: unrecognized selector'")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.red)
            
            Button("🔍 Run Full Diagnostics") {
                runDiagnostics()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
            
            Button("🚑 Emergency Reset (Deletes All Data)") {
                emergencyReset()
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
            .disabled(isRunning)
            
            Button("📋 Copy Diagnostics") {
                #if canImport(UIKit)
                UIPasteboard.general.string = diagnosticResults
                #elseif canImport(AppKit)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(diagnosticResults, forType: .string)
                #endif
            }
            .buttonStyle(.bordered)
            .disabled(diagnosticResults == "Tap 'Run Diagnostics' to check Core Data status")
            
            ScrollView {
                Text(diagnosticResults)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(8)
                    .textSelection(.enabled)
            }
            
            if isRunning {
                ProgressView("Running diagnostics...")
            }
        }
        .padding()
    }
    
    private func runDiagnostics() {
        isRunning = true
        
        Task {
            let results = await performDiagnostics()
            await MainActor.run {
                diagnosticResults = results
                isRunning = false
            }
        }
    }
    
    private func performDiagnostics() async -> String {
        var results = "=== CORE DATA DIAGNOSTICS ===\n\n"
        
        // Check store health
        results += "1. STORE HEALTH CHECK:\n"
        let isHealthy = CoreDataRecoveryUtility.verifyStoreHealth(PersistenceController.shared)
        results += isHealthy ? "✅ Store is healthy\n" : "❌ Store has issues\n"
        
        if let error = PersistenceController.shared.storeLoadingError {
            results += "Error details: \(error.localizedDescription)\n"
        }
        
        results += "\n2. ENTITY REGISTRATION CHECK:\n"
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        
        // Check if CatalogItem entity can be resolved
        if let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) {
            results += "✅ CatalogItem entity found\n"
            results += "   Class: \(entity.managedObjectClassName)\n"
            results += "   Properties: \(entity.properties.count)\n"
            results += "   Attributes:\n"
            
            for (name, attr) in entity.attributesByName.sorted(by: { $0.key < $1.key }) {
                results += "     - \(name): \(attr.attributeType.rawValue)\n"
            }
        } else {
            results += "❌ CatalogItem entity NOT found\n"
        }
        
        results += "\n3. FETCH TEST:\n"
        do {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CatalogItem")
            fetchRequest.fetchLimit = 1
            let testResults = try context.fetch(fetchRequest)
            results += "✅ Fetch test passed (\(testResults.count) items)\n"
        } catch {
            results += "❌ Fetch test failed: \(error.localizedDescription)\n"
        }
        
        results += "\n4. CREATION TEST:\n"
        do {
            let testItem = PersistenceController.createCatalogItem(in: context)
            if let item = testItem {
                results += "✅ Creation test passed\n"
                results += "   Entity name: \(item.entity.name ?? "Unknown")\n"
                context.delete(item) // Clean up test item
            } else {
                results += "❌ Creation test failed - returned nil\n"
            }
        } catch {
            results += "❌ Creation test crashed: \(error.localizedDescription)\n"
        }
        
        results += "\n5. MODEL ENTITIES:\n"
        let model = controller.container.managedObjectModel
        for entity in model.entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
            results += "   - \(entity.name ?? "Unknown") (\(entity.managedObjectClassName))\n"
        }
        
        results += "\n=== END DIAGNOSTICS ===\n"
        results += "\nRUN THIS AND SHARE THE RESULTS TO GET HELP FIXING THE ISSUE."
        
        return results
    }
    
    private func emergencyReset() {
        isRunning = true
        
        Task {
            await CoreDataRecoveryUtility.resetPersistentStore(PersistenceController.shared)
            await MainActor.run {
                diagnosticResults = "🚑 EMERGENCY RESET COMPLETED\n\nAll Core Data files deleted.\nRestart the app to get a fresh database."
                isRunning = false
            }
        }
    }
}

#if DEBUG
struct CoreDataDiagnosticView_Previews: PreviewProvider {
    static var previews: some View {
        CoreDataDiagnosticView()
    }
}
#endif