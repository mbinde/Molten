//
//  PurchasesView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI

struct PurchasesView: View {
    // MIGRATION COMPLETE: All state now managed by ViewModel ✓
    @State private var showingAddPurchase = false
    @State private var viewModel: PurchasesViewModel

    // Accept ViewModel directly (follows protocol-based pattern)
    init(viewModel: PurchasesViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    // Convenience init for production use (DI pattern)
    init(purchaseService: PurchaseRecordService) {
        let viewModel = PurchasesViewModel(purchaseService: purchaseService)
        self.init(viewModel: viewModel)
    }

    // Convenience computed property for cleaner code
    private var filteredPurchases: [PurchaseRecordModel] {
        viewModel.filteredPurchases
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    TextField("Search purchases...", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    if !viewModel.searchText.isEmpty {
                        Button("Clear") {
                            viewModel.clearSearch()
                        }
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("purchases_clear_search")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if viewModel.isLoading {
                    LoadingStateView(message: "Loading purchases...")
                } else if filteredPurchases.isEmpty {
                    if viewModel.purchases.isEmpty {
                        // Empty state when no purchases exist
                        emptyStateView
                    } else {
                        // Empty search results
                        searchEmptyStateView
                    }
                } else {
                    // Purchase list
                    List {
                        ForEach(filteredPurchases, id: \.id) { purchase in
                            PurchaseListRowView(purchase: purchase)
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                                .accessibilityIdentifier("purchases.record.\(purchase.id)")
                        }
                        .onDelete(perform: deletePurchases)
                    }
                    .accessibilityIdentifier("purchases.list")
                    .listStyle(.plain)
                    .refreshable {
                        // Refresh purchases
                        await viewModel.refreshPurchases()
                    }
                }
            }
            .navigationTitle("Purchases")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddPurchase = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("purchases_add_button")
                }

                #if os(iOS)
                if !viewModel.purchases.isEmpty && !viewModel.isLoading {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                            .accessibilityIdentifier("purchases_edit_button")
                    }
                }
                #endif
            }
            .task {
                await viewModel.loadPurchases()
            }
            .sheet(isPresented: $showingAddPurchase, onDismiss: {
                // Reload purchases when sheet is dismissed (after saving)
                Task {
                    await viewModel.loadPurchases()
                }
            }) {
                NavigationStack {
                    AddPurchaseRecordView()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearPurchasesSearch)) { _ in
            viewModel.clearSearch()
        }
    }
    
    private func deletePurchases(offsets: IndexSet) {
        Task {
            let idsToDelete = offsets.map { filteredPurchases[$0].id }
            await viewModel.deletePurchases(ids: idsToDelete)
        }
    }

    // MARK: - Empty States

    private var emptyStateView: some View {
        CustomEmptyStateView(
            icon: "creditcard",
            title: "No Purchases Yet",
            description: "Track your purchase records here",
            actionButton: .init(
                title: "Add Purchase",
                action: { showingAddPurchase = true },
                style: .prominent
            )
        )
    }

    private var searchEmptyStateView: some View {
        CustomEmptyStateView.searchResults(
            searchTerm: viewModel.searchText.isEmpty ? nil : viewModel.searchText,
            filters: [],
            onClearFilters: {
                viewModel.clearSearch()
            }
        )
    }
}

struct PurchaseListRowView: View {
    let purchase: PurchaseRecordModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "creditcard.fill")
                .foregroundColor(Color.accentColor)
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
                    if let formattedPrice = purchase.formattedPrice {
                        Text(formattedPrice)
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
                .foregroundColor(Color.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    return PurchasesView(purchaseService: deps.purchaseRecordService)
}
