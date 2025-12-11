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
    
    init(purchaseRecord: PurchaseRecordModel, purchaseService: PurchaseRecordService? = nil) {
        self._purchaseRecord = State(initialValue: purchaseRecord)

        if let service = purchaseService {
            self.purchaseService = service
        } else {
            let deps = AppDependencies(persistenceController: .createTestController())
            self.purchaseService = deps.purchaseRecordService
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Information
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        LabeledDetailRow.prominent(
                            label: "Supplier",
                            value: purchaseRecord.supplier,
                            alignment: .leading
                        )

                        Spacer()

                        LabeledDetailRow.prominent(
                            label: "Total Amount",
                            value: purchaseRecord.formattedPrice ?? "—",
                            alignment: .trailing
                        )
                    }

                    LabeledDetailRow.horizontal(
                        label: "Date",
                        value: purchaseRecord.dateAdded.formatted(date: .abbreviated, time: .omitted)
                    )
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
                            .foregroundColor(DesignSystem.Colors.textSecondary)
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
                        .accessibilityIdentifier("purchase_detail_add_item")
                    }

                    CustomEmptyStateView(
                        icon: "cart",
                        iconSize: 40,
                        title: "No Items Added",
                        description: "Add items to track what you purchased"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
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
                Button("Edit") {
                    showingEditSheet = true
                }
                .accessibilityIdentifier("purchase_detail_edit")
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
        .errorAlert(errorState)
    }
}

#Preview {
    let sampleRecord = PurchaseRecordModel(
        supplier: "Mountain Glass Supply",
        subtotal: Decimal(string: "300.00"),
        tax: Decimal(string: "24.50"),
        shipping: Decimal(string: "0.00"),
        notes: "Monthly order of glass rods and tools"
    )

    let deps = AppDependencies(persistenceController: .createTestController())

    NavigationView {
        PurchaseRecordDetailView(purchaseRecord: sampleRecord, purchaseService: deps.purchaseRecordService)
    }
}
