//
//  ProjectsView.swift
//  Molten
//
//  Main views for browsing and managing project plans
//

import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif

// Navigation destination for project plans
enum ProjectDestination: Hashable {
    case existing(ProjectModel)
    case new(ProjectModel)
}

struct ProjectsView: View, CachedDataDeletion {
    @State private var projects: [ProjectModel] = []
    @State private var isLoading = false
    @State private var refreshTrigger = 0
    @State private var navigationPath = NavigationPath()

    // Search and filter state
    @State private var searchText = ""
    @State private var searchTitlesOnly = false
    @State private var selectedTags: Set<String> = []
    @State private var showingAllTags = false
    @State private var selectedCOEs: Set<Int32> = []
    @State private var showingCOESelection = false
    @State private var selectedProductTypes: Set<String> = []  // Allow filtering by product type
    @State private var showingProductTypeSelection = false
    @State private var selectedManufacturers: Set<String> = []
    @State private var showingManufacturerSelection = false

    private let deps: AppDependencies
    private let projectPlanRepository: ProjectRepository
    private let userImageRepository: UserImageRepository
    private let projectImageRepository: ProjectImageRepository

    init(deps: AppDependencies = AppDependencies()) {
        self.deps = deps
        self.projectPlanRepository = deps.projectRepository
        self.userImageRepository = deps.userImageRepository
        self.projectImageRepository = deps.projectImageRepository
    }

    // MARK: - Computed Properties

    private var filteredProjects: [ProjectModel] {
        guard !searchText.isEmpty else {
            return projects
        }

        let lowercasedSearch = searchText.lowercased()

        return projects.filter { project in
            // Search in title
            if project.title.lowercased().contains(lowercasedSearch) {
                return true
            }

            // Search in summary if not titles-only mode
            if !searchTitlesOnly,
               let summary = project.summary,
               summary.lowercased().contains(lowercasedSearch) {
                return true
            }

            return false
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Search bar at top (only show when we have projects)
                // TODO: Migrate to native .searchable() with FilterChipsRow component (see CatalogView)
                if !projects.isEmpty {
                    StandardSearchAndFilterHeader(
                        searchText: $searchText,
                        searchTitlesOnly: $searchTitlesOnly,
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
                        searchPlaceholder: "Search projects..."
                    )
                }

                Group {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if projects.isEmpty && searchText.isEmpty {
                        ProjectsEmptyStates.standard(onCreatePlan: createNewPlan)
                    } else if filteredProjects.isEmpty {
                        ProjectsEmptyStates.searchResults
                    } else {
                        projectsListView
                    }
                }
                .id(refreshTrigger)
            }
            .navigationTitle("Projects")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: ProjectDestination.self) { destination in
                switch destination {
                case .existing(let plan):
                    ProjectDetailView(plan: plan, repository: projectPlanRepository, startInEditMode: false)
                case .new(let plan):
                    ProjectDetailView(plan: plan, repository: projectPlanRepository, startInEditMode: true)
                }
            }
            .toolbar {
                toolbarContent
            }
            .task {
                await loadProjects()
            }
            #if os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)) { _ in
                // Refresh projects when app becomes active (e.g., returning from share extension)
                Task {
                    await loadProjects()
                }
            }
            #else
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh projects when app becomes active (e.g., returning from share extension)
                Task {
                    await loadProjects()
                }
            }
            #endif
        }
    }

    // MARK: - List View

    private var projectsListView: some View {
        List {
            ForEach(filteredProjects) { plan in
                NavigationLink(value: ProjectDestination.existing(plan)) {
                    // TODO: Load tags in batch in loadProjects() and pass here (Phase 4)
                    ProjectRow(plan: plan, tags: [])
                }
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await deleteItem(filteredProjects[index])
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task {
                    await createNewPlan()
                }
            } label: {
                Label("Add Plan", systemImage: "plus")
            }
        }
    }

    // MARK: - Data Loading

    private func loadProjects() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load active (non-archived) plans from repository
            projects = try await projectPlanRepository.getActiveProjects()
            refreshTrigger += 1
        } catch {
            // Handle error silently - empty state will show
            projects = []
        }
    }

    // MARK: - Actions

    private func createNewPlan() async {
        // Create a blank plan with default values (empty title)
        // NOTE: We don't save it yet - only save when user clicks "Done"
        let blankPlan = ProjectModel(
            title: "",
            type: .idea,
            coe: "any",
            summary: nil
        )

        await MainActor.run {
            navigationPath.append(ProjectDestination.new(blankPlan))
        }
    }

    // MARK: - CachedDataDeletion Implementation

    func performDeletion(for item: ProjectModel) async throws {
        // Delete all images associated with this project
        let images = try await userImageRepository.getImages(
            ownerType: .projectPlan,
            ownerId: item.id.uuidString
        )

        for image in images {
            try await userImageRepository.deleteImage(image.id)
        }

        // Delete the project (Core Data will cascade delete ProjectImage, ProjectStep, etc.)
        try await projectPlanRepository.deleteProject(id: item.id)
    }

    func removeFromCache(_ item: ProjectModel) async {
        await MainActor.run {
            projects.removeAll { $0.id == item.id }
        }
    }

    func reloadData() async {
        await loadProjects()
    }
}

