//
//  LocationAutoCompleteField.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import SwiftUI
import CoreData


/// Auto-complete input field for inventory item locations
struct LocationAutoCompleteField: View {
    @Binding var location: String
    let context: NSManagedObjectContext
    
    @State private var showingSuggestions = false
    @State private var locationSuggestions: [String] = []
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("Enter location (e.g., Workshop Shelf A)", text: $location)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .onSubmit {
                    showingSuggestions = false
                }
                .onChange(of: location) { _, newValue in
                    updateSuggestions(for: newValue)
                }
                .onChange(of: isTextFieldFocused) { _, isFocused in
                    if isFocused {
                        loadInitialSuggestions()
                        showingSuggestions = true
                    } else {
                        // Delay hiding to allow tapping suggestions
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingSuggestions = false
                        }
                    }
                }
            
            // Auto-complete suggestions dropdown
            if showingSuggestions && !locationSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(locationSuggestions.prefix(5), id: \.self) { suggestion in
                        Button(action: {
                            location = suggestion
                            showingSuggestions = false
                            isTextFieldFocused = false
                        }) {
                            HStack {
                                Image(systemName: "location")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                
                                Text(suggestion)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(Color(.systemBackground))
                        
                        if suggestion != locationSuggestions.prefix(5).last {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .zIndex(1)
            }
        }
    }
    
    private func updateSuggestions(for searchText: String) {
        locationSuggestions = getLocationSuggestions(matching: searchText, from: context)
        showingSuggestions = !locationSuggestions.isEmpty && isTextFieldFocused
    }
    
    private func loadInitialSuggestions() {
        locationSuggestions = getUniqueLocations(from: context)
    }
    
    // MARK: - Location Service Methods
    
    private func getUniqueLocations(from context: NSManagedObjectContext) -> [String] {
        let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        
        do {
            let items = try context.fetch(fetchRequest)
            
            // Extract non-empty locations, make unique, and sort
            let locations = items
                .compactMap { $0.location }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            // Remove duplicates and sort
            let uniqueLocations = Set(locations)
            return uniqueLocations.sorted()
            
        } catch {
            print("❌ Failed to fetch inventory items for location suggestions: \(error)")
            return []
        }
    }
    
    private func getLocationSuggestions(matching searchText: String, from context: NSManagedObjectContext) -> [String] {
        let allLocations = getUniqueLocations(from: context)
        
        guard !searchText.isEmpty else {
            return allLocations
        }
        
        let lowercaseSearch = searchText.lowercased()
        return allLocations.filter { location in
            location.lowercased().contains(lowercaseSearch)
        }
    }
}

#Preview {
    @State var location = ""
    
    return VStack {
        LocationAutoCompleteField(
            location: $location, 
            context: PersistenceController.preview.container.viewContext
        )
        Spacer()
    }
    .padding()
}
