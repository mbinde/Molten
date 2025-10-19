//
//  ProjectPlansView.swift
//  Flameworker
//
//  Created by Assistant on 10/18/25.
//

import SwiftUI

struct ProjectPlansView: View {
    @State private var showingAddPlan = false
    @State private var projectPlans: [ProjectPlanModel] = []
    @State private var isLoading = false
    @State private var refreshTrigger = 0

    private let projectPlanRepository: ProjectPlanRepository

    init(projectPlanRepository: ProjectPlanRepository? = nil) {
        self.projectPlanRepository = projectPlanRepository ?? RepositoryFactory.createProjectPlanRepository()
    }

    var body: some View {
        NavigationStack {
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
            .sheet(isPresented: $showingAddPlan, onDismiss: {
                Task {
                    await loadProjectPlans()
                }
            }) {
                NavigationStack {
                    AddProjectPlanView()
                }
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
                    showingAddPlan = true
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
                NavigationLink(value: plan) {
                    ProjectPlanRow(plan: plan)
                }
            }
        }
        .id(refreshTrigger)
        .navigationDestination(for: ProjectPlanModel.self) { plan in
            ProjectPlanDetailView(plan: plan, repository: projectPlanRepository)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddPlan = true
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

    init(projectPlanRepository: ProjectPlanRepository? = nil) {
        self.projectPlanRepository = projectPlanRepository ?? RepositoryFactory.createProjectPlanRepository()
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

                Picker("Glass COE", selection: $coe) {
                    Text("Any").tag("any")
                    Text("33").tag("33")
                    Text("90").tag("90")
                    Text("96").tag("96")
                    Text("104").tag("104")
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
            _ = try await projectPlanRepository.createPlan(plan)
            await MainActor.run {
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
    let plan: ProjectPlanModel
    let repository: ProjectPlanRepository

    @State private var showingAddGlass = false

    var body: some View {
        List {
            // Basic Information Section
            Section("Details") {
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

            // Tags Section
            if !plan.tags.isEmpty {
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

            // Glass Section (Placeholder)
            Section("Suggested Glass") {
                if plan.glassItems.isEmpty {
                    Button(action: {
                        showingAddGlass = true
                    }) {
                        Label("Add suggested glass", systemImage: "plus.circle")
                    }
                } else {
                    ForEach(plan.glassItems) { item in
                        HStack {
                            Text(item.naturalKey)
                            Spacer()
                            Text("\(item.quantity) \(item.unit)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Images Section (Placeholder)
            Section("Images") {
                Button(action: {
                    // TODO: Add image
                }) {
                    Label("Add Image", systemImage: "plus.circle")
                }
            }

            // Reference URLs Section
            Section("Reference URLs") {
                if plan.referenceUrls.isEmpty {
                    Button(action: {
                        // TODO: Add URL
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
                            Text(url.url)
                                .font(.caption)
                                .foregroundColor(.blue)
                            if let description = url.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
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
        .navigationTitle(plan.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingAddGlass) {
            NavigationStack {
                AddSuggestedGlassView(plan: plan, repository: repository)
            }
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
    @State private var glassItems: [CompleteInventoryItemModel] = []
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
        isLoading = true

        // Use the preloaded cache for instant search results
        let dataCache = CatalogDataCache.shared

        // Ensure cache is loaded (will return immediately if already loaded during launch)
        await dataCache.loadIfNeeded(catalogService: catalogService)

        // Get items from cache
        glassItems = dataCache.items

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

#Preview {
    ProjectPlansView()
}
