//
//  PurchaseRecordDetailView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI

struct PurchaseRecordDetailView: View {
    @State private var purchaseRecord: PurchaseRecordModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var errorState = ErrorAlertState()
    
    private let purchaseService: PurchaseRecordService
    
    @State private var showingEditSheet = false
    @State private var showingAddItem = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    init(purchaseRecord: PurchaseRecordModel, purchaseService: PurchaseRecordService? = nil) {
        self._purchaseRecord = State(initialValue: purchaseRecord)
        
        if let service = purchaseService {
            self.purchaseService = service
        } else {
            let mockRepository = MockPurchaseRecordRepository()
            self.purchaseService = PurchaseRecordService(repository: mockRepository)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Information
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Supplier")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(purchaseRecord.supplier)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(purchaseRecord.formattedPrice)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    HStack {
                        Text("Date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(purchaseRecord.dateAdded, style: .date)
                            .font(.body)
                    }
                    
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                // Notes Section
                if let notes = purchaseRecord.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }
                
                // Purchase Items Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Items")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Add Item") {
                            showingAddItem = true
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    
                    Text("No items added yet")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Purchase Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Menu {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                    Button("Delete", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .disabled(isDeleting)
        .overlay {
            if isDeleting {
                VStack {
                    ProgressView("Deleting...")
                    Text("Please wait")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            // TODO: Create proper EditPurchaseRecordView
            Text("Edit functionality coming soon...")
                .navigationTitle("Edit Purchase")
        }
        .sheet(isPresented: $showingAddItem) {
            Text("Add Item - Not Implemented Yet")
                .navigationTitle("Add Item")
        }
        .alert("Delete Purchase Record", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePurchaseRecord()
            }
        } message: {
            Text("Are you sure you want to delete this purchase record? This action cannot be undone.")
        }
        .errorAlert(errorState)
    }
    
    // MARK: - Actions
    
    private func deletePurchaseRecord() {
        isDeleting = true
        
        Task {
            let result = await ErrorHandler.shared.executeAsync(context: "Deleting purchase record") {
                try await purchaseService.deleteRecord(id: purchaseRecord.id)
            }
            
            await MainActor.run {
                isDeleting = false
                
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    errorState.show(error: error, context: "Failed to delete purchase record")
                }
            }
        }
    }
}

#Preview {
    let sampleRecord = PurchaseRecordModel(
        id: UUID().uuidString,
        supplier: "Mountain Glass Supply",
        price: 324.50,
        dateAdded: Date(),
        notes: "Monthly order of glass rods and tools"
    )
    
    let mockRepository = MockPurchaseRecordRepository()
    let purchaseService = PurchaseRecordService(repository: mockRepository)
    
    return NavigationView {
        PurchaseRecordDetailView(purchaseRecord: sampleRecord, purchaseService: purchaseService)
    }
}
