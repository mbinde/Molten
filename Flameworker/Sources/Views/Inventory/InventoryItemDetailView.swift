//
//  InventoryItemDetailView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isAdvancedImageLoadingEnabled = false

struct InventoryItemDetailView: View {
    let item: InventoryItemModel
    let startInEditMode: Bool
    let inventoryService: InventoryService
    
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    
    // MARK: - Dependency Injection Initializers
    
    /// Initialize with business model and service (repository pattern)
    init(item: InventoryItemModel, inventoryService: InventoryService, startInEditMode: Bool = false) {
        self.item = item
        self.inventoryService = inventoryService
        self.startInEditMode = startInEditMode
    }
    
    /// Convenience initializer for business model only (creates default service for previews)
    init(item: InventoryItemModel, startInEditMode: Bool = false) {
        self.item = item
        self.startInEditMode = startInEditMode
        // Create service with Core Data repository for previews
        let coreDataRepository = CoreDataInventoryRepository()
        self.inventoryService = InventoryService(repository: coreDataRepository)
    }
    @State private var showingDeleteAlert = false
    @State private var errorMessage: String?
    @StateObject private var errorState = ErrorAlertState()
    
    // Editing state - populated from business model
    @State private var count = ""
    @State private var selectedType: InventoryItemType = .inventory
    @State private var notes = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with business model data
                businessModelHeaderSection
                
                // Inventory details
                inventoryDetailsSection
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle(isEditing ? "Edit Item" : "Inventory Item")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(isEditing ? "Cancel" : "Done") {
                    if isEditing {
                        if startInEditMode {
                            dismiss()
                        } else {
                            isEditing = false
                        }
                    } else {
                        dismiss()
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                if !isEditing {
                    Button("Edit") {
                        isEditing = true
                    }
                }
            }
        }
        .onAppear {
            loadInitialData()
            if startInEditMode {
                isEditing = true
            }
        }
        .errorAlert(errorState)
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialData() {
        // Load data from business model
        count = String(item.quantity)
        selectedType = item.type
        notes = item.notes ?? ""
    }
    
    // MARK: - View Sections
    
    @ViewBuilder
    private var businessModelHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.catalogCode)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Quantity: \(item.quantity)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(item.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.type.color.opacity(0.2))
                    .foregroundColor(item.type.color)
                    .cornerRadius(8)
            }
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var inventoryDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Inventory Details")
                .font(.headline)
            
            if isEditing {
                editingForm
            } else {
                readOnlyContent
            }
        }
    }
    
    @ViewBuilder
    private var readOnlyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailRow(title: "Catalog Code", value: item.catalogCode)
            DetailRow(title: "Quantity", value: String(item.quantity))
            DetailRow(title: "Type", value: item.type.displayName)
            
            if let notes = item.notes, !notes.isEmpty {
                DetailRow(title: "Notes", value: notes)
            }
        }
    }
    
    @ViewBuilder
    private var editingForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Quantity", text: $count)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
            
            Picker("Type", selection: $selectedType) {
                ForEach(InventoryItemType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            TextField("Notes", text: $notes, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
    }
}

// MARK: - Helper Views

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}
