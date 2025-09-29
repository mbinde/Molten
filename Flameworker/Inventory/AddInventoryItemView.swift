//
//  AddInventoryItemView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct AddInventoryItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Form fields
    @State private var customTags = ""
    @State private var isFavorite = false
    
    // Inventory section
    @State private var inventoryAmount = ""
    @State private var inventoryUnits = ""
    @State private var inventoryNotes = ""
    
    // Shopping section
    @State private var shoppingAmount = ""
    @State private var shoppingUnits = ""
    @State private var shoppingNotes = ""
    
    // For Sale section
    @State private var forsaleAmount = ""
    @State private var forsaleUnits = ""
    @State private var forsaleNotes = ""
    
    // UI state
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    TextField("Custom Tags", text: $customTags)
                        .textInputAutocapitalization(.words)
                    
                    Toggle("Favorite", isOn: $isFavorite)
                }
                
                Section("Inventory") {
                    HStack {
                        TextField("Amount", text: $inventoryAmount)
                            .keyboardType(.numbersAndPunctuation)
                        
                        TextField("Units", text: $inventoryUnits)
                            .textInputAutocapitalization(.words)
                    }
                    
                    TextField("Notes", text: $inventoryNotes, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section("Shopping List") {
                    HStack {
                        TextField("Amount", text: $shoppingAmount)
                            .keyboardType(.numbersAndPunctuation)
                        
                        TextField("Units", text: $shoppingUnits)
                            .textInputAutocapitalization(.words)
                    }
                    
                    TextField("Notes", text: $shoppingNotes, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section("For Sale") {
                    HStack {
                        TextField("Amount", text: $forsaleAmount)
                            .keyboardType(.numbersAndPunctuation)
                        
                        TextField("Units", text: $forsaleUnits)
                            .textInputAutocapitalization(.words)
                    }
                    
                    TextField("Notes", text: $forsaleNotes, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                }
            }
            .navigationTitle("Add Inventory Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveInventoryItem()
                        }
                    }
                    .disabled(isLoading || !canSave)
                }
            }
            .disabled(isLoading)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView("Saving...")
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
    
    /// Checks if the form has enough data to save
    private var canSave: Bool {
        // At least one field should have meaningful content
        return !customTags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               !inventoryAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               !inventoryNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               !shoppingAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               !shoppingNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               !forsaleAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               !forsaleNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Saves the inventory item
    @MainActor
    private func saveInventoryItem() async {
        isLoading = true
        
        do {
            let _ = try InventoryService.shared.createInventoryItem(
                customTags: customTags.isEmpty ? nil : customTags,
                isFavorite: isFavorite,
                inventoryAmount: inventoryAmount.isEmpty ? nil : inventoryAmount,
                inventoryUnits: inventoryUnits.isEmpty ? nil : inventoryUnits,
                inventoryNotes: inventoryNotes.isEmpty ? nil : inventoryNotes,
                shoppingAmount: shoppingAmount.isEmpty ? nil : shoppingAmount,
                shoppingUnits: shoppingUnits.isEmpty ? nil : shoppingUnits,
                shoppingNotes: shoppingNotes.isEmpty ? nil : shoppingNotes,
                forsaleAmount: forsaleAmount.isEmpty ? nil : forsaleAmount,
                forsaleUnits: forsaleUnits.isEmpty ? nil : forsaleUnits,
                forsaleNotes: forsaleNotes.isEmpty ? nil : forsaleNotes,
                in: viewContext
            )
            
            // Success - dismiss the view
            dismiss()
            
        } catch {
            // Handle the error
            errorMessage = "Failed to save inventory item: \(error.localizedDescription)"
            showingError = true
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        AddInventoryItemView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}