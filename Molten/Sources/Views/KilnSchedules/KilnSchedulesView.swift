//
//  KilnSchedulesView.swift
//  Molten
//
//  Main view for browsing and managing kiln firing schedules
//

import SwiftUI

struct KilnSchedulesView: View {
    @State private var viewModel: KilnSchedulesViewModel
    private let kilnScheduleService: KilnScheduleService

    // UI-only state
    @State private var showingAddSchedule = false
    @State private var showingImportSchedule = false
    @State private var scheduleToDelete: KilnSchedule?
    @State private var showingDeleteConfirmation = false
    @State private var showingSortOptions = false

    // Accept ViewModel directly (protocol-based pattern)
    init(viewModel: KilnSchedulesViewModel, kilnScheduleService: KilnScheduleService) {
        self._viewModel = State(initialValue: viewModel)
        self.kilnScheduleService = kilnScheduleService
    }

    // Convenience init for production use
    init(kilnScheduleService: KilnScheduleService) {
        let viewModel = KilnSchedulesViewModel(kilnScheduleService: kilnScheduleService)
        self.init(viewModel: viewModel, kilnScheduleService: kilnScheduleService)
    }

    /// Convenience init using AppDependencies
    init(deps: AppDependencies = AppDependencies()) {
        let service = deps.kilnScheduleService
        let viewModel = KilnSchedulesViewModel(kilnScheduleService: service)
        self.init(viewModel: viewModel, kilnScheduleService: service)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search box at top (similar to CatalogView)
                if !viewModel.isLoading && viewModel.hasData {
                    searchHeader
                }

                // Main content
                ZStack {
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.hasError {
                        errorView
                    } else if !viewModel.hasData {
                        emptyStateView
                    } else {
                        schedulesList
                    }
                }
            }
            .navigationTitle("Kiln Schedules")
            .toolbar {
                toolbarContent
            }
            .task {
                await viewModel.loadSchedules()
            }
            .sheet(isPresented: $showingAddSchedule) {
                AddKilnScheduleView(kilnScheduleService: kilnScheduleService) { newSchedule in
                    Task {
                        await viewModel.loadSchedules()
                    }
                }
            }
            .sheet(isPresented: $showingImportSchedule) {
                ImportScheduleView(kilnScheduleService: kilnScheduleService) {
                    Task {
                        await viewModel.loadSchedules()
                    }
                }
            }
            .confirmationDialog(
                "Delete Schedule",
                isPresented: $showingDeleteConfirmation,
                presenting: scheduleToDelete
            ) { schedule in
                Button("Delete", role: .destructive) {
                    Task {
                        try? await viewModel.deleteSchedule(schedule)
                    }
                }
            } message: { schedule in
                Text("Are you sure you want to delete \"\(schedule.name)\"?")
            }
        }
    }

    // MARK: - View Components

    private var searchHeader: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search schedules", text: $viewModel.searchText)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    private var schedulesList: some View {
        List {
            // Filter section
            if !viewModel.availableTechniques.isEmpty {
                techniqueFilterSection
            }

            // Schedules
            ForEach(viewModel.filteredSchedules) { schedule in
                NavigationLink(destination: KilnScheduleDetailView(
                    schedule: schedule,
                    kilnScheduleService: kilnScheduleService,
                    onScheduleUpdated: { _ in
                        Task {
                            await viewModel.loadSchedules()
                        }
                    },
                    onScheduleDeleted: {
                        Task {
                            await viewModel.loadSchedules()
                        }
                    }
                )) {
                    KilnScheduleRowView(schedule: schedule)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        scheduleToDelete = schedule
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        Task {
                            try? await viewModel.duplicateSchedule(
                                schedule,
                                newName: "\(schedule.name) (Copy)"
                            )
                        }
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    .tint(.blue)
                }
            }

            // Results footer
            if !viewModel.filteredSchedules.isEmpty {
                Section {
                    Text("\(viewModel.filteredSchedules.count) schedule\(viewModel.filteredSchedules.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var techniqueFilterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "All" filter chip
                    filterChip(
                        title: "All",
                        isSelected: viewModel.selectedTechnique == nil
                    ) {
                        viewModel.selectedTechnique = nil
                    }

                    // Technique filter chips
                    ForEach(viewModel.availableTechniques, id: \.self) { technique in
                        filterChip(
                            title: technique?.displayName ?? "No Technique",
                            isSelected: viewModel.selectedTechnique == technique
                        ) {
                            viewModel.selectedTechnique = technique
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddSchedule = true
            } label: {
                Image(systemName: "plus")
            }
        }

        ToolbarItem(placement: .secondaryAction) {
            Menu {
                Button {
                    showingImportSchedule = true
                } label: {
                    Label("Import Schedule", systemImage: "square.and.arrow.down")
                }

                Divider()

                Picker("Sort By", selection: $viewModel.sortOption) {
                    ForEach(KilnScheduleSortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    private var loadingView: some View {
        LoadingStateView(message: "Loading schedules...")
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)

            Text(viewModel.errorMessage ?? "An error occurred")
                .font(.headline)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await viewModel.loadSchedules()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "fireplace.fill")
                .font(.system(size: 80, weight: .regular))
                .foregroundColor(.secondary.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Kiln Schedules")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create your first firing schedule to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showingAddSchedule = true
            } label: {
                Label("Create Schedule", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    return KilnSchedulesView(deps: deps)
}
