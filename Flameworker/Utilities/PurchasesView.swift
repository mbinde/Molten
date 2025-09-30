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
        sortDescriptors: [NSSortDescriptor(keyPath: \PurchaseRecord.purchase_date, ascending: false)]
    ) private var purchases: FetchedResults<PurchaseRecord>
    
    private var filteredPurchases: [PurchaseRecord] {
        if searchText.isEmpty {
            return Array(purchases)
        } else {
            return purchases.filter { purchase in
                // Search through various fields of the purchase
                let searchLower = searchText.lowercased()
                let itemName = purchase.item_name?.lowercased() ?? ""
                let notes = purchase.notes?.lowercased() ?? ""
                let vendor = purchase.vendor?.lowercased() ?? ""
                
                return itemName.contains(searchLower) || 
                       notes.contains(searchLower) ||
                       vendor.contains(searchLower)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                if !purchases.isEmpty {
                    SearchBar(text: $searchText, placeholder: "Search purchases...")
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                if filteredPurchases.isEmpty {
                    if purchases.isEmpty {
                        // Empty state when no purchases exist
                        ContentUnavailableView(
                            "No Purchases Yet",
                            systemImage: "creditcard",
                            description: Text("Track your welding supply purchases here")
                        )
                    } else {
                        // Empty search results
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    // Purchase list
                    List {
                        ForEach(filteredPurchases, id: \.objectID) { purchase in
                            PurchaseRowView(purchase: purchase)
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
                    PurchaseFormView()
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

struct PurchaseRowView: View {
    let purchase: PurchaseRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "creditcard.fill")
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            // Purchase details
            VStack(alignment: .leading, spacing: 4) {
                // Item name and vendor
                HStack {
                    Text(purchase.item_name ?? "Unknown Item")
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let vendor = purchase.vendor, !vendor.isEmpty {
                        Text(vendor)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Purchase details
                HStack {
                    // Date
                    if let date = purchase.purchase_date {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Total price
                    if purchase.total_price > 0 {
                        Text("$\(purchase.total_price, specifier: "%.2f")")
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
                .foregroundColor(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct PurchaseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var itemName = ""
    @State private var vendor = ""
    @State private var totalPrice = ""
    @State private var purchaseDate = Date()
    @State private var notes = ""
    
    var body: some View {
        Form {
            Section("Purchase Details") {
                TextField("Item name", text: $itemName)
                    .textInputAutocapitalization(.words)
                
                TextField("Vendor", text: $vendor)
                    .textInputAutocapitalization(.words)
                
                HStack {
                    Text("Total price")
                    Spacer()
                    Text("$")
                        .foregroundColor(.secondary)
                    TextField("0.00", text: $totalPrice)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                
                DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
            }
            
            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)
            }
        }
        .navigationTitle("Add Purchase")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    savePurchase()
                }
                .disabled(itemName.isEmpty)
            }
        }
    }
    
    private func savePurchase() {
        let purchase = PurchaseRecord(context: viewContext)
        purchase.item_name = itemName
        purchase.vendor = vendor.isEmpty ? nil : vendor
        purchase.total_price = Double(totalPrice) ?? 0.0
        purchase.purchase_date = purchaseDate
        purchase.notes = notes.isEmpty ? nil : notes
        purchase.created_at = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("❌ Failed to save purchase: \(error)")
        }
    }
}

// Add notification for clearing search
extension Notification.Name {
    static let clearPurchasesSearch = Notification.Name("clearPurchasesSearch")
}

#Preview {
    PurchasesView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}