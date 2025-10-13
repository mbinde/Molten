//
//  PurchasesView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI

struct PurchasesView: View {
    @State private var searchText = ""
    @State private var showingAddPurchase = false
    @State private var purchases: [PurchaseRecordModel] = []
    @State private var isLoading = true
    
    private let purchaseService: PurchaseRecordService
    
    init(purchaseService: PurchaseRecordService? = nil) {
        if let service = purchaseService {
            self.purchaseService = service
        } else {
            // Create default service with mock repository for preview/default usage
            let mockRepository = MockPurchaseRecordRepository()
            self.purchaseService = PurchaseRecordService(repository: mockRepository)
        }
    }
    
    private var filteredPurchases: [PurchaseRecordModel] {
        if searchText.isEmpty {
            return purchases
        } else {
            return purchases.filter { purchase in
                // Search through various fields of the purchase
                let searchLower = searchText.lowercased()
                let supplierName = purchase.supplier.lowercased()
                let notes = purchase.notes?.lowercased() ?? ""
                
                return supplierName.contains(searchLower) || 
                       notes.contains(searchLower)
            }
        }
    }
    
    // Load purchases from repository
    private func loadPurchases() async {
        do {
            let loadedPurchases = try await purchaseService.getAllRecords()
            await MainActor.run {
                purchases = loadedPurchases.sorted { $0.dateAdded > $1.dateAdded }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
            print("Error loading purchases: \(error)")
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
                
                if isLoading {
                    // Loading state
                    VStack {
                        Spacer()
                        ProgressView("Loading purchases...")
                        Spacer()
                    }
                } else if filteredPurchases.isEmpty {
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
                        ForEach(filteredPurchases, id: \.id) { purchase in
                            PurchaseListRowView(purchase: purchase)
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }
                        .onDelete(perform: deletePurchases)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        // Refresh purchases
                        await loadPurchases()
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
                
                if !purchases.isEmpty && !isLoading {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
            }
            .task {
                await loadPurchases()
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
        Task {
            do {
                for index in offsets {
                    let purchase = filteredPurchases[index]
                    try await purchaseService.deleteRecord(id: purchase.id)
                }
                
                // Reload purchases after deletion
                await loadPurchases()
            } catch {
                print("❌ Failed to delete purchases: \(error)")
            }
        }
    }
}

struct PurchaseListRowView: View {
    let purchase: PurchaseRecordModel
    
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
                    Text(purchase.supplier)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                // Purchase details
                HStack {
                    // Date
                    Text(purchase.dateAdded, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
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
    let mockRepository = MockPurchaseRecordRepository()
    let purchaseService = PurchaseRecordService(repository: mockRepository)
    
    return PurchasesView(purchaseService: purchaseService)
}
