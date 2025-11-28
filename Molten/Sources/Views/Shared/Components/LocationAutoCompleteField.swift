//
//  LocationAutoCompleteField.swift
//  Molten
//
//  Created by Assistant on 10/4/25.
//  Updated for GlassItem architecture - 10/14/25
//  Updated to use StorageLocationDefinitionRepository - 11/25/25
//

import SwiftUI

/// Auto-complete input field for inventory item locations using StorageLocationDefinition entities
struct LocationAutoCompleteField: View {
    @Binding var location: String
    let storageLocationDefinitionRepository: StorageLocationDefinitionRepository
    let placeholder: String

    @State private var showingSuggestions = false
    @State private var locationSuggestions: [String] = []
    @State private var allLocationNames: [String] = []
    @FocusState private var isTextFieldFocused: Bool

    init(
        location: Binding<String>,
        storageLocationDefinitionRepository: StorageLocationDefinitionRepository,
        placeholder: String = "Enter location (e.g., Workshop Shelf A)"
    ) {
        self._location = location
        self.storageLocationDefinitionRepository = storageLocationDefinitionRepository
        self.placeholder = placeholder
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField(placeholder, text: $location)
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
                        .accessibilityIdentifier("location_autocomplete_\(suggestion.replacingOccurrences(of: " ", with: "_").lowercased())")
                        
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
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmed.isEmpty {
            locationSuggestions = allLocationNames
        } else {
            // Filter locations that contain the search text (case-insensitive)
            locationSuggestions = allLocationNames.filter { $0.lowercased().contains(trimmed) }
        }

        showingSuggestions = !locationSuggestions.isEmpty && isTextFieldFocused
    }

    private func loadInitialSuggestions() {
        Task {
            allLocationNames = await fetchAllLocationNames()
            locationSuggestions = allLocationNames
        }
    }

    // MARK: - Location Service Methods (StorageLocationDefinition)

    private func fetchAllLocationNames() async -> [String] {
        do {
            // Get all location definitions from the repository
            let definitions = try await storageLocationDefinitionRepository.fetchAll()
            return definitions.map { $0.name }.sorted()
        } catch {
            print("❌ Failed to fetch location definitions: \(error)")
            return []
        }
    }
}

#Preview {
    @Previewable @State var location = ""
    let deps = AppDependencies(persistenceController: .createTestController())

    VStack {
        LocationAutoCompleteField(
            location: $location,
            storageLocationDefinitionRepository: deps.storageLocationDefinitionRepository
        )
        Spacer()
    }
    .padding()
}
