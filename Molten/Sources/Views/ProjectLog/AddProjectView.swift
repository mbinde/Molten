//
//  AddProjectView.swift
//  Molten
//
//  Form view for creating new project plans
//  Extracted from ProjectsView.swift for better code organization
//

import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif

struct AddProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementService.self) private var entitlementService

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
    @State private var showingUpgradePrompt = false
    @State private var projectCount = 0
    @State private var projectLimit = 0
    @State private var kilnScheduleId: UUID?
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    private let deps: AppDependencies
    private let projectPlanRepository: ProjectRepository
    private let projectService: ProjectService
    private let kilnScheduleService: KilnScheduleService
    private let onSave: ((ProjectModel) -> Void)?

    init(
        deps: AppDependencies = .shared,
        onSave: ((ProjectModel) -> Void)? = nil
    ) {
        self.deps = deps
        self.projectPlanRepository = deps.projectRepository
        self.projectService = deps.projectService
        self.kilnScheduleService = deps.kilnScheduleService
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
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    } else {
                        Text("\(tags.count) tag\(tags.count == 1 ? "" : "s")")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
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
                                    .background(DesignSystem.Colors.accentSecondary.opacity(0.1))
                                    .foregroundColor(DesignSystem.Colors.accentSecondary)
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

            Section("Kiln Schedule") {
                KilnSchedulePickerView(
                    selectedScheduleId: $kilnScheduleId,
                    kilnScheduleService: kilnScheduleService
                )
            }

            Section {
                Text("You can add steps, glass, images, and reference URLs after creating the plan.")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
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
                .accessibilityIdentifier("add_project_cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await savePlan()
                    }
                }
                .disabled(title.isEmpty)
                .accessibilityIdentifier("add_project_save")
            }
        }
        .sheet(isPresented: $showingTagEditor) {
            TagEditorSheet(tags: $tags)
        }
        .sheet(isPresented: $showingUpgradePrompt) {
            UpgradePromptView(
                feature: "projects",
                currentCount: projectCount,
                limit: projectLimit
            )
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
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
            proposedPriceRange: priceRange,
            kilnScheduleId: kilnScheduleId
        )

        do {
            // Check subscription entitlement before creating project
            let allProjects = try await projectPlanRepository.getActiveProjects()
            let currentProjectCount = allProjects.count
            let canAdd = entitlementService.canAddProject(currentCount: currentProjectCount)

            if !canAdd {
                // Hit the limit - show upgrade prompt
                let limit = entitlementService.getProjectsLimit() ?? 0
                await MainActor.run {
                    projectCount = currentProjectCount
                    projectLimit = limit
                    showingUpgradePrompt = true
                }
                return
            }

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
            print("Error saving plan: \(error)")
            await MainActor.run {
                errorMessage = "Failed to save project: \(error.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }
}
