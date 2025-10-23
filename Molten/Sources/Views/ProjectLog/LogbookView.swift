//
//  LogbookView.swift
//  Molten
//
//  Created by Melissa Binde on 9/29/25.
//

import SwiftUI

struct LogbookView: View {
    // Repository
    private let logbookRepository: LogbookRepository

    @State private var logEntries: [LogbookModel] = []
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

    init(logbookRepository: LogbookRepository? = nil) {
        self.logbookRepository = logbookRepository ?? RepositoryFactory.createLogbookRepository()
    }

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
                AddLogbookEntryView(logbookRepository: logbookRepository)
            }
            .task {
                await loadLogEntries()
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
            ForEach(logEntries) { entry in
                LogbookRow(logEntry: entry)
            }
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

    // MARK: - Data Loading

    private func loadLogEntries() async {
        isLoading = true
        defer { isLoading = false }

        do {
            logEntries = try await logbookRepository.getAllLogs()
        } catch {
            print("Error loading logbook entries: \(error)")
            logEntries = []
        }
    }
}

// MARK: - Logbook Row

struct LogbookRow: View {
    let logEntry: LogbookModel

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Thumbnail on the left
            #if canImport(UIKit)
            ProjectThumbnail(
                heroImageId: logEntry.heroImageId,
                projectId: logEntry.id,
                projectCategory: .log,
                size: 60
            )
            #endif

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(logEntry.title)
                    .font(.headline)

                if let notes = logEntry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    // Show completion date if available, otherwise created date
                    if let completionDate = logEntry.completionDate {
                        Text(completionDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(logEntry.dateCreated, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !logEntry.tags.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(logEntry.tags.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LogbookView()
}