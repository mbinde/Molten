//
//  LocationInputField.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import SwiftUI
import CoreData

/// Input field for inventory item location with auto-complete suggestions
struct LocationInputField: View {
    @Binding var location: String
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingSuggestions = false
    @State private var locationSuggestions: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 0) {
                TextField("Enter location (e.g., Workshop Shelf A)", text: $location)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        showingSuggestions = false
                    }
                    .onChange(of: location) { _, newValue in
                        updateSuggestions(for: newValue)
                    }
                    .onTapGesture {
                        if locationSuggestions.isEmpty {
                            loadAllSuggestions()
                        }
                        showingSuggestions = true
                    }
                
                // Auto-complete suggestions
                if showingSuggestions && !locationSuggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(locationSuggestions.prefix(5), id: \.self) { suggestion in
                            Button(action: {
                                location = suggestion
                                showingSuggestions = false
                            }) {
                                HStack {
                                    Image(systemName: "location")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    
                                    Text(suggestion)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
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
                }
            }
        }
        .onTapGesture {
            // Dismiss suggestions when tapping outside
            showingSuggestions = false
        }
    }
    
    private func updateSuggestions(for searchText: String) {
        if searchText.isEmpty {
            loadAllSuggestions()
        } else {
            locationSuggestions = LocationService.shared.getLocationSuggestions(
                matching: searchText,
                from: viewContext
            )
        }
        showingSuggestions = !locationSuggestions.isEmpty
    }
    
    private func loadAllSuggestions() {
        locationSuggestions = LocationService.shared.getUniqueLocations(from: viewContext)
    }
}

#Preview {
    VStack {
        LocationInputField(location: .constant(""))
        Spacer()
    }
    .padding()
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}