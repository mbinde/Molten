//
//  PurchaseRecordView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI
import CoreData

struct PurchaseRecordView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var selectedDateFilter: DateFilter = .all
    @State private var showingAddPurchase = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
        animation: .default
    )
    private var purchaseRecords: FetchedResults<PurchaseRecord>
    
    // Filtered purchases based on search and date
    private var filteredPurchases: [PurchaseRecord] {
        var purchases = Array(purchaseRecords)
        
        // Apply text search filter
        if !searchText.isEmpty {
            purchases = purchases.filter { purchase in
                let searchLower = searchText.lowercased()
                let supplier = (purchase.value(forKey: "supplier") as? String) ?? ""
                let notes = (purchase.value(forKey: "notes") as? String) ?? ""
                let totalAmount = (purchase.value(forKey: "totalAmount") as? Double) ?? 0.0
                
                return supplier.lowercased().contains(searchLower) ||
                       notes.lowercased().contains(searchLower) ||
                       String(totalAmount).contains(searchLower)
            }
        }
        
        // Apply date filter
        purchases = filterByDateRange(purchases, dateFilter: selectedDateFilter)
        
        return purchases
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if purchaseRecords.isEmpty {
                    purchaseEmptyState
                } else if filteredPurchases.isEmpty && !searchText.isEmpty {
                    searchEmptyState
                } else {
                    purchaseListView
                }
            }
            .navigationTitle("Purchase Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showingAddPurchase = true
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                // Search and filter controls
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search purchases...", text: $searchText)
                            
                            // Clear button
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    // Date filter
                    Picker("Date Filter", selection: $selectedDateFilter) {
                        ForEach(DateFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .sheet(isPresented: $showingAddPurchase) {
                AddPurchaseRecordView()
            }
        }
    }
    
    // MARK: - Views
    
    private var purchaseEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Purchase Records")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start tracking your glass purchases by adding your first record.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Add First Purchase") {
                showingAddPurchase = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var searchEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("No purchase records match '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var purchaseListView: some View {
        List {
            ForEach(filteredPurchases, id: \.objectID) { purchase in
                NavigationLink {
                    PurchaseRecordDetailView(purchaseRecord: purchase)
                } label: {
                    // Inline row view to avoid import conflicts
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(purchase.value(forKey: "supplier") as? String ?? "Unknown Supplier")
                                .font(.headline)
                                .lineLimit(1)
                            
                            if let date = purchase.value(forKey: "date") as? Date {
                                Text(date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatCurrency(purchase.value(forKey: "totalAmount") as? Double ?? 0.0))
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deletePurchases)
        }
    }
    
    // MARK: - Actions
    
    private func deletePurchases(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredPurchases[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("❌ Error deleting purchase records: \(error)")
            }
        }
    }
    
    private func filterByDateRange(_ purchases: [PurchaseRecord], dateFilter: DateFilter) -> [PurchaseRecord] {
        let now = Date()
        let calendar = Calendar.current
        
        switch dateFilter {
        case .all:
            return purchases
        case .thisWeek:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return purchases.filter { (($0.value(forKey: "date") as? Date) ?? Date.distantPast) >= weekAgo }
        case .thisMonth:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return purchases.filter { (($0.value(forKey: "date") as? Date) ?? Date.distantPast) >= monthAgo }
        case .thisYear:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return purchases.filter { (($0.value(forKey: "date") as? Date) ?? Date.distantPast) >= yearAgo }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Date Filter Enum
enum DateFilter: String, CaseIterable {
    case all = "All"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    
    var displayName: String {
        return self.rawValue
    }
}

#Preview {
    PurchaseRecordView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
