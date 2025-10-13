//
//  PurchaseRecordView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isPurchaseRecordsEnabled = false

struct PurchaseRecordView: View {
    @State private var searchText = ""
    @State private var selectedDateFilter: DateFilter = .all
    @State private var showingAddPurchase = false
    @State private var purchaseRecords: [PurchaseRecordModel] = []
    @State private var isLoading = false
    
    private let purchaseService: PurchaseRecordService
    
    init(purchaseService: PurchaseRecordService? = nil) {
        if let service = purchaseService {
            self.purchaseService = service
        } else {
            let mockRepository = MockPurchaseRecordRepository()
            self.purchaseService = PurchaseRecordService(repository: mockRepository)
        }
    }
    
    // Filtered purchases based on search and date
    private var filteredPurchases: [PurchaseRecordModel] {
        var purchases = purchaseRecords
        
        // Apply text search filter
        if !searchText.isEmpty {
            purchases = purchases.filter { purchase in
                let searchLower = searchText.lowercased()
                let supplier = purchase.supplier.lowercased()
                let notes = purchase.notes?.lowercased() ?? ""
                let totalAmount = String(purchase.price)
                
                return supplier.contains(searchLower) ||
                       notes.contains(searchLower) ||
                       totalAmount.contains(searchLower)
            }
        }
        
        // Apply date filter
        purchases = filterByDateRange(purchases, dateFilter: selectedDateFilter)
        
        return purchases
    }
    
    // Load purchases from repository
    private func loadPurchases() async {
        if !isPurchaseRecordsEnabled { return }
        
        isLoading = true
        do {
            let records = try await purchaseService.getAllRecords()
            await MainActor.run {
                purchaseRecords = records.sorted { $0.dateAdded > $1.dateAdded }
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
        if isPurchaseRecordsEnabled {
            purchaseRecordsContent
        } else {
            featureDisabledView
        }
    }
    
    private var featureDisabledView: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Icon and title
                VStack(spacing: 16) {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("Purchase Records")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text("Available in future update")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Text("This feature is temporarily disabled in the current release. It will be available in a future version of the app.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Purchase Records")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var purchaseRecordsContent: some View {
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
            .task {
                await loadPurchases()
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
            ForEach(filteredPurchases, id: \.id) { purchase in
                NavigationLink {
                    PurchaseRecordDetailView(purchaseRecord: purchase)
                } label: {
                    // Inline row view using repository pattern
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(purchase.supplier)
                                .font(.headline)
                                .lineLimit(1)
                            
                            Text(purchase.dateAdded, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(purchase.formattedPrice)
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
        Task {
            do {
                for index in offsets {
                    let purchase = filteredPurchases[index]
                    try await purchaseService.deleteRecord(id: purchase.id)
                }
                
                // Reload purchases after deletion
                await loadPurchases()
            } catch {
                print("❌ Error deleting purchase records: \(error)")
            }
        }
    }
    
    private func filterByDateRange(_ purchases: [PurchaseRecordModel], dateFilter: DateFilter) -> [PurchaseRecordModel] {
        let now = Date()
        let calendar = Calendar.current
        
        switch dateFilter {
        case .all:
            return purchases
        case .thisWeek:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return purchases.filter { $0.dateAdded >= weekAgo }
        case .thisMonth:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return purchases.filter { $0.dateAdded >= monthAgo }
        case .thisYear:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return purchases.filter { $0.dateAdded >= yearAgo }
        }
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
    let mockRepository = MockPurchaseRecordRepository()
    let purchaseService = PurchaseRecordService(repository: mockRepository)
    
    return PurchaseRecordView(purchaseService: purchaseService)
}
