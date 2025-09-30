//
//  PurchasesView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI
import CoreData

struct PurchasesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var showingAddPurchase = false
    
    // Fetch purchases or purchase records
    @FetchRequest(
        entity: PurchaseRecord.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PurchaseRecord.date_added, ascending: false)]
    ) private var purchases: FetchedResults<PurchaseRecord>
    
    private var filteredPurchases: [PurchaseRecord] {
        if searchText.isEmpty {
            return Array(purchases)
        } else {
            return purchases.filter { purchase in
                // Search through various fields of the purchase
                let searchLower = searchText.lowercased()
                let supplierName = purchase.supplier?.lowercased() ?? ""
                let notes = purchase.notes?.lowercased() ?? ""
                
                return supplierName.contains(searchLower) || 
                       notes.contains(searchLower)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                if !purchases.isEmpty {
                    HStack {
                        TextField("Search purchases...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                if filteredPurchases.isEmpty {
                    if purchases.isEmpty {
                        // Empty state when no purchases exist
                        ContentUnavailableView(
                            "No Purchases Yet",
                            systemImage: "creditcard",
                            description: Text("Track your purchase records here")
                        )
                    } else {
                        // Empty search results
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    // Purchase list
                    List {
                        ForEach(filteredPurchases, id: \.objectID) { purchase in
                            PurchaseListRowView(purchase: purchase)
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }
                        .onDelete(perform: deletePurchases)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        // Refresh purchases if needed
                    }
                }
            }
            .navigationTitle("Purchases")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddPurchase = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                if !purchases.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddPurchase) {
                NavigationStack {
                    AddPurchaseRecordView()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearPurchasesSearch)) { _ in
            searchText = ""
        }
    }
    
    private func deletePurchases(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let purchase = filteredPurchases[index]
                viewContext.delete(purchase)
            }
            
            do {
                try viewContext.save()
            } catch {
                print("❌ Failed to delete purchases: \(error)")
            }
        }
    }
}

struct PurchaseListRowView: View {
    let purchase: PurchaseRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "creditcard.fill")
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            // Purchase details
            VStack(alignment: .leading, spacing: 4) {
                // Supplier name
                HStack {
                    Text(purchase.supplier ?? "Unknown Supplier")
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                // Purchase details
                HStack {
                    // Date
                    if let date = purchase.date_added {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Total price
                    if purchase.price > 0 {
                        Text("$\(purchase.price, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                
                // Notes if available
                if let notes = purchase.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PurchasesView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}