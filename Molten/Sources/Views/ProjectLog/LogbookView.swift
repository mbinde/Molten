//
//  LogbookView.swift
//  Molten
//
//  Created by Melissa Binde on 9/29/25.
//

import SwiftUI

struct LogbookView: View, CachedDataDeletion {
    // MIGRATION COMPLETE: All state managed by ViewModel ✓
    @State private var showingAddEntry = false

    // Filter state (minimal, for SearchAndFilterHeader - not yet used by ViewModel)
    @State private var selectedTags: Set<String> = []
    @State private var showingAllTags = false
    @State private var selectedCOEs: Set<Int32> = []
    @State private var showingCOESelection = false
    @State private var selectedProductTypes: Set<String> = []  // Not used in logbook, but required by SearchAndFilterHeader
    @State private var showingProductTypeSelection = false
    @State private var selectedManufacturers: Set<String> = []
    @State private var showingManufacturerSelection = false

    @State private var viewModel: LogbookViewModel
    private let logbookRepository: LogbookRepository  // Keep for child views
    private let userImageRepository: UserImageRepository

    // Accept ViewModel directly (protocol-based pattern)
    init(viewModel: LogbookViewModel, logbookRepository: LogbookRepository, userImageRepository: UserImageRepository) {
        self._viewModel = State(initialValue: viewModel)
        self.logbookRepository = logbookRepository
        self.userImageRepository = userImageRepository
    }

    // Convenience init for production use (DI pattern)
    init(logbookRepository: LogbookRepository, deps: AppDependencies = AppDependencies()) {
        let viewModel = LogbookViewModel(logbookRepository: logbookRepository)
        self.init(viewModel: viewModel, logbookRepository: logbookRepository, userImageRepository: deps.userImageRepository)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar at top (only show when we have entries)
                // TODO: Migrate to native .searchable() with FilterChipsRow component (see CatalogView)
                if !viewModel.logEntries.isEmpty {
                    StandardSearchAndFilterHeader(
                        searchText: $viewModel.searchText,
                        searchTitlesOnly: $viewModel.searchTitlesOnly,
                        selectedTags: $selectedTags,
                        selectedCOEs: $selectedCOEs,
                        selectedManufacturers: $selectedManufacturers,
                        selectedProductTypes: $selectedProductTypes,
                        showingAllTags: $showingAllTags,
                        showingCOESelection: $showingCOESelection,
                        showingManufacturerSelection: $showingManufacturerSelection,
                        showingProductTypeSelection: $showingProductTypeSelection,
                        allAvailableTags: [],
                        allAvailableCOEs: [],
                        allAvailableManufacturers: [],
                        allAvailableProductTypes: [],
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
                if viewModel.isLoading {
                    LoadingStateView()
                } else if viewModel.logEntries.isEmpty && viewModel.searchText.isEmpty {
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
            .sheet(isPresented: $showingAddEntry, onDismiss: {
                // Reload entries when sheet is dismissed (after saving)
                Task {
                    await viewModel.loadLogEntries()
                }
            }) {
                // Pass same repository instance to child view
                AddLogbookEntryView(logbookRepository: logbookRepository)
            }
            .task {
                await viewModel.loadLogEntries()
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
                    .foregroundColor(Color.accentColor)

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
            ForEach(viewModel.logEntries) { entry in
                LogbookRow(logEntry: entry)
                    .accessibilityIdentifier("logbook.entry.\(entry.id)")
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await deleteItem(viewModel.logEntries[index])
                    }
                }
            }
        }
        .accessibilityIdentifier("logbook.list")
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

    // MIGRATION COMPLETE: loadLogEntries() removed - using viewModel.loadLogEntries() ✓

    // MARK: - CachedDataDeletion Implementation

    func performDeletion(for item: LogbookModel) async throws {
        // Delete all images associated with this logbook entry
        let images = try await userImageRepository.getImages(
            ownerType: .projectLog,
            ownerId: item.id.uuidString
        )

        for image in images {
            try await userImageRepository.deleteImage(image.id)
        }

        // Delete the logbook entry (Core Data will cascade delete related entities)
        try await logbookRepository.deleteLog(id: item.id)
    }

    func removeFromCache(_ item: LogbookModel) async {
        await MainActor.run {
            viewModel.logEntries.removeAll { $0.id == item.id }
        }
    }

    func reloadData() async {
        await viewModel.loadLogEntries()
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
    let deps = AppDependencies(persistenceController: .createTestController())
    return LogbookView(logbookRepository: deps.logbookRepository)
}