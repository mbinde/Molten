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

struct ProjectsView: View {
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
    @State private var selectedManufacturers: Set<String> = []
    @State private var showingManufacturerSelection = false

    private let projectPlanRepository: ProjectRepository

    init(projectPlanRepository: ProjectRepository = RepositoryFactory.createProjectRepository()) {
        self.projectPlanRepository = projectPlanRepository
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
                if !projects.isEmpty {
                    SearchAndFilterHeader(
                        searchText: $searchText,
                        searchTitlesOnly: $searchTitlesOnly,
                        selectedTags: $selectedTags,
                        showingAllTags: $showingAllTags,
                        allAvailableTags: [],
                        selectedCOEs: $selectedCOEs,
                        showingCOESelection: $showingCOESelection,
                        allAvailableCOEs: [],
                        selectedManufacturers: $selectedManufacturers,
                        showingManufacturerSelection: $showingManufacturerSelection,
                        allAvailableManufacturers: [],
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

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if projects.isEmpty && searchText.isEmpty {
                    emptyStateView
                } else if filteredProjects.isEmpty {
                    noResultsView
                } else {
                    projectsListView
                }
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
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 70))
                    .foregroundColor(.blue)

                Text("No Project Plans Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Save notes, photos, recipes, and tutorials to bring your glass art ideas to life")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Create Your First Plan") {
                    Task {
                        await createNewPlan()
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                Text("No Results Found")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Try adjusting your search")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List View

    private var projectsListView: some View {
        List {
            ForEach(filteredProjects) { plan in
                NavigationLink(value: ProjectDestination.existing(plan)) {
                    ProjectRow(plan: plan)
                }
            }
        }
        .id(refreshTrigger)
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
}

// MARK: - Supporting Views

struct ProjectRow: View {
    let plan: ProjectModel
    @State private var tags: [String] = []

    private let projectService: ProjectService

    init(plan: ProjectModel, projectService: ProjectService = RepositoryFactory.createProjectService()) {
        self.plan = plan
        self.projectService = projectService
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Thumbnail on the left
            #if canImport(UIKit)
            ProjectThumbnail(
                heroImageId: plan.heroImageId,
                projectId: plan.id,
                projectCategory: .plan,
                size: 60
            )
            #endif

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.headline)

                if let summary = plan.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    Text(plan.dateCreated, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !tags.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(tags.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .task {
            // Load tags asynchronously
            await loadTags()
        }
    }

    private func loadTags() async {
        do {
            let loadedTags = try await projectService.getTags(forProject: plan.id)
            await MainActor.run {
                self.tags = loadedTags
            }
        } catch {
            // Silently fail - tags are optional
            print("Failed to load tags for project \(plan.id): \(error)")
        }
    }
}

struct AddProjectView: View {
    @Environment(\.dismiss) private var dismiss

    // Basic info
    @State private var title = ""
    @State private var summary = ""
    @State private var type: ProjectType = .recipe
    @State private var coe: String = "any"

    // Categorization
    @State private var tags: [String] = []
    @State private var showingTagEditor = false

    // Optional metadata
    @State private var difficultyLevel: DifficultyLevel?
    @State private var estimatedHours: String = ""
    @State private var priceMin: String = ""
    @State private var priceMax: String = ""
    @State private var showingOptionalDetails = false

    private let projectPlanRepository: ProjectRepository
    private let projectService: ProjectService
    private let onSave: ((ProjectModel) -> Void)?

    init(
        projectPlanRepository: ProjectRepository = RepositoryFactory.createProjectRepository(),
        onSave: ((ProjectModel) -> Void)? = nil
    ) {
        self.projectPlanRepository = projectPlanRepository
        self.projectService = RepositoryFactory.createProjectService()
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Basic Information") {
                TextField("Title", text: $title)
                    .font(.body)

                Picker("Type", selection: $type) {
                    ForEach([ProjectType.recipe, .tutorial, .idea, .technique, .commission], id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                TextField("Summary (optional)", text: $summary, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Categorization") {
                HStack {
                    Text("Tags")
                    Spacer()
                    if tags.isEmpty {
                        Text("None")
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(tags.count) tag\(tags.count == 1 ? "" : "s")")
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingTagEditor = true
                }

                if !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }

            Section {
                DisclosureGroup(
                    isExpanded: $showingOptionalDetails,
                    content: {
                        Picker("Glass COE", selection: $coe) {
                            Text("Any").tag("any")
                            Text("33").tag("33")
                            Text("90").tag("90")
                            Text("96").tag("96")
                            Text("104").tag("104")
                        }

                        Picker("Difficulty", selection: $difficultyLevel) {
                            Text("Not set").tag(nil as DifficultyLevel?)
                            Text("Beginner").tag(DifficultyLevel.beginner as DifficultyLevel?)
                            Text("Intermediate").tag(DifficultyLevel.intermediate as DifficultyLevel?)
                            Text("Advanced").tag(DifficultyLevel.advanced as DifficultyLevel?)
                            Text("Expert").tag(DifficultyLevel.expert as DifficultyLevel?)
                        }

                        HStack {
                            Text("Estimated Time (hours)")
                            Spacer()
                            TextField("0", text: $estimatedHours)
                                #if canImport(UIKit)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }

                        HStack {
                            Text("Price Range (optional)")
                            Spacer()
                            Text("$")
                            TextField("Min", text: $priceMin)
                                #if canImport(UIKit)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                            Text("-")
                            TextField("Max", text: $priceMax)
                                #if canImport(UIKit)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                        }
                    },
                    label: {
                        Text("Optional Details")
                    }
                )
            }

            Section {
                Text("You can add steps, glass, images, and reference URLs after creating the plan.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("New Project")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await savePlan()
                    }
                }
                .disabled(title.isEmpty)
            }
        }
        .sheet(isPresented: $showingTagEditor) {
            TagEditorSheet(tags: $tags)
        }
    }

    private func savePlan() async {
        // Parse optional values
        let estimatedTime: TimeInterval? = {
            guard let hours = Double(estimatedHours), hours > 0 else { return nil }
            return hours * 3600 // Convert to seconds
        }()

        let priceRange: PriceRange? = {
            let min = Decimal(string: priceMin)
            let max = Decimal(string: priceMax)
            if min != nil || max != nil {
                return PriceRange(min: min, max: max, currency: "USD")
            }
            return nil
        }()

        let plan = ProjectModel(
            title: title,
            type: type,
            coe: coe,
            summary: summary.isEmpty ? nil : summary,
            estimatedTime: estimatedTime,
            difficultyLevel: difficultyLevel,
            proposedPriceRange: priceRange
        )

        do {
            let createdPlan = try await projectPlanRepository.createProject(plan)

            // Save tags separately via ProjectService if user added any
            if !tags.isEmpty {
                try await projectService.setTags(tags, forProject: createdPlan.id)
            }

            await MainActor.run {
                // Call the callback with the created plan
                onSave?(createdPlan)
                dismiss()
            }
        } catch {
            // TODO: Show error alert
            print("Error saving plan: \(error)")
        }
    }
}

// MARK: - Tag Editor Sheet

struct TagEditorSheet: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Add Tag") {
                    HStack {
                        TextField("Enter tag name", text: $newTag)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif

                        Button("Add") {
                            let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            if !trimmed.isEmpty && !tags.contains(trimmed) {
                                tags.append(trimmed)
                                newTag = ""
                            }
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if !tags.isEmpty {
                    Section("Current Tags") {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Button(action: {
                                    tags.removeAll { $0 == tag }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Tags")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Project Plan Detail View

// Wrapper to make URL identifiable for sheet presentation
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ProjectDetailView: View {
    let projectId: UUID
    let repository: ProjectRepository
    @State private var isNewPlan: Bool  // Track if this is a new unsaved plan

    @State private var plan: ProjectModel?
    @State private var isLoading = false
    @State private var showingAddGlass = false
    @State private var showingAddURL = false
    @State private var urlToEdit: ProjectReferenceUrl?
    @State private var showingImagePicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingAddStep = false
    @State private var showingExport = false
    @State private var showingPDFExportOptions = false
    @State private var pdfFileURL: IdentifiableURL?  // Changed to IdentifiableURL
    @State private var exportedPlanURL: IdentifiableURL?  // For .moltenplan exports
    @State private var glassItemLookup: [String: GlassItemModel] = [:]
    @State private var loadedImages: [UUID: UIImage] = [:]  // Cache of loaded images
    @State private var isEditing = false

    // Edit mode fields
    @State private var editTitle = ""
    @State private var editSummary = ""
    @State private var editPlanType: ProjectType = .recipe
    @State private var editCOE: String = "any"
    @State private var editTags: [String] = []
    @State private var displayTags: [String] = []  // For display in view mode
    @State private var editDifficultyLevel: DifficultyLevel?
    @State private var editEstimatedHours: String = ""
    @State private var editPriceMin: String = ""
    @State private var editPriceMax: String = ""
    @State private var showingTagEditor = false
    @State private var showingOptionalFields = false
    @State private var showingSuggestedGlass = true
    @State private var showingReferenceUrls = true
    @State private var showingSteps = true

    @Environment(\.dismiss) private var dismiss

    private let catalogService: CatalogService
    private let projectService: ProjectService

    init(plan: ProjectModel, repository: ProjectRepository, startInEditMode: Bool = false) {
        self.projectId = plan.id
        self.repository = repository
        self._isNewPlan = State(initialValue: startInEditMode)  // If starting in edit mode, it's a new plan
        self._plan = State(initialValue: plan)
        self._isEditing = State(initialValue: startInEditMode)
        self.catalogService = RepositoryFactory.createCatalogService()
        self.projectService = RepositoryFactory.createProjectService()
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let plan = plan {
                planDetailContent(for: plan)
            } else {
                Text("Plan not found")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(plan?.title.isEmpty == false && plan!.title != "Untitled" ? plan!.title : "New Plan")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelEditing()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingExport = true
                        } label: {
                            Label("Share Plan (.moltenplan)", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            showingPDFExportOptions = true
                        } label: {
                            Label("Export as PDF", systemImage: "doc.text")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddGlass, onDismiss: {
            Task {
                await loadPlan()
            }
        }) {
            NavigationStack {
                if let plan = plan {
                    AddSuggestedGlassView(plan: plan, repository: repository)
                }
            }
        }
        .sheet(isPresented: $showingTagEditor) {
            TagEditorSheet(tags: $editTags)
        }
        .sheet(isPresented: $showingAddURL, onDismiss: {
            Task {
                await loadPlan()
            }
        }) {
            NavigationStack {
                if let plan = plan {
                    AddReferenceURLView(plan: plan, repository: repository)
                }
            }
        }
        .sheet(item: $urlToEdit, onDismiss: {
            Task {
                await loadPlan()
            }
        }) { url in
            NavigationStack {
                if let plan = plan {
                    EditReferenceURLView(plan: plan, repository: repository, urlToEdit: url)
                }
            }
        }
        #if canImport(PhotosUI)
        .photosPicker(
            isPresented: $showingImagePicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                await loadSelectedImages(newItems)
            }
        }
        #endif
        .sheet(isPresented: $showingAddStep, onDismiss: {
            Task {
                await loadPlan()
            }
        }) {
            NavigationStack {
                if let plan = plan {
                    AddStepView(plan: plan, repository: repository)
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            if let plan = plan {
                ExportPlanView(plan: plan) { exportedURL in
                    exportedPlanURL = IdentifiableURL(url: exportedURL)
                }
            }
        }
        .sheet(item: $exportedPlanURL) { identifiableURL in
            ShareSheet(items: [identifiableURL.url])
        }
        .sheet(item: $pdfFileURL) { identifiableURL in
            PDFPreviewView(url: identifiableURL.url)
        }
        .sheet(isPresented: $showingPDFExportOptions) {
            if let plan = plan {
                PDFExportOptionsView(plan: plan) { includeAuthor in
                    Task {
                        await exportAsPDF(includeAuthor: includeAuthor)
                    }
                }
            }
        }
        .task {
            await loadPlan()

            // If starting in edit mode, populate edit fields
            if isEditing {
                enterEditMode()
            }

            // Load tags for display
            await loadTags()
        }
    }

    /// Compute total glass needed across all steps
    private func computeTotalGlassNeeded(from plan: ProjectModel) -> [ProjectGlassItem] {
        // Flatten all glass items from steps
        let allGlass = plan.steps.flatMap { $0.glassItemsNeeded ?? [] }

        // Group by naturalKey or freeformDescription (for free-form items)
        var totals: [String: (ProjectGlassItem, Decimal)] = [:]

        for glass in allGlass {
            let key = glass.stableId ?? glass.freeformDescription ?? ""
            if let existing = totals[key] {
                totals[key] = (existing.0, existing.1 + glass.quantity)
            } else {
                totals[key] = (glass, glass.quantity)
            }
        }

        // Create new ProjectGlassItems with totaled quantities
        return totals.values.map { (template, totalQty) in
            if template.isCatalogItem, let naturalKey = template.stableId {
                return ProjectGlassItem(
                    stableId: naturalKey,
                    quantity: totalQty,
                    unit: template.unit,
                    notes: template.notes
                )
            } else if let freeformDescription = template.freeformDescription {
                return ProjectGlassItem(
                    freeformDescription: freeformDescription,
                    quantity: totalQty,
                    unit: template.unit,
                    notes: template.notes
                )
            } else {
                // Fallback: create a placeholder
                return ProjectGlassItem(
                    freeformDescription: "Unknown glass",
                    quantity: totalQty,
                    unit: template.unit
                )
            }
        }
    }

    @ViewBuilder
    private func planDetailContent(for plan: ProjectModel) -> some View {
        List {
            detailsSection(for: plan)

            // Show author card if plan has author info (read-only)
            if let author = plan.author, !isEditing {
                Section("Created By") {
                    AuthorCardView(author: author)
                }
            }

            primaryImageSection(for: plan)

            optionalFieldsSection

            tagsSection(for: plan)

            stepsSection(for: plan)

            totalGlassSection(for: plan)

            referenceUrlsSection(for: plan)

            metadataSection(for: plan)
        }
    }

    // MARK: - Section Builders

    @ViewBuilder
    private func detailsSection(for plan: ProjectModel) -> some View {
        Section {
            if isEditing {
                // Edit mode - show editable fields
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter plan title", text: $editTitle)
                        .font(.body)
                }

                Picker("Type", selection: $editPlanType) {
                    ForEach([ProjectType.recipe, .tutorial, .idea, .technique, .commission], id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                Picker("Glass COE", selection: $editCOE) {
                    Text("Any").tag("any")
                    Text("33").tag("33")
                    Text("90").tag("90")
                    Text("96").tag("96")
                    Text("104").tag("104")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Summary")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Summary (optional)", text: $editSummary, axis: .vertical)
                        .lineLimit(2...4)
                }
            } else {
                // View mode - show read-only fields
                LabeledContent("Title", value: plan.title)
                LabeledContent("Type", value: plan.type.displayName)
                LabeledContent("COE", value: plan.coe)

                if let summary = plan.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Summary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(summary)
                            .font(.body)
                    }
                }

                if let difficulty = plan.difficultyLevel {
                    LabeledContent("Difficulty", value: difficulty.rawValue.capitalized)
                }

                if let time = plan.estimatedTime {
                    let hours = time / 3600
                    LabeledContent("Estimated Time", value: String(format: "%.1f hours", hours))
                }

                if let priceRange = plan.proposedPriceRange {
                    let minStr = priceRange.min.map { "$\($0)" } ?? "?"
                    let maxStr = priceRange.max.map { "$\($0)" } ?? "?"
                    LabeledContent("Price Range", value: "\(minStr) - \(maxStr)")
                }
            }
        } header: {
            HStack {
                Text("Details")
                Spacer()
                if !isEditing {
                    Button("Edit") {
                        enterEditMode()
                    }
                    .font(.subheadline)
                    .textCase(nil)
                }
            }
        }
    }

    @ViewBuilder
    private var optionalFieldsSection: some View {
        // Optional Fields Section (Edit Mode Only)
        if isEditing {
            Section {
                DisclosureGroup(
                    isExpanded: $showingOptionalFields,
                    content: {
                        optionalFieldsContent
                    },
                    label: {
                        Text("Additional Optional Fields")
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var optionalFieldsContent: some View {
        Picker("Difficulty", selection: $editDifficultyLevel) {
            Text("Not set").tag(nil as DifficultyLevel?)
            Text("Beginner").tag(DifficultyLevel.beginner as DifficultyLevel?)
            Text("Intermediate").tag(DifficultyLevel.intermediate as DifficultyLevel?)
            Text("Advanced").tag(DifficultyLevel.advanced as DifficultyLevel?)
            Text("Expert").tag(DifficultyLevel.expert as DifficultyLevel?)
        }

        HStack {
            Text("Estimated Time (hours)")
            Spacer()
            TextField("0", text: $editEstimatedHours)
                #if canImport(UIKit)
                .keyboardType(.decimalPad)
                #endif
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
        }

        HStack {
            Text("Price Range")
            Spacer()
            Text("$")
            TextField("Min", text: $editPriceMin)
                #if canImport(UIKit)
                .keyboardType(.decimalPad)
                #endif
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
            Text("-")
            TextField("Max", text: $editPriceMax)
                #if canImport(UIKit)
                .keyboardType(.decimalPad)
                #endif
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
        }

        tagsEditorContent
    }

    @ViewBuilder
    private var tagsEditorContent: some View {
        HStack {
            Text("Tags")
            Spacer()
            if editTags.isEmpty {
                Text("None")
                    .foregroundColor(.secondary)
            } else {
                Text("\(editTags.count) tag\(editTags.count == 1 ? "" : "s")")
                    .foregroundColor(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingTagEditor = true
        }

        if !editTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(editTags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tagsSection(for plan: ProjectModel) -> some View {
        // Tags Section (View Mode Only)
        if !isEditing && !displayTags.isEmpty {
            Section("Tags") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(displayTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stepsSection(for plan: ProjectModel) -> some View {
        Section {
            DisclosureGroup(
                isExpanded: $showingSteps,
                content: {
                    stepsContent(for: plan)
                },
                label: {
                    Text("Steps (\(plan.steps.count))")
                }
            )
        }
    }

    @ViewBuilder
    private func stepsContent(for plan: ProjectModel) -> some View {
        if plan.steps.isEmpty {
            if isEditing {
                Button(action: {
                    Task {
                        await ensurePlanExistsInRepository()
                        await MainActor.run {
                            showingAddStep = true
                        }
                    }
                }) {
                    Label("Add Step", systemImage: "plus.circle")
                }
            } else {
                Text("No steps yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        } else {
            ForEach(plan.steps) { step in
                stepRow(step)
            }

            if isEditing {
                Button(action: {
                    Task {
                        await ensurePlanExistsInRepository()
                        await MainActor.run {
                            showingAddStep = true
                        }
                    }
                }) {
                    Label("Add more steps", systemImage: "plus.circle")
                }
            }
        }
    }

    @ViewBuilder
    private func stepRow(_ step: ProjectStepModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Step title and info
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.headline)
                if let description = step.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Glass items for this step
            if let glassItems = step.glassItemsNeeded, !glassItems.isEmpty {
                stepGlassItems(glassItems)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func stepGlassItems(_ glassItems: [ProjectGlassItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Glass:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            ForEach(glassItems) { glass in
                HStack {
                    Text(glass.isCatalogItem ? (glassItemLookup[glass.stableId!]?.name ?? glass.displayName) : glass.displayName)
                        .font(.caption)
                    Spacer()
                    if glass.quantity > 0 {
                        Text(verbatim: "\(glass.quantity) \(glass.unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func totalGlassSection(for plan: ProjectModel) -> some View {
        Section {
            DisclosureGroup(
                isExpanded: $showingSuggestedGlass,
                content: {
                    totalGlassContent(for: plan)
                },
                label: {
                    let totalGlass = computeTotalGlassNeeded(from: plan)
                    Text("Total Glass Needed (\(totalGlass.count))")
                }
            )
        }
    }

    @ViewBuilder
    private func totalGlassContent(for plan: ProjectModel) -> some View {
        let totalGlass = computeTotalGlassNeeded(from: plan)

        if totalGlass.isEmpty {
            Text("No glass items added to steps yet")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
        } else {
            ForEach(totalGlass) { projectGlassItem in
                totalGlassRow(projectGlassItem)
            }

            Text("Add glass items to individual steps to see them totaled here")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func totalGlassRow(_ projectGlassItem: ProjectGlassItem) -> some View {
        if projectGlassItem.isCatalogItem, let glassItem = glassItemLookup[projectGlassItem.stableId!] {
            // Catalog item with full card display
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Glass item card
                GlassItemCard(item: glassItem, variant: .compact)

                // Quantity and unit
                if projectGlassItem.quantity > 0 {
                    HStack {
                        Text("Total Needed:")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(verbatim: "\(projectGlassItem.quantity) \(projectGlassItem.unit)")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                            .foregroundColor(DesignSystem.Colors.accentPrimary)
                    }
                    .padding(.horizontal, DesignSystem.Padding.standard)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        } else {
            // Free-form text or fallback display
            HStack {
                Text(projectGlassItem.displayName)
                    .font(.caption)
                Spacer()
                if projectGlassItem.quantity > 0 {
                    Text(verbatim: "\(projectGlassItem.quantity) \(projectGlassItem.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func primaryImageSection(for plan: ProjectModel) -> some View {
        #if canImport(UIKit)
        Section {
            PrimaryImageSelector(
                images: plan.images,
                loadedImages: loadedImages,
                currentPrimaryImageId: plan.heroImageId,
                onSelectPrimary: { newId in
                    Task {
                        await updatePrimaryImage(newId)
                    }
                },
                onAddImage: {
                    Task {
                        await ensurePlanExistsInRepository()
                        await MainActor.run {
                            showingImagePicker = true
                        }
                    }
                }
            )
        } header: {
            Text("Images")
        } footer: {
            if !plan.images.isEmpty {
                Text("Tap an image to set it as the primary image. The primary image appears in PDF exports.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        #endif
    }


    @ViewBuilder
    private func referenceUrlsSection(for plan: ProjectModel) -> some View {
        Section {
            DisclosureGroup(
                isExpanded: $showingReferenceUrls,
                content: {
                    referenceUrlsContent(for: plan)
                },
                label: {
                    Text("Reference URLs (\(plan.referenceUrls.count))")
                }
            )
        }
    }

    @ViewBuilder
    private func referenceUrlsContent(for plan: ProjectModel) -> some View {
        if plan.referenceUrls.isEmpty {
            if isEditing {
                Button(action: {
                    Task {
                        await ensurePlanExistsInRepository()
                        await MainActor.run {
                            showingAddURL = true
                        }
                    }
                }) {
                    Label("Add Reference URL", systemImage: "plus.circle")
                }
            } else {
                Text("No reference URLs yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        } else {
            ForEach(plan.referenceUrls) { url in
                VStack(alignment: .leading, spacing: 8) {
                    if let title = url.title {
                        Text(title)
                            .font(.headline)
                    }
                    Link(url.url, destination: URL(string: url.url)!)
                        .font(.caption)
                        .foregroundColor(.blue)
                    if let description = url.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Action buttons (only in edit mode)
                    if isEditing {
                        HStack {
                            Button(action: {
                                Task {
                                    await ensurePlanExistsInRepository()
                                    await MainActor.run {
                                        urlToEdit = url
                                    }
                                }
                            }) {
                                Label("Edit", systemImage: "pencil")
                                    .font(.caption)
                            }

                            Spacer()

                            Button(action: {
                                Task {
                                    await deleteReferenceURL(url.id)
                                }
                            }) {
                                Label("Delete", systemImage: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }

            if isEditing {
                Button(action: {
                    Task {
                        await ensurePlanExistsInRepository()
                        await MainActor.run {
                            showingAddURL = true
                        }
                    }
                }) {
                    Label("Add more URLs", systemImage: "plus.circle")
                }
            }
        }
    }

    private func deleteReferenceURL(_ urlId: UUID) async {
        guard let plan = plan else { return }

        // Remove the URL from the plan's referenceUrls array
        let updatedUrls = plan.referenceUrls.filter { $0.id != urlId }

        let updatedPlan = ProjectModel(
            id: plan.id,
            title: plan.title,
            type: plan.type,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: plan.isArchived,
            coe: plan.coe,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: plan.images,
            heroImageId: plan.heroImageId,
            glassItems: plan.glassItems,
            referenceUrls: updatedUrls,
            author: plan.author,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            try await repository.updateProject(updatedPlan)
            await MainActor.run {
                self.plan = updatedPlan
            }
        } catch {
            print("Error deleting reference URL: \(error)")
        }
    }

    @ViewBuilder
    private func metadataSection(for plan: ProjectModel) -> some View {
        Section("Metadata") {
            LabeledContent("Created", value: plan.dateCreated, format: .dateTime)
            LabeledContent("Modified", value: plan.dateModified, format: .dateTime)
            LabeledContent("Times Used", value: String(plan.timesUsed))

            if let lastUsed = plan.lastUsedDate {
                LabeledContent("Last Used", value: lastUsed, format: .dateTime)
            }
        }
    }

    // MARK: - Edit Mode Functions

    private func enterEditMode() {
        guard let plan = plan else { return }

        // Copy current values to edit fields
        editTitle = plan.title
        editSummary = plan.summary ?? ""
        editPlanType = plan.type
        editCOE = plan.coe
        // Copy current tags from displayTags (already loaded)
        editTags = displayTags
        editDifficultyLevel = plan.difficultyLevel

        // Convert estimated time from seconds to hours
        if let time = plan.estimatedTime {
            let hours = time / 3600
            editEstimatedHours = String(format: "%.1f", hours)
        } else {
            editEstimatedHours = ""
        }

        // Convert price range to strings
        if let priceRange = plan.proposedPriceRange {
            editPriceMin = priceRange.min.map { "\($0)" } ?? ""
            editPriceMax = priceRange.max.map { "\($0)" } ?? ""
        } else {
            editPriceMin = ""
            editPriceMax = ""
        }

        isEditing = true
    }

    private func cancelEditing() {
        // If this is a new plan that hasn't been saved, dismiss the view
        if isNewPlan {
            dismiss()
        } else {
            isEditing = false
        }
    }

    private func saveChanges() async {
        guard let plan = plan else { return }

        // Parse estimated time from hours to seconds
        let estimatedTime: TimeInterval? = {
            guard let hours = Double(editEstimatedHours), hours > 0 else { return nil }
            return hours * 3600
        }()

        // Parse price range
        let priceRange: PriceRange? = {
            let min = Decimal(string: editPriceMin)
            let max = Decimal(string: editPriceMax)
            if min != nil || max != nil {
                return PriceRange(min: min, max: max, currency: "USD")
            }
            return nil
        }()

        // Create updated plan
        let updatedPlan = ProjectModel(
            id: plan.id,
            title: editTitle,
            type: editPlanType,
            dateCreated: plan.dateCreated,
            dateModified: Date(), // Update modification date
            isArchived: plan.isArchived,
            coe: editCOE,
            summary: editSummary.isEmpty ? nil : editSummary,
            steps: plan.steps,
            estimatedTime: estimatedTime,
            difficultyLevel: editDifficultyLevel,
            proposedPriceRange: priceRange,
            images: plan.images,
            heroImageId: plan.heroImageId,
            glassItems: plan.glassItems,
            referenceUrls: plan.referenceUrls,
            author: plan.author,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            // If this is a new plan, create it; otherwise, update it
            if isNewPlan {
                _ = try await repository.createProject(updatedPlan)
            } else {
                try await repository.updateProject(updatedPlan)
            }

            // Save tags separately via ProjectService
            try await projectService.setTags(editTags, forProject: updatedPlan.id)

            await MainActor.run {
                self.plan = updatedPlan
                self.displayTags = editTags  // Update display tags
                isEditing = false

                // If it was a new plan, dismiss after saving
                if isNewPlan {
                    dismiss()
                }
            }
        } catch {
            print("Error saving plan changes: \(error)")
            // TODO: Show error alert
        }
    }

    // MARK: - Data Loading

    private func loadPlan() async {
        // If this is a new plan, don't try to load from repository
        // (it doesn't exist yet)
        guard !isNewPlan else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Reload the plan from repository
            guard let reloadedPlan = try await repository.getProject(id: projectId) else {
                self.plan = nil
                return
            }

            await MainActor.run {
                self.plan = reloadedPlan
            }

            // Load glass item details from all steps
            let totalGlass = computeTotalGlassNeeded(from: reloadedPlan)
            await loadGlassItems(for: totalGlass)

            // Load plan images
            await loadPlanImages(for: reloadedPlan)
        } catch {
            print("Error loading plan: \(error)")
            await MainActor.run {
                self.plan = nil
            }
        }
    }

    // MARK: - Ensure Plan Exists

    /// Ensures the plan exists in the repository before opening child views (add glass, add URL, etc.)
    /// This is necessary because child views call updateProject() which requires the plan to exist
    ///
    /// Note: We save "Untitled" in the database as a fallback, but keep editTitle empty in the UI
    /// so the user still sees the empty text field and can fill it in later
    private func ensurePlanExistsInRepository() async {
        // If this is a new plan that hasn't been saved yet, save it now
        guard isNewPlan, let plan = plan else { return }

        do {
            // Create the plan in the repository with current edit values
            // Use "Untitled" as fallback title in DB, but don't change editTitle (keep UI showing empty field)
            let planToSave = ProjectModel(
                id: plan.id,
                title: editTitle.isEmpty ? "Untitled" : editTitle,
                type: editPlanType,
                dateCreated: plan.dateCreated,
                dateModified: Date(),
                isArchived: plan.isArchived,
                coe: editCOE,
                summary: editSummary.isEmpty ? nil : editSummary,
                steps: plan.steps,
                estimatedTime: nil, // We can parse these later if needed
                difficultyLevel: editDifficultyLevel,
                proposedPriceRange: nil,
                images: plan.images,
                heroImageId: plan.heroImageId,
                glassItems: plan.glassItems,
                referenceUrls: plan.referenceUrls,
                author: plan.author,
                timesUsed: plan.timesUsed,
                lastUsedDate: plan.lastUsedDate
            )

            _ = try await repository.createProject(planToSave)

            // Save tags if any were added during editing
            if !editTags.isEmpty {
                try await projectService.setTags(editTags, forProject: planToSave.id)
            }

            await MainActor.run {
                // Mark as no longer new - it now exists in the repository
                isNewPlan = false
                // Update plan reference but DON'T update editTitle - keep UI showing empty field
                self.plan = planToSave
            }
        } catch {
            print("Error creating plan in background: \(error)")
            // TODO: Show error alert
        }
    }

    private func loadGlassItems(for projectGlassItems: [ProjectGlassItem]) async {
        // Extract all natural keys (only for catalog items, not free-form)
        let naturalKeys = projectGlassItems.compactMap { $0.stableId }

        // Fetch all glass items from catalog
        do {
            let allItems = try await catalogService.getGlassItemsLightweight()
            let itemsDict: [String: GlassItemModel] = Dictionary(uniqueKeysWithValues: allItems.map { ($0.stable_id, $0) })

            // Build lookup dictionary for glass items we need
            var lookup: [String: GlassItemModel] = [:]
            for key in naturalKeys {
                if let item = itemsDict[key] {
                    lookup[key] = item
                }
            }

            await MainActor.run {
                self.glassItemLookup = lookup
            }
        } catch {
            print("Error loading glass items: \(error)")
        }
    }

    private func loadPlanImages(for plan: ProjectModel) async {
        #if canImport(UIKit)
        let userImageRepository = RepositoryFactory.createUserImageRepository()

        do {
            // Load all images for this plan
            let allImages = try await userImageRepository.getImages(
                ownerType: .projectPlan,
                ownerId: plan.id.uuidString
            )

            // Load each image
            var imageCache: [UUID: UIImage] = [:]
            for imageModel in allImages {
                if let image = try? await userImageRepository.loadImage(imageModel) {
                    imageCache[imageModel.id] = image
                }
            }

            await MainActor.run {
                self.loadedImages = imageCache
            }
        } catch {
            print("Error loading plan images: \(error)")
        }
        #endif
    }

    // MARK: - Image Management

    /// Update the primary image selection
    private func updatePrimaryImage(_ imageId: UUID?) async {
        guard let plan = plan else { return }

        let updatedPlan = ProjectModel(
            id: plan.id,
            title: plan.title,
            type: plan.type,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: plan.isArchived,
            coe: plan.coe,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: plan.images,
            heroImageId: imageId,
            glassItems: plan.glassItems,
            referenceUrls: plan.referenceUrls,
            author: plan.author,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            try await repository.updateProject(updatedPlan)
            await MainActor.run {
                self.plan = updatedPlan
            }
        } catch {
            print("Error updating primary image: \(error)")
        }
    }

    /// Load selected images from PhotosPicker
    #if canImport(PhotosUI)
    private func loadSelectedImages(_ items: [PhotosPickerItem]) async {
        guard let plan = plan else { return }

        let userImageRepository = RepositoryFactory.createUserImageRepository()
        let projectImageRepository = RepositoryFactory.createProjectImageRepository()

        var updatedImages = plan.images
        var newHeroImageId = plan.heroImageId

        for item in items {
            do {
                // Load the image data
                guard let data = try await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else {
                    continue
                }

                // Save image to UserImageRepository
                let userImageModel = try await userImageRepository.saveImage(
                    uiImage,
                    ownerType: .projectPlan,
                    ownerId: plan.id.uuidString,
                    type: .primary
                )

                // Create ProjectImageModel
                let newProjectImage = ProjectImageModel(
                    id: userImageModel.id,
                    projectId: plan.id,
                    projectCategory: .plan,
                    fileExtension: userImageModel.fileExtension,
                    caption: nil,
                    order: updatedImages.count
                )

                // Save metadata
                _ = try await projectImageRepository.createImageMetadata(newProjectImage)

                // Add to images array
                updatedImages.append(newProjectImage)

                // Set as hero image if it's the first image
                if newHeroImageId == nil {
                    newHeroImageId = newProjectImage.id
                }

                // Cache the loaded image
                await MainActor.run {
                    loadedImages[newProjectImage.id] = uiImage
                }
            } catch {
                print("Error loading image: \(error)")
            }
        }

        // Update the plan with new images
        let updatedPlan = ProjectModel(
            id: plan.id,
            title: plan.title,
            type: plan.type,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: plan.isArchived,
            coe: plan.coe,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: updatedImages,
            heroImageId: newHeroImageId,
            glassItems: plan.glassItems,
            referenceUrls: plan.referenceUrls,
            author: plan.author,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            try await repository.updateProject(updatedPlan)
            await MainActor.run {
                self.plan = updatedPlan
                // Clear the selected items so they can select again
                self.selectedPhotoItems = []
            }
        } catch {
            print("Error saving images to plan: \(error)")
        }
    }
    #endif

    // MARK: - Tag Loading

    /// Load tags for the current plan from ProjectService
    private func loadTags() async {
        guard let plan = plan else { return }

        do {
            let tags = try await projectService.getTags(forProject: plan.id)
            await MainActor.run {
                self.displayTags = tags
            }
        } catch {
            // Silently fail - tags are optional
            print("Failed to load tags for project \(plan.id): \(error)")
        }
    }

    // MARK: - PDF Export

    private func exportAsPDF(includeAuthor: Bool) async {
        guard var planToExport = plan else {
            return
        }

        // Add author info if requested and plan doesn't already have one
        if includeAuthor && planToExport.author == nil {
            let authorSettings = await MainActor.run { AuthorSettings.shared }
            if let authorModel = await MainActor.run(body: { authorSettings.createAuthorModel() }) {
                planToExport = ProjectModel(
                    id: planToExport.id,
                    title: planToExport.title,
                    type: planToExport.type,
                    dateCreated: planToExport.dateCreated,
                    dateModified: planToExport.dateModified,
                    isArchived: planToExport.isArchived,
                    coe: planToExport.coe,
                    summary: planToExport.summary,
                    steps: planToExport.steps,
                    estimatedTime: planToExport.estimatedTime,
                    difficultyLevel: planToExport.difficultyLevel,
                    proposedPriceRange: planToExport.proposedPriceRange,
                    images: planToExport.images,
                    heroImageId: planToExport.heroImageId,
                    glassItems: planToExport.glassItems,
                    referenceUrls: planToExport.referenceUrls,
                    author: authorModel,
                    timesUsed: planToExport.timesUsed,
                    lastUsedDate: planToExport.lastUsedDate
                )
            }
        }

        do {
            let userImageRepository = RepositoryFactory.createUserImageRepository()
            let pdfService = ProjectPDFService(userImageRepository: userImageRepository)

            let fileURL = try await pdfService.exportPlanAsPDF(planToExport)

            await MainActor.run {
                self.pdfFileURL = IdentifiableURL(url: fileURL)
            }
        } catch {
            print("Error exporting PDF: \(error)")
            // TODO: Show error alert
        }
    }
}

#Preview {
    ProjectsView()
}
