//
//  SearchStoresView.swift
//  Molten
//
//  Created for Store Maps Feature on 10/27/25.
//

import SwiftUI

/// Popup sheet for searching stores by name, city, or state
struct SearchStoresView: View {
    @Bindable var viewModel: StoreListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Search field
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Search by name, city, or state")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Enter search term...", text: $searchText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .focused($isTextFieldFocused)

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(DesignSystem.Padding.compact)
                    .background(Color(.systemGray6))
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }

                // Search button
                Button(action: applySearch) {
                    Text("Search")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(!searchText.isEmpty ? Color.accentColor : Color(.systemGray4))
                        .foregroundStyle(.white)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .disabled(searchText.isEmpty)
                .accessibilityIdentifier("search_stores_search")

                Spacer()
            }
            .padding(DesignSystem.Padding.standard)
            .navigationTitle("Search Stores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("search_stores_cancel")
                }
            }
            .onAppear {
                searchText = viewModel.searchText
                isTextFieldFocused = true
            }
        }
        .presentationDetents([.height(250)])
    }

    private func applySearch() {
        viewModel.searchText = searchText
        dismiss()
    }
}

#Preview {
    SearchStoresView(viewModel: StoreListViewModel())
}
