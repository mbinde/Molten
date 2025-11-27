//
//  FormatSearchView.swift
//  Molten
//
//  Extracted from LabelDesignerView.swift
//

import SwiftUI

/// Search view for finding label formats
struct FormatSearchView: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @Binding var selectedFormat: AveryFormat
    let filteredFormats: [AveryFormat]

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)

                TextField("Search label formats...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("format_search_clear")
                }

                Button("Cancel") {
                    withAnimation {
                        isSearching = false
                        searchText = ""
                    }
                }
                .font(.body)
                .accessibilityIdentifier("format_search_cancel")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }

        // Search results in a scrollable container
        if filteredFormats.isEmpty && !searchText.isEmpty {
            Text("No formats match \"\(searchText)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredFormats, id: \.name) { format in
                        FormatRow(format: format) {
                            withAnimation {
                                selectedFormat = format
                                isSearching = false
                                searchText = ""
                            }
                        }
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }
}
