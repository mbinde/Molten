//
//  LogbookView.swift
//  Molten
//
//  Created by Melissa Binde on 9/29/25.
//

import SwiftUI

struct LogbookView: View {
    @State private var logEntries: [UUID] = []  // Placeholder for future log entries
    @State private var isLoading = false
    @State private var showingAddEntry = false
    @State private var searchText = ""
    @State private var searchTitlesOnly = false

    // Filter state (minimal, for SearchAndFilterHeader)
    @State private var selectedTags: Set<String> = []
    @State private var showingAllTags = false
    @State private var selectedCOEs: Set<Int32> = []
    @State private var showingCOESelection = false
    @State private var selectedManufacturers: Set<String> = []
    @State private var showingManufacturerSelection = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar at top (only show when we have entries)
                if !logEntries.isEmpty {
                    SearchAndFilterHeader(
                        searchText: $searchText,
                        searchTitlesOnly: $searchTitlesOnly,
                        selectedTags: $selectedTags,
                        showingAllTags: $showingAllTags,
                        allAvailableTags: [],  // No tags for now
                        selectedCOEs: $selectedCOEs,
                        showingCOESelection: $showingCOESelection,
                        allAvailableCOEs: [],  // No COE filter for now
                        selectedManufacturers: $selectedManufacturers,
                        showingManufacturerSelection: $showingManufacturerSelection,
                        allAvailableManufacturers: [],  // No manufacturer filter for now
                        sortMenuContent: {
                            AnyView(
                                Group {
                                    Button("Date (Newest First)") { }
                                    Button("Date (Oldest First)") { }
                                    Button("Title (A-Z)") { }
                                    Button("Title (Z-A)") { }
                                }
                            )
                        },
                        searchPlaceholder: "Search logbook entries..."
                    )
                }

                // Main content
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if logEntries.isEmpty && searchText.isEmpty {
                    emptyStateView
                } else {
                    logEntriesListView
                }
            }
            .navigationTitle("Logbook")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingAddEntry) {
                AddLogbookEntryView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "book.pages")
                    .font(.system(size: 70))
                    .foregroundColor(.blue)

                Text("No Logbook Entries Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Document your completed glass projects, record techniques, and track your creative journey")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Create Your First Entry") {
                    showingAddEntry = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List View

    private var logEntriesListView: some View {
        List {
            // Placeholder for future log entries list
            Text("Log entries will appear here")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddEntry = true
            } label: {
                Label("Add Entry", systemImage: "plus")
            }
        }
    }
}

#Preview {
    LogbookView()
}