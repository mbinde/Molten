//
//  ProjectPlansView.swift
//  Flameworker
//
//  Created by Assistant on 10/18/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
import PhotosUI
#endif

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
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }

                        HStack {
                            Text("Price Range (optional)")
                            Spacer()
                            Text("$")
                            TextField("Min", text: $priceMin)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                            Text("-")
                            TextField("Max", text: $priceMax)
                                .keyboardType(.decimalPad)
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
        .navigationBarTitleDisplayMode(.inline)
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
                            .textInputAutocapitalization(.never)

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
            .navigationBarTitleDisplayMode(.inline)
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
        .task {
            await loadPlan()

            // If starting in edit mode, populate edit fields
            if isEditing {
                enterEditMode()
            }
        }
    }

    @ViewBuilder
    private func planDetailContent(for plan: ProjectPlanModel) -> some View {
        List {
            // Basic Information Section
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

            // Optional Fields Section (Edit Mode Only)
            if isEditing {
                Section {
                    DisclosureGroup(
                        isExpanded: $showingOptionalFields,
                        content: {
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

                            // Tags Editor
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
                        },
                        label: {
                            Text("Additional Optional Fields")
                        }
                    )
                }
            }

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

            // Glass Section with Cards (Collapsible)
            Section {
                DisclosureGroup(
                    isExpanded: $showingSuggestedGlass,
                    content: {
                        if plan.glassItems.isEmpty {
                            Button(action: {
                                Task {
                                    await ensurePlanExistsInRepository()
                                    await MainActor.run {
                                        showingAddGlass = true
                                    }
                                }
                            }) {
                                Label("Add suggested glass", systemImage: "plus.circle")
                            }
                        } else {
                            ForEach(plan.glassItems) { projectGlassItem in
                                if let glassItem = glassItemLookup[projectGlassItem.naturalKey] {
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                        // Glass item card
                                        GlassItemCard(item: glassItem, variant: .compact)

                                        // Quantity and unit
                                        HStack {
                                            Text("Quantity:")
                                                .font(DesignSystem.Typography.caption)
                                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                            Text("\(projectGlassItem.quantity) \(projectGlassItem.unit)")
                                                .font(DesignSystem.Typography.caption)
                                                .fontWeight(DesignSystem.FontWeight.semibold)
                                                .foregroundColor(DesignSystem.Colors.accentPrimary)
                                        }
                                        .padding(.horizontal, DesignSystem.Padding.standard)

                                        // Notes (if present)
                                        if let notes = projectGlassItem.notes, !notes.isEmpty {
                                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                                Text("Notes:")
                                                    .font(DesignSystem.Typography.caption)
                                                    .fontWeight(DesignSystem.FontWeight.semibold)
                                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                                Text(notes)
                                                    .font(DesignSystem.Typography.caption)
                                                    .foregroundColor(.primary)
                                            }
                                            .padding(DesignSystem.Padding.standard)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(DesignSystem.Colors.backgroundInput)
                                            .cornerRadius(DesignSystem.CornerRadius.medium)
                                        }
                                    }
                                    .padding(.vertical, DesignSystem.Spacing.xs)
                                } else {
                                    // Fallback if glass item not found in catalog
                                    HStack {
                                        Text(projectGlassItem.naturalKey)
                                        Spacer()
                                        Text("\(projectGlassItem.quantity) \(projectGlassItem.unit)")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Button(action: {
                                Task {
                                    await ensurePlanExistsInRepository()
                                    await MainActor.run {
                                        showingAddGlass = true
                                    }
                                }
                            }) {
                                Label("Add more glass", systemImage: "plus.circle")
                            }
                        }
                    },
                    label: {
                        Text("Suggested Glass (\(plan.glassItems.count))")
                    }
                )
            }

            // Images Section (Collapsible)
            Section {
                DisclosureGroup(
                    isExpanded: $showingImages,
                    content: {
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
                    },
                    label: {
                        Text("Images (\(plan.images.count))")
                    }
                )
            }

            // Reference URLs Section (Collapsible)
            Section {
                DisclosureGroup(
                    isExpanded: $showingReferenceUrls,
                    content: {
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
                    },
                    label: {
                        Text("Reference URLs (\(plan.referenceUrls.count))")
                    }
                )
            }

            // Steps Section (Placeholder)
            Section("Steps") {
                if plan.steps.isEmpty {
                    Button(action: {
                        // TODO: Add step
                    }) {
                        Label("Add Step", systemImage: "plus.circle")
                    }
                } else {
                    ForEach(plan.steps) { step in
                        Text(step.title)
                    }
                }
            }

            // Metadata Section
            Section("Metadata") {
                LabeledContent("Created", value: plan.dateCreated, format: .dateTime)
                LabeledContent("Modified", value: plan.dateModified, format: .dateTime)
                LabeledContent("Times Used", value: String(plan.timesUsed))

                if let lastUsed = plan.lastUsedDate {
                    LabeledContent("Last Used", value: lastUsed, format: .dateTime)
                }
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

            // Load glass item details for all suggested glass
            await loadGlassItems(for: reloadedPlan.glassItems)
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
        // Extract all natural keys
        let naturalKeys = projectGlassItems.map { $0.naturalKey }

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

// MARK: - Add Suggested Glass View

struct AddSuggestedGlassView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: ProjectPlanModel
    let repository: ProjectPlanRepository

    @State private var selectedGlassItem: GlassItemModel?
    @State private var searchText = ""
    @State private var quantity = ""
    @State private var unit = "rods"
    @State private var notes = ""
    @State private var glassItems: [GlassItemModel] = []
    @State private var isLoading = false

    private let catalogService: CatalogService

    init(plan: ProjectPlanModel, repository: ProjectPlanRepository) {
        self.plan = plan
        self.repository = repository
        self.catalogService = RepositoryFactory.createCatalogService()
    }

    var body: some View {
        Form {
            // Glass Item Selection
            GlassItemSearchSelector(
                selectedGlassItem: $selectedGlassItem,
                searchText: $searchText,
                prefilledNaturalKey: nil,
                glassItems: glassItems,
                onSelect: { item in
                    selectedGlassItem = item
                    searchText = ""
                },
                onClear: {
                    selectedGlassItem = nil
                    searchText = ""
                }
            )

            // Quantity and Unit
            Section("Quantity") {
                HStack {
                    TextField("Quantity", text: $quantity)
                        #if canImport(UIKit)
                        .keyboardType(.decimalPad)
                        #endif
                        .textFieldStyle(.roundedBorder)

                    Picker("Unit", selection: $unit) {
                        Text("Rods").tag("rods")
                        Text("Grams").tag("grams")
                        Text("Oz").tag("oz")
                        Text("Pounds").tag("lbs")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
            }

            // Optional Notes
            Section("Notes (Optional)") {
                TextField("e.g., for the base layer", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle("Add Suggested Glass")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    Task {
                        await saveGlassItem()
                    }
                }
                .disabled(selectedGlassItem == nil || quantity.isEmpty)
            }
        }
        .task {
            await loadGlassItems()
        }
    }

    private func loadGlassItems() async {
        print("⏱️ [SEARCH] loadGlassItems() started, cache isLoaded=\(CatalogSearchCache.shared.isLoaded)")
        isLoading = true

        // CRITICAL: Trust the cache is loaded during FirstRunDataLoadingView
        // The cache is ALWAYS loaded during startup (see FirstRunDataLoadingView line 189)
        // If it's not loaded yet, we wait for it to finish loading (don't reload!)
        if CatalogSearchCache.shared.isLoaded {
            // Cache ready - instant access!
            glassItems = CatalogSearchCache.shared.items
            print("✅ [SEARCH] Using pre-loaded cache with \(glassItems.count) items")
        } else {
            // Cache still loading from FirstRunDataLoadingView, wait for it
            print("⏳ [SEARCH] Cache not ready, waiting for FirstRunDataLoadingView to finish...")
            await CatalogSearchCache.shared.loadIfNeeded(catalogService: catalogService)
            glassItems = CatalogSearchCache.shared.items
            print("✅ [SEARCH] Cache now ready with \(glassItems.count) items")
        }

        isLoading = false
    }

    private func saveGlassItem() async {
        guard let glassItem = selectedGlassItem,
              let quantityValue = Decimal(string: quantity) else {
            return
        }

        // Create new ProjectGlassItem
        let newItem = ProjectGlassItem(
            naturalKey: glassItem.natural_key,
            quantity: quantityValue,
            unit: unit,
            notes: notes.isEmpty ? nil : notes
        )

        // Create updated plan with new glass item
        var updatedGlassItems = plan.glassItems
        updatedGlassItems.append(newItem)

        let updatedPlan = ProjectPlanModel(
            id: plan.id,
            title: plan.title,
            planType: plan.planType,
            dateCreated: plan.dateCreated,
            dateModified: Date(), // Update modification date
            isArchived: plan.isArchived,
            tags: plan.tags,
            coe: plan.coe,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: plan.images,
            heroImageId: plan.heroImageId,
            glassItems: updatedGlassItems,
            referenceUrls: plan.referenceUrls,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            try await repository.updatePlan(updatedPlan)
            await MainActor.run {
                dismiss()
            }
        } catch {
            // TODO: Show error alert
            print("Error saving glass item: \(error)")
        }
    }
}

// MARK: - Add Reference URL View

struct AddReferenceURLView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: ProjectPlanModel
    let repository: ProjectPlanRepository

    @State private var url = ""
    @State private var title = ""
    @State private var urlDescription = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var autoFetchTitle = true
    @State private var isFetchingTitle = false
    @State private var fetchedTitle: String?

    var body: some View {
        Form {
            Section("URL") {
                TextField("https://example.com", text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #if canImport(UIKit)
                    .keyboardType(.URL)
                    #endif
            }

            Section("Title") {
                Picker("Title Source", selection: $autoFetchTitle) {
                    Text("Auto-fetch from URL").tag(true)
                    Text("Enter manually").tag(false)
                }
                .pickerStyle(.segmented)

                if autoFetchTitle {
                    Text("Title will be fetched automatically when you tap Add")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Title")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., Tutorial video", text: $title)
                    }
                }
            }

            Section("Description (Optional)") {
                TextField("Add notes about this reference", text: $urlDescription, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle("Add Reference URL")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isFetchingTitle)
            }

            ToolbarItem(placement: .confirmationAction) {
                if isFetchingTitle {
                    ProgressView()
                } else {
                    Button("Add") {
                        Task {
                            await saveURL()
                        }
                    }
                    .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func fetchTitleFromURL(_ urlString: String) async {
        // Reset state
        await MainActor.run {
            isFetchingTitle = true
            fetchedTitle = nil
        }

        // Validate URL and upgrade HTTP to HTTPS to avoid ATS issues
        guard var url = URL(string: urlString) else {
            await MainActor.run {
                isFetchingTitle = false
            }
            return
        }

        // Upgrade HTTP to HTTPS to avoid App Transport Security blocking
        if url.scheme == "http" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = "https"
            if let httpsURL = components?.url {
                url = httpsURL
            }
        }

        // Ensure we have a valid HTTP(S) URL
        guard let scheme = url.scheme, scheme.hasPrefix("http") else {
            await MainActor.run {
                isFetchingTitle = false
            }
            return
        }

        do {
            // Create a request with timeout
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0

            // Fetch HTML content
            let (data, _) = try await URLSession.shared.data(for: request)

            // Check if task was cancelled
            guard !Task.isCancelled else {
                await MainActor.run {
                    isFetchingTitle = false
                }
                return
            }

            // Convert to string
            guard let html = String(data: data, encoding: .utf8) else {
                await MainActor.run {
                    isFetchingTitle = false
                }
                return
            }

            // Extract title using regex
            let titlePattern = "<title>([^<]+)</title>"
            if let regex = try? NSRegularExpression(pattern: titlePattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
               let titleRange = Range(match.range(at: 1), in: html) {
                let extractedTitle = String(html[titleRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#39;", with: "'")

                await MainActor.run {
                    fetchedTitle = extractedTitle
                    isFetchingTitle = false
                }
            } else {
                await MainActor.run {
                    isFetchingTitle = false
                }
            }
        } catch {
            // Silently fail - just stop showing loading state
            await MainActor.run {
                isFetchingTitle = false
            }
        }
    }

    private func saveURL() async {
        // Validate URL
        guard let _ = URL(string: url) else {
            errorMessage = "Please enter a valid URL"
            showingError = true
            return
        }

        // Fetch title if auto-fetch is enabled
        var finalTitle: String?
        if autoFetchTitle {
            await fetchTitleFromURL(url)
            finalTitle = fetchedTitle
        } else {
            finalTitle = title.isEmpty ? nil : title
        }

        // Create new reference URL
        let newURL = ProjectReferenceUrl(
            url: url,
            title: finalTitle,
            description: urlDescription.isEmpty ? nil : urlDescription
        )

        // Create updated plan with new URL
        var updatedURLs = plan.referenceUrls
        updatedURLs.append(newURL)

        let updatedPlan = ProjectPlanModel(
            id: plan.id,
            title: plan.title,
            planType: plan.planType,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: plan.isArchived,
            tags: plan.tags,
            coe: plan.coe,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: plan.images,
            heroImageId: plan.heroImageId,
            glassItems: plan.glassItems,
            referenceUrls: updatedURLs,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            try await repository.updatePlan(updatedPlan)
            await MainActor.run {
                dismiss()
            }
        } catch {
            errorMessage = "Failed to save URL: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Add Plan Image View

#if canImport(UIKit)
struct AddPlanImageView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: ProjectPlanModel
    let repository: ProjectPlanRepository

    @State private var selectedImage: UIImage?
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section {
                if let image = selectedImage {
                    VStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(8)

                        Button("Choose Different Image") {
                            showingPhotoPicker = true
                        }
                        .foregroundColor(.blue)
                    }
                } else {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Choose from Photos", systemImage: "photo")
                    }

                    #if !targetEnvironment(macCatalyst)
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                    #endif
                }
            }
        }
        .navigationTitle("Add Image")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            if selectedImage != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveImage()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        #if !targetEnvironment(macCatalyst)
        .sheet(isPresented: $showingCamera) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
        }
        #endif
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func saveImage() async {
        guard let image = selectedImage else { return }

        // TODO: Save image to UserImageRepository or similar storage
        // For now, create a ProjectImageModel and add it to the plan's images array

        // Create new image model
        let newImage = ProjectImageModel(
            projectId: plan.id,
            projectType: .plan,
            fileExtension: "jpg",
            caption: nil,
            order: plan.images.count
        )

        // Create updated plan with new image
        var updatedImages = plan.images
        updatedImages.append(newImage)

        let updatedPlan = ProjectPlanModel(
            id: plan.id,
            title: plan.title,
            planType: plan.planType,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: plan.isArchived,
            tags: plan.tags,
            coe: plan.coe,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: updatedImages,
            heroImageId: plan.heroImageId,
            glassItems: plan.glassItems,
            referenceUrls: plan.referenceUrls,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            try await repository.updatePlan(updatedPlan)
            await MainActor.run {
                dismiss()
            }
        } catch {
            errorMessage = "Failed to save image: \(error.localizedDescription)"
            showingError = true
        }
    }
}
#endif

// MARK: - Image Picker (UIKit wrapper)

#if canImport(UIKit)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif

#Preview {
    ProjectPlansView()
}
