//
//  ProjectPlansView.swift
//  Molten
//
//  Main views for browsing and managing project plans
//

import SwiftUI

// Navigation destination for project plans
enum ProjectPlanDestination: Hashable {
    case existing(ProjectPlanModel)
    case new(ProjectPlanModel)
}

struct ProjectPlansView: View {
    @State private var projectPlans: [ProjectPlanModel] = []
    @State private var isLoading = false
    @State private var refreshTrigger = 0
    @State private var navigationPath = NavigationPath()

    private let projectPlanRepository: ProjectPlanRepository

    init(projectPlanRepository: ProjectPlanRepository? = nil) {
        self.projectPlanRepository = projectPlanRepository ?? RepositoryFactory.createProjectPlanRepository()
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if projectPlans.isEmpty {
                    emptyStateView
                } else {
                    projectPlansListView
                }
            }
            .navigationTitle("Plans")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                toolbarContent
            }
            .task {
                await loadProjectPlans()
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

    // MARK: - List View

    private var projectPlansListView: some View {
        List {
            ForEach(projectPlans) { plan in
                NavigationLink(value: ProjectPlanDestination.existing(plan)) {
                    ProjectPlanRow(plan: plan)
                }
            }
        }
        .id(refreshTrigger)
        .navigationDestination(for: ProjectPlanDestination.self) { destination in
            switch destination {
            case .existing(let plan):
                ProjectPlanDetailView(plan: plan, repository: projectPlanRepository, startInEditMode: false)
            case .new(let plan):
                ProjectPlanDetailView(plan: plan, repository: projectPlanRepository, startInEditMode: true)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        SettingsToolbarButton()

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

    private func loadProjectPlans() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load active (non-archived) plans from repository
            projectPlans = try await projectPlanRepository.getActivePlans()
            refreshTrigger += 1
        } catch {
            // Handle error silently - empty state will show
            projectPlans = []
        }
    }

    // MARK: - Actions

    private func createNewPlan() async {
        // Create a blank plan with default values (empty title)
        // NOTE: We don't save it yet - only save when user clicks "Done"
        let blankPlan = ProjectPlanModel(
            title: "",
            planType: .idea,
            tags: [],
            coe: "any",
            summary: nil
        )

        await MainActor.run {
            navigationPath.append(ProjectPlanDestination.new(blankPlan))
        }
    }
}

// MARK: - Supporting Views

struct ProjectPlanRow: View {
    let plan: ProjectPlanModel

    var body: some View {
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

                if !plan.tags.isEmpty {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(plan.tags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddProjectPlanView: View {
    @Environment(\.dismiss) private var dismiss

    // Basic info
    @State private var title = ""
    @State private var summary = ""
    @State private var planType: ProjectPlanType = .recipe
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

    private let projectPlanRepository: ProjectPlanRepository
    private let onSave: ((ProjectPlanModel) -> Void)?

    init(projectPlanRepository: ProjectPlanRepository? = nil, onSave: ((ProjectPlanModel) -> Void)? = nil) {
        self.projectPlanRepository = projectPlanRepository ?? RepositoryFactory.createProjectPlanRepository()
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Basic Information") {
                TextField("Title", text: $title)
                    .font(.body)

                Picker("Type", selection: $planType) {
                    ForEach([ProjectPlanType.recipe, .tutorial, .idea, .technique, .commission], id: \.self) { type in
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
        .navigationTitle("New Plan")
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

        let plan = ProjectPlanModel(
            title: title,
            planType: planType,
            tags: tags,
            coe: coe,
            summary: summary.isEmpty ? nil : summary,
            estimatedTime: estimatedTime,
            difficultyLevel: difficultyLevel,
            proposedPriceRange: priceRange
        )

        do {
            let createdPlan = try await projectPlanRepository.createPlan(plan)
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

struct ProjectPlanDetailView: View {
    let planId: UUID
    let repository: ProjectPlanRepository
    @State private var isNewPlan: Bool  // Track if this is a new unsaved plan

    @State private var plan: ProjectPlanModel?
    @State private var isLoading = false
    @State private var showingAddGlass = false
    @State private var showingAddURL = false
    @State private var showingImagePicker = false
    @State private var showingAddStep = false
    @State private var glassItemLookup: [String: GlassItemModel] = [:]
    @State private var isEditing = false

    // Edit mode fields
    @State private var editTitle = ""
    @State private var editSummary = ""
    @State private var editPlanType: ProjectPlanType = .recipe
    @State private var editCOE: String = "any"
    @State private var editTags: [String] = []
    @State private var editDifficultyLevel: DifficultyLevel?
    @State private var editEstimatedHours: String = ""
    @State private var editPriceMin: String = ""
    @State private var editPriceMax: String = ""
    @State private var showingTagEditor = false
    @State private var showingOptionalFields = false
    @State private var showingSuggestedGlass = true
    @State private var showingImages = true
    @State private var showingReferenceUrls = true
    @State private var showingSteps = true

    @Environment(\.dismiss) private var dismiss

    private let catalogService: CatalogService

    init(plan: ProjectPlanModel, repository: ProjectPlanRepository, startInEditMode: Bool = false) {
        self.planId = plan.id
        self.repository = repository
        self._isNewPlan = State(initialValue: startInEditMode)  // If starting in edit mode, it's a new plan
        self._plan = State(initialValue: plan)
        self._isEditing = State(initialValue: startInEditMode)
        self.catalogService = RepositoryFactory.createCatalogService()
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
                    Button("Edit") {
                        enterEditMode()
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
        #if canImport(UIKit)
        .sheet(isPresented: $showingImagePicker, onDismiss: {
            Task {
                await loadPlan()
            }
        }) {
            NavigationStack {
                if let plan = plan {
                    AddPlanImageView(plan: plan, repository: repository)
                }
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
        .task {
            await loadPlan()

            // If starting in edit mode, populate edit fields
            if isEditing {
                enterEditMode()
            }
        }
    }

    /// Compute total glass needed across all steps
    private func computeTotalGlassNeeded(from plan: ProjectPlanModel) -> [ProjectGlassItem] {
        // Flatten all glass items from steps
        let allGlass = plan.steps.flatMap { $0.glassItemsNeeded ?? [] }

        // Group by naturalKey or notes (for free-form items)
        var totals: [String: (ProjectGlassItem, Decimal)] = [:]

        for glass in allGlass {
            let key = glass.naturalKey ?? glass.freeformDescription ?? ""
            if let existing = totals[key] {
                totals[key] = (existing.0, existing.1 + glass.quantity)
            } else {
                totals[key] = (glass, glass.quantity)
            }
        }

        // Create new ProjectGlassItems with totaled quantities
        return totals.values.map { (template, totalQty) in
            if template.isCatalogItem, let naturalKey = template.naturalKey {
                return ProjectGlassItem(
                    naturalKey: naturalKey,
                    quantity: totalQty,
                    unit: template.unit
                )
            } else if let notes = template.notes {
                return ProjectGlassItem(
                    freeformNotes: notes,
                    quantity: totalQty,
                    unit: template.unit
                )
            } else {
                // Fallback: create a placeholder
                return ProjectGlassItem(
                    freeformNotes: "Unknown glass",
                    quantity: totalQty,
                    unit: template.unit
                )
            }
        }
    }

    @ViewBuilder
    private func planDetailContent(for plan: ProjectPlanModel) -> some View {
        List {
            detailsSection(for: plan)

            optionalFieldsSection

            tagsSection(for: plan)

            stepsSection(for: plan)

            totalGlassSection(for: plan)

            imagesSection(for: plan)

            referenceUrlsSection(for: plan)

            metadataSection(for: plan)
        }
    }

    // MARK: - Section Builders

    @ViewBuilder
    private func detailsSection(for plan: ProjectPlanModel) -> some View {
        Section("Details") {
            if isEditing {
                // Edit mode - show editable fields
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter plan title", text: $editTitle)
                        .font(.body)
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
                LabeledContent("Type", value: plan.planType.displayName)
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
        Picker("Type", selection: $editPlanType) {
            ForEach([ProjectPlanType.recipe, .tutorial, .idea, .technique, .commission], id: \.self) { type in
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
    private func tagsSection(for plan: ProjectPlanModel) -> some View {
        // Tags Section (View Mode Only)
        if !isEditing && !plan.tags.isEmpty {
            Section("Tags") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(plan.tags, id: \.self) { tag in
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
    private func stepsSection(for plan: ProjectPlanModel) -> some View {
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
    private func stepsContent(for plan: ProjectPlanModel) -> some View {
        if plan.steps.isEmpty {
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
            ForEach(plan.steps) { step in
                stepRow(step)
            }

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
                if let minutes = step.estimatedMinutes {
                    Text("\(minutes) minutes")
                        .font(.caption2)
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
                    Text(glass.isCatalogItem ? (glassItemLookup[glass.naturalKey!]?.name ?? glass.displayName) : glass.displayName)
                        .font(.caption)
                    Spacer()
                    Text(verbatim: "\(glass.quantity) \(glass.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func totalGlassSection(for plan: ProjectPlanModel) -> some View {
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
    private func totalGlassContent(for plan: ProjectPlanModel) -> some View {
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
        if projectGlassItem.isCatalogItem, let glassItem = glassItemLookup[projectGlassItem.naturalKey!] {
            // Catalog item with full card display
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Glass item card
                GlassItemCard(item: glassItem, variant: .compact)

                // Quantity and unit
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
            .padding(.vertical, DesignSystem.Spacing.xs)
        } else {
            // Free-form text or fallback display
            HStack {
                Text(projectGlassItem.displayName)
                    .font(.caption)
                Spacer()
                Text(verbatim: "\(projectGlassItem.quantity) \(projectGlassItem.unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func imagesSection(for plan: ProjectPlanModel) -> some View {
        Section {
            DisclosureGroup(
                isExpanded: $showingImages,
                content: {
                    imagesContent(for: plan)
                },
                label: {
                    Text("Images (\(plan.images.count))")
                }
            )
        }
    }

    @ViewBuilder
    private func imagesContent(for plan: ProjectPlanModel) -> some View {
        #if canImport(UIKit)
        if plan.images.isEmpty {
            Button(action: {
                Task {
                    await ensurePlanExistsInRepository()
                    await MainActor.run {
                        showingImagePicker = true
                    }
                }
            }) {
                Label("Add Image", systemImage: "plus.circle")
            }
        } else {
            Text("\(plan.images.count) image\(plan.images.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: {
                Task {
                    await ensurePlanExistsInRepository()
                    await MainActor.run {
                        showingImagePicker = true
                    }
                }
            }) {
                Label("Add more images", systemImage: "plus.circle")
            }
        }
        #else
        Text("Image upload is only available on iOS")
            .font(.caption)
            .foregroundColor(.secondary)
        #endif
    }

    @ViewBuilder
    private func referenceUrlsSection(for plan: ProjectPlanModel) -> some View {
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
    private func referenceUrlsContent(for plan: ProjectPlanModel) -> some View {
        if plan.referenceUrls.isEmpty {
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
            ForEach(plan.referenceUrls) { url in
                VStack(alignment: .leading, spacing: 4) {
                    if let title = url.title {
                        Text(title)
                            .font(.headline)
                    }
                    Link(url.url, destination: URL(string: url.url)!)
                        .font(.caption)
                    if let description = url.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

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

    @ViewBuilder
    private func metadataSection(for plan: ProjectPlanModel) -> some View {
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
        editPlanType = plan.planType
        editCOE = plan.coe
        editTags = plan.tags
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
        let updatedPlan = ProjectPlanModel(
            id: plan.id,
            title: editTitle,
            planType: editPlanType,
            dateCreated: plan.dateCreated,
            dateModified: Date(), // Update modification date
            isArchived: plan.isArchived,
            tags: editTags,
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
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            // If this is a new plan, create it; otherwise, update it
            if isNewPlan {
                _ = try await repository.createPlan(updatedPlan)
            } else {
                try await repository.updatePlan(updatedPlan)
            }

            await MainActor.run {
                self.plan = updatedPlan
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
            guard let reloadedPlan = try await repository.getPlan(id: planId) else {
                self.plan = nil
                return
            }

            await MainActor.run {
                self.plan = reloadedPlan
            }

            // Load glass item details from all steps
            let totalGlass = computeTotalGlassNeeded(from: reloadedPlan)
            await loadGlassItems(for: totalGlass)
        } catch {
            print("Error loading plan: \(error)")
            await MainActor.run {
                self.plan = nil
            }
        }
    }

    // MARK: - Ensure Plan Exists

    /// Ensures the plan exists in the repository before opening child views (add glass, add URL, etc.)
    /// This is necessary because child views call updatePlan() which requires the plan to exist
    ///
    /// Note: We save "Untitled" in the database as a fallback, but keep editTitle empty in the UI
    /// so the user still sees the empty text field and can fill it in later
    private func ensurePlanExistsInRepository() async {
        // If this is a new plan that hasn't been saved yet, save it now
        guard isNewPlan, let plan = plan else { return }

        do {
            // Create the plan in the repository with current edit values
            // Use "Untitled" as fallback title in DB, but don't change editTitle (keep UI showing empty field)
            let planToSave = ProjectPlanModel(
                id: plan.id,
                title: editTitle.isEmpty ? "Untitled" : editTitle,
                planType: editPlanType,
                dateCreated: plan.dateCreated,
                dateModified: Date(),
                isArchived: plan.isArchived,
                tags: editTags,
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
                timesUsed: plan.timesUsed,
                lastUsedDate: plan.lastUsedDate
            )

            _ = try await repository.createPlan(planToSave)

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
        let naturalKeys = projectGlassItems.compactMap { $0.naturalKey }

        // Fetch all glass items from catalog
        do {
            let allItems = try await catalogService.getGlassItemsLightweight()
            let itemsDict: [String: GlassItemModel] = Dictionary(uniqueKeysWithValues: allItems.map { ($0.natural_key, $0) })

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
}

#Preview {
    ProjectPlansView()
}
