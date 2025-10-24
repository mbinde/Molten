//
//  LocationAutoCompleteField.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//  Updated for GlassItem architecture - 10/14/25
//

import SwiftUI

/// Auto-complete input field for inventory item locations using repository pattern
struct LocationAutoCompleteField: View {
    @Binding var location: String
    let locationRepository: LocationRepository
    
    @State private var showingSuggestions = false
    @State private var locationSuggestions: [String] = []
    @FocusState private var isTextFieldFocused: Bool
    
    init(location: Binding<String>, locationRepository: LocationRepository) {
        self._location = location
        self.locationRepository = locationRepository
    }
    
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
                        .background(Color(white: 1.0))
                        
                        if suggestion != locationSuggestions.prefix(5).last {
                            Divider()
                        }
                    }
                }
                .background(Color(white: 1.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .zIndex(1)
            }
        }
    }
    
    private func updateSuggestions(for searchText: String) {
        Task {
            locationSuggestions = await getLocationSuggestions(matching: searchText)
            await MainActor.run {
                showingSuggestions = !locationSuggestions.isEmpty && isTextFieldFocused
            }
        }
    }
    
    private func loadInitialSuggestions() {
        Task {
            locationSuggestions = await getUniqueLocations()
        }
    }
    
    // MARK: - Location Service Methods (Repository Pattern)
    
    private func getUniqueLocations() async -> [String] {
        do {
            // Get all distinct location names from the location repository
            let locationNames = try await locationRepository.getDistinctLocationNames()
            return locationNames
            
        } catch {
            print("❌ Failed to fetch location suggestions: \(error)")
            return []
        }
    }
    
    private func getLocationSuggestions(matching searchText: String) async -> [String] {
        do {
            let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !trimmedSearchText.isEmpty else {
                return try await locationRepository.getDistinctLocationNames()
            }
            
            // Use repository method to get location names with prefix
            let suggestions = try await locationRepository.getLocationNames(withPrefix: trimmedSearchText)
            return suggestions
            
        } catch {
            print("❌ Failed to get location suggestions: \(error)")
            return []
        }
    }
}

#Preview {
    let _ = RepositoryFactory.configureForTesting()
    @Previewable @State var location = ""

    VStack {
        LocationAutoCompleteField(
            location: $location,
            locationRepository: RepositoryFactory.createLocationRepository()
        )
        Spacer()
    }
    .padding()
}
