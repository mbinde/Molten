//  PurchaseRecordDetailAlternateView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isPurchaseRecordsEnabled = false

// ⚠️ LEGACY VIEW - Disabled in current release
// This view has been simplified during Core Data migration
// Full functionality available in PurchaseRecordDetailView.swift

struct PurchaseRecordDetailAlternateView: View {
    let purchase: PurchaseRecordModel
    @Environment(\.dismiss) private var dismiss
    
    private let purchaseService: PurchaseRecordService
    
    @State private var showingDeleteAlert = false
    
    init(purchase: PurchaseRecordModel, purchaseService: PurchaseRecordService? = nil) {
        self.purchase = purchase
        
        if let service = purchaseService {
            self.purchaseService = service
        } else {
            let mockRepository = MockPurchaseRecordRepository()
            self.purchaseService = PurchaseRecordService(repository: mockRepository)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("Legacy Purchase Detail View")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This alternate purchase detail view is currently disabled. Use the main PurchaseRecordDetailView for full functionality.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if isPurchaseRecordsEnabled {
                    // Basic purchase information (simplified)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Purchase Details:")
                            .font(.headline)
                        Text("Supplier: \(purchase.supplier)")
                        Text("Price: \(purchase.formattedPrice)")
                        Text("Date: \(purchase.dateAdded, style: .date)")
                        if let notes = purchase.notes, !notes.isEmpty {
                            Text("Notes: \(notes)")
                                .lineLimit(3)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Purchase Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delete") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                    .disabled(!isPurchaseRecordsEnabled)
                }
            }
            .alert("Delete Purchase Record", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deletePurchase()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Actions
    
    private func deletePurchase() {
        Task {
            do {
                try await purchaseService.deleteRecord(id: purchase.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error deleting purchase record: \(error)")
            }
        }
    }
}

#Preview {
    let samplePurchase = PurchaseRecordModel(
        id: UUID().uuidString,
        supplier: "Mountain Glass",
        price: 125.50,
        dateAdded: Date(),
        notes: "Monthly glass rod order - various colors and sizes for upcoming projects"
    )
    
    let mockRepository = MockPurchaseRecordRepository()
    let purchaseService = PurchaseRecordService(repository: mockRepository)
    
    NavigationStack {
        PurchaseRecordDetailAlternateView(purchase: samplePurchase, purchaseService: purchaseService)
    }
}